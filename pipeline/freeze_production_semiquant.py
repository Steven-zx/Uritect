#!/usr/bin/env python3
"""Deduplicate, group-evaluate, and freeze the production semiquant model."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import pickle
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from statistics import mean
from typing import Any

import numpy as np
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import FunctionTransformer, StandardScaler

try:
    from model_features import hsv_to_circular_features
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte
except ImportError:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from model_features import hsv_to_circular_features
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte


DEFAULT_FEATURES = pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv.csv"
DEFAULT_OPT = pathlib.Path(__file__).parent / "output" / "semiquant_optimization_results.json"
DEFAULT_DEDUPED = pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv_deduped_production.csv"
DEFAULT_MODELS = pathlib.Path(__file__).parent / "output" / "semiquant_models"
DEFAULT_REPORT = pathlib.Path(__file__).parent / "output" / "production_grouped_evaluation.json"
MODEL_VERSION = "production_semiquant_knn_markerless_roi_topfix_v3_20260908"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
    parser.add_argument("--optimization-results", type=pathlib.Path, default=DEFAULT_OPT)
    parser.add_argument("--deduped-output", type=pathlib.Path, default=DEFAULT_DEDUPED)
    parser.add_argument("--models-dir", type=pathlib.Path, default=DEFAULT_MODELS)
    parser.add_argument("--report", type=pathlib.Path, default=DEFAULT_REPORT)
    parser.add_argument("--test-size", type=float, default=0.20)
    parser.add_argument("--random-state", type=int, default=42)
    return parser.parse_args()


def _load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as file:
        return list(csv.DictReader(file))


def _feature_columns(analyte: str) -> tuple[str, str, str]:
    return feature_columns_for_analyte(analyte, feature_space="normalized_hsv")


def _specimen_group(row: dict[str, str]) -> str:
    source = row.get("source_zip", "").strip()
    event = row.get("event_id", "").strip()
    batch = row.get("batch_id", "").strip()
    raw = event or batch or source
    raw = re.sub(r"(?i)(?:^|[_\\-\\s])(cool|warm|daylight|2700k|4000k|5500k)(?:$|[_\\-\\s])", "_", raw)
    raw = re.sub(r"(?i)(_rhu|_labels|\\.zip)$", "", raw)
    raw = re.sub(r"[_\\-\\s]+", "_", raw).strip("_")
    return f"{source}|{raw}" if source else raw


def _dedupe_rows(rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], int]:
    seen: set[tuple[str, ...]] = set()
    deduped: list[dict[str, str]] = []
    feature_keys = [
        column
        for analyte in ANALYTE_ORDER
        for column in _feature_columns(analyte)
    ]
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = canonicalize_level(analyte, row.get("level", ""))
        if analyte not in ANALYTE_ORDER or level is None:
            continue
        key = (
            _specimen_group(row),
            str(row.get("light_kelvin", "")).strip().lower(),
            analyte,
            level,
            *[str(row.get(column, "")).strip() for column in feature_keys],
        )
        if key in seen:
            continue
        seen.add(key)
        clean = dict(row)
        clean["level"] = level
        clean["specimen_group"] = _specimen_group(row)
        deduped.append(clean)
    return deduped, len(rows) - len(deduped)


def _write_rows(path: pathlib.Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames: list[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _make_model(k: int, metric: str, transform: str):
    knn = KNeighborsClassifier(n_neighbors=k, metric=metric, weights="distance")
    if transform == "scaled":
        return make_pipeline(StandardScaler(), knn)
    if transform == "circular_scaled":
        return make_pipeline(
            FunctionTransformer(hsv_to_circular_features, validate=False),
            StandardScaler(),
            knn,
        )
    return knn


def _rows_for_analyte(rows: list[dict[str, str]], analyte: str) -> tuple[list[list[float]], list[str], list[str], list[str]]:
    columns = _feature_columns(analyte)
    x_values: list[list[float]] = []
    y_values: list[str] = []
    groups: list[str] = []
    events: list[str] = []
    for row in rows:
        if row.get("analyte", "").strip() != analyte:
            continue
        level = canonicalize_level(analyte, row.get("level", ""))
        if level is None:
            continue
        try:
            x_values.append([float(row[column]) for column in columns])
        except (KeyError, TypeError, ValueError):
            continue
        y_values.append(level)
        groups.append(row.get("specimen_group") or _specimen_group(row))
        events.append(f"{row.get('source_zip','')}|{row.get('event_id','')}|{row.get('light_kelvin','')}")
    return x_values, y_values, groups, events


def _evaluate_grouped(rows: list[dict[str, str]], opt: dict[str, Any], test_size: float, random_state: int) -> dict[str, Any]:
    per_analyte: dict[str, Any] = {}
    event_votes: dict[str, list[bool]] = defaultdict(list)
    total_correct = 0
    total = 0
    for analyte in ANALYTE_ORDER:
        x_values, y_values, groups, events = _rows_for_analyte(rows, analyte)
        if len(set(groups)) < 3 or len(set(y_values)) < 2:
            per_analyte[analyte] = {"skipped": True, "reason": "insufficient grouped class diversity"}
            continue
        split = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
        train_index, test_index = next(split.split(x_values, y_values, groups))
        params = opt.get(analyte, {})
        k = min(int(params.get("best_k", params.get("k", 5))), len(train_index))
        metric = str(params.get("best_metric", params.get("metric", "euclidean")))
        transform = str(params.get("feature_transform", "raw"))
        model = _make_model(k, metric, transform)
        x_train = [x_values[i] for i in train_index]
        y_train = [y_values[i] for i in train_index]
        x_test = [x_values[i] for i in test_index]
        y_test = [y_values[i] for i in test_index]
        y_pred = model.fit(x_train, y_train).predict(x_test).tolist()
        correct = sum(1 for expected, predicted in zip(y_test, y_pred) if expected == predicted)
        for i, predicted in zip(test_index, y_pred):
            event_votes[events[i]].append(predicted == y_values[i])
        total_correct += correct
        total += len(y_test)
        per_analyte[analyte] = {
            "correct": correct,
            "total": len(y_test),
            "accuracy": correct / len(y_test) if y_test else 0.0,
            "f1_macro": f1_score(y_test, y_pred, average="macro", zero_division=0),
            "train_groups": len({groups[i] for i in train_index}),
            "test_groups": len({groups[i] for i in test_index}),
            "k": k,
            "metric": metric,
            "feature_transform": transform,
        }

    whole_scan_total = len(event_votes)
    whole_scan_correct = sum(1 for values in event_votes.values() if len(values) == 10 and all(values))
    return {
        "individual_analyte_accuracy": total_correct / total if total else 0.0,
        "individual_analyte_correct": total_correct,
        "individual_analyte_total": total,
        "whole_scan_accuracy_all_10_correct": whole_scan_correct / whole_scan_total if whole_scan_total else 0.0,
        "whole_scan_correct": whole_scan_correct,
        "whole_scan_total": whole_scan_total,
        "macro_analyte_accuracy": mean(
            item["accuracy"] for item in per_analyte.values() if not item.get("skipped")
        ),
        "per_analyte": per_analyte,
    }


def _train_final_models(rows: list[dict[str, str]], opt: dict[str, Any], output_dir: pathlib.Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    metadata: dict[str, Any] = {}
    for analyte in ANALYTE_ORDER:
        x_values, y_values, _groups, _events = _rows_for_analyte(rows, analyte)
        if not x_values:
            raise SystemExit(f"No rows available for {analyte}")
        params = opt.get(analyte, {})
        k = min(int(params.get("best_k", params.get("k", 5))), len(x_values))
        metric = str(params.get("best_metric", params.get("metric", "euclidean")))
        transform = str(params.get("feature_transform", "raw"))
        model = _make_model(k, metric, transform)
        model.fit(x_values, y_values)
        model_file = f"{analyte.lower().replace(' ', '_')}_knn_model.pkl"
        with (output_dir / model_file).open("wb") as file:
            pickle.dump(model, file)
        metadata[analyte] = {
            "model_version": MODEL_VERSION,
            "k": k,
            "metric": metric,
            "feature_transform": transform,
            "feature_space": "normalized_hsv",
            "feature_set": "local",
            "n_samples": len(x_values),
            "n_levels": len(set(y_values)),
            "model_file": model_file,
            "trained_on": "deduplicated production features",
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
    with (output_dir / "semiquant_models_metadata.json").open("w", encoding="utf-8") as file:
        json.dump(metadata, file, indent=2)


def main() -> None:
    args = parse_args()
    rows = _load_rows(args.features)
    with args.optimization_results.open(encoding="utf-8") as file:
        opt = json.load(file)
    deduped, duplicates_removed = _dedupe_rows(rows)
    _write_rows(args.deduped_output, deduped)
    evaluation = _evaluate_grouped(deduped, opt, args.test_size, args.random_state)
    _train_final_models(deduped, opt, args.models_dir)
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "features": str(args.features),
        "deduped_output": str(args.deduped_output),
        "raw_rows": len(rows),
        "deduped_rows": len(deduped),
        "duplicates_removed": duplicates_removed,
        "split": {
            "type": "GroupShuffleSplit",
            "group": "specimen_group",
            "test_size": args.test_size,
            "random_state": args.random_state,
        },
        "model_version": MODEL_VERSION,
        "evaluation": evaluation,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)
    print(f"Rows: {len(rows)} raw, {len(deduped)} deduped, {duplicates_removed} duplicates removed")
    print(
        "Individual-analyte accuracy: "
        f"{evaluation['individual_analyte_accuracy']:.4f} "
        f"({evaluation['individual_analyte_accuracy'] * 100:.2f}%)"
    )
    print(
        "Whole-scan all-10 accuracy: "
        f"{evaluation['whole_scan_accuracy_all_10_correct']:.4f} "
        f"({evaluation['whole_scan_accuracy_all_10_correct'] * 100:.2f}%)"
    )
    print(f"Report: {args.report}")
    print(f"Frozen models: {args.models_dir}")


if __name__ == "__main__":
    main()
