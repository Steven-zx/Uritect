#!/usr/bin/env python3
"""Search KNN hyperparameters using the production specimen-grouped split."""
from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import sys
from collections import defaultdict
from statistics import mean
from typing import Any

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
DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "output" / "semiquant_optimization_results.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--test-size", type=float, default=0.20)
    parser.add_argument("--random-state", type=int, default=42)
    return parser.parse_args()


def _specimen_group(row: dict[str, str]) -> str:
    source = row.get("source_zip", "").strip()
    event = row.get("event_id", "").strip()
    batch = row.get("batch_id", "").strip()
    raw = event or batch or source
    raw = re.sub(r"(?i)(?:^|[_\\-\\s])(cool|warm|daylight|2700k|4000k|5500k)(?:$|[_\\-\\s])", "_", raw)
    raw = re.sub(r"(?i)(_rhu|_labels|\\.zip)$", "", raw)
    raw = re.sub(r"[_\\-\\s]+", "_", raw).strip("_")
    return f"{source}|{raw}" if source else raw


def _model(k: int, metric: str, transform: str):
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


def _rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as file:
        return list(csv.DictReader(file))


def _data_for(rows: list[dict[str, str]], analyte: str) -> tuple[list[list[float]], list[str], list[str]]:
    columns = feature_columns_for_analyte(analyte, feature_space="normalized_hsv")
    x_values: list[list[float]] = []
    y_values: list[str] = []
    groups: list[str] = []
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
        groups.append(_specimen_group(row))
    return x_values, y_values, groups


def main() -> None:
    args = parse_args()
    rows = _rows(args.features)
    results: dict[str, dict[str, Any]] = {}
    total_correct = 0
    total = 0
    print(f"{'Analyte':<20} {'k':>3} {'Metric':<10} {'Transform':<16} {'Acc':>7} {'F1':>7}")
    print("-" * 72)
    for analyte in ANALYTE_ORDER:
        x_values, y_values, groups = _data_for(rows, analyte)
        split = GroupShuffleSplit(n_splits=1, test_size=args.test_size, random_state=args.random_state)
        train_index, test_index = next(split.split(x_values, y_values, groups))
        x_train = [x_values[i] for i in train_index]
        y_train = [y_values[i] for i in train_index]
        x_test = [x_values[i] for i in test_index]
        y_test = [y_values[i] for i in test_index]

        best: tuple[float, float, int, str, str, int] | None = None
        for k in [1, 3, 5, 7, 9, 11, 15, 21, 31, 41, 51]:
            if k > len(train_index):
                continue
            for metric in ["euclidean", "manhattan", "chebyshev"]:
                for transform in ["raw", "scaled", "circular_scaled"]:
                    model = _model(k, metric, transform)
                    y_pred = model.fit(x_train, y_train).predict(x_test).tolist()
                    correct = sum(1 for expected, predicted in zip(y_test, y_pred) if expected == predicted)
                    acc = accuracy_score(y_test, y_pred)
                    f1 = f1_score(y_test, y_pred, average="macro", zero_division=0)
                    candidate = (acc, f1, correct, metric, transform, k)
                    if best is None or candidate > best:
                        best = candidate

        if best is None:
            raise SystemExit(f"No model candidate for {analyte}")
        acc, f1, correct, metric, transform, k = best
        total_correct += correct
        total += len(test_index)
        results[analyte] = {
            "samples": len(x_values),
            "levels": len(set(y_values)),
            "best_k": k,
            "best_metric": metric,
            "feature_transform": transform,
            "accuracy": round(acc, 6),
            "f1_macro": round(f1, 6),
        }
        print(f"{analyte:<20} {k:>3} {metric:<10} {transform:<16} {acc:>7.4f} {f1:>7.4f}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as file:
        json.dump(results, file, indent=2)
    print("-" * 72)
    print(f"Mean per-analyte accuracy: {mean(item['accuracy'] for item in results.values()):.4f}")
    print(f"Pooled individual-analyte accuracy: {total_correct / total:.4f}")
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()
