#!/usr/bin/env python3
"""
Leakage-safe semiquant evaluation using event-level holdout splits.

This script estimates generalization by:
- splitting rows by event_id into train/test groups
- building semiquant map from train only (with optional SMOTE)
- evaluating on unseen test events
- repeating for multiple random seeds
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
import statistics
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any

from sklearn.metrics import accuracy_score, cohen_kappa_score, f1_score, precision_score, recall_score
from sklearn.model_selection import GroupShuffleSplit

from semiquant_schema import ANALYTE_ORDER, canonicalize_level
from train import build_semiquant_reference_map, validate_and_normalize_semiquant_rows
from vision_pipeline import feature_columns_for_analyte

DEFAULT_FEATURES = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_REPORT = pathlib.Path(__file__).parent / "output" / "semiquant_holdout_metrics.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate semiquant model with event-level holdout")
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_REPORT)
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--repeats", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--semiquant-augment-target-per-level", type=int, default=120)
    parser.add_argument("--semiquant-knn-k", type=int, default=1)
    parser.add_argument(
        "--semiquant-prototype-mode",
        choices=["median", "library"],
        default="library",
    )
    return parser.parse_args()


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _hsv_distance(a_h: float, a_s: float, a_v: float, b_h: float, b_s: float, b_v: float) -> float:
    raw_hue_delta = abs(a_h - b_h)
    hue_delta = min(raw_hue_delta, 360.0 - raw_hue_delta) / 180.0
    saturation_delta = a_s - b_s
    value_delta = a_v - b_v
    return math.sqrt((hue_delta * hue_delta) + (saturation_delta * saturation_delta) + (value_delta * value_delta))


def _feature_distance(a: list[float], b: list[float], feature_space: str) -> float:
    if feature_space in {"hsv", "normalized_hsv"}:
        return _hsv_distance(a[0], a[1], a[2], b[0], b[1], b[2])
    d0 = a[0] - b[0]
    d1 = a[1] - b[1]
    d2 = a[2] - b[2]
    return math.sqrt((d0 * d0) + (d1 * d1) + (d2 * d2))


def detect_feature_space(rows: list[dict[str, str]]) -> str:
    if not rows:
        return "hsv"
    keys = set(rows[0].keys())
    if any(key.endswith("_l") for key in keys):
        return "lab"
    return "hsv"


def load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with open(path, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    out: list[dict[str, str]] = []
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level_raw = row.get("level", "").strip()
        if analyte not in ANALYTE_ORDER or not level_raw:
            continue

        canonical = canonicalize_level(analyte, level_raw)
        if canonical is None:
            continue

        copied = dict(row)
        copied["level"] = canonical
        if not copied.get("event_id", "").strip():
            copied["event_id"] = f"event_missing_{len(out)}"
        out.append(copied)

    return out


def predict_level(
    row: dict[str, str],
    ref_map: dict[str, list[dict[str, Any]]],
    feature_space: str,
    knn_k: int,
) -> str | None:
    analyte = row["analyte"]
    refs = ref_map.get(analyte, [])
    if not refs:
        return None

    col_h, col_s, col_v = feature_columns_for_analyte(analyte, feature_space=feature_space)
    raw_h = row.get(col_h, "").strip()
    raw_s = row.get(col_s, "").strip()
    raw_v = row.get(col_v, "").strip()
    if not raw_h or not raw_s or not raw_v:
        return None

    observed = [_safe_float(raw_h), _safe_float(raw_s), _safe_float(raw_v)]
    if feature_space in {"hsv", "normalized_hsv"}:
        observed = [_normalize_hue(observed[0]), _clip_01(observed[1]), _clip_01(observed[2])]

    distances: list[tuple[str, float]] = []

    for ref in refs:
        if feature_space == "lab":
            keys = ("l", "a", "b")
        else:
            keys = ("h", "s", "v")
        if any(key not in ref for key in keys):
            continue
        ref_values = [_safe_float(ref[key]) for key in keys]
        if feature_space in {"hsv", "normalized_hsv"}:
            ref_values = [_normalize_hue(ref_values[0]), _clip_01(ref_values[1]), _clip_01(ref_values[2])]
        distances.append((
            str(ref.get("level", "")).strip(),
            _feature_distance(observed, ref_values, feature_space),
        ))

    if not distances:
        return None

    distances.sort(key=lambda item: item[1])
    votes: dict[str, float] = defaultdict(float)
    for level, distance in distances[: max(1, min(knn_k, len(distances)))]:
        votes[level] += 1.0 / (distance + 1e-9)

    return max(votes.items(), key=lambda item: item[1])[0]


def evaluate_split(
    train_rows: list[dict[str, str]],
    test_rows: list[dict[str, str]],
    augment_target: int,
    prototype_mode: str,
    feature_space: str,
    knn_k: int,
) -> dict[str, Any]:
    train_norm, train_report = validate_and_normalize_semiquant_rows(train_rows, feature_space=feature_space)
    test_norm, test_report = validate_and_normalize_semiquant_rows(test_rows, feature_space=feature_space)

    ref_map, _summary = build_semiquant_reference_map(
        rows=train_norm,
        augment_target_per_level=augment_target,
        prototype_mode=prototype_mode,
        feature_space=feature_space,
    )

    y_true: list[str] = []
    y_pred: list[str] = []

    per_analyte_true: dict[str, list[str]] = defaultdict(list)
    per_analyte_pred: dict[str, list[str]] = defaultdict(list)

    dropped = 0
    for row in test_norm:
        pred_level = predict_level(row, ref_map, feature_space, knn_k)
        if pred_level is None:
            dropped += 1
            continue

        analyte = row["analyte"]
        true_level = row["level"]

        y_true.append(f"{analyte}:{true_level}")
        y_pred.append(f"{analyte}:{pred_level}")

        per_analyte_true[analyte].append(true_level)
        per_analyte_pred[analyte].append(pred_level)

    if not y_true:
        return {
            "ok": False,
            "reason": "no_test_predictions",
            "train_valid_rows": len(train_norm),
            "test_valid_rows": len(test_norm),
            "dropped_predictions": dropped,
            "train_invalid_rows": train_report.get("invalid_rows", 0),
            "test_invalid_rows": test_report.get("invalid_rows", 0),
        }

    per_analyte_accuracy = {
        analyte: float(accuracy_score(per_analyte_true[analyte], per_analyte_pred[analyte]))
        for analyte in per_analyte_true
    }

    labels_union = sorted(set(y_true) | set(y_pred))

    return {
        "ok": True,
        "overall": {
            "accuracy": float(accuracy_score(y_true, y_pred)),
            "precision_macro": float(precision_score(y_true, y_pred, average="macro", zero_division=0)),
            "recall_macro": float(recall_score(y_true, y_pred, average="macro", zero_division=0)),
            "f1_macro": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
            "f1_weighted": float(f1_score(y_true, y_pred, average="weighted", zero_division=0)),
            "cohen_kappa": float(cohen_kappa_score(y_true, y_pred, labels=labels_union)),
        },
        "per_analyte_accuracy": per_analyte_accuracy,
        "counts": {
            "train_valid_rows": len(train_norm),
            "test_valid_rows": len(test_norm),
            "dropped_predictions": dropped,
            "train_invalid_rows": train_report.get("invalid_rows", 0),
            "test_invalid_rows": test_report.get("invalid_rows", 0),
        },
    }


def main() -> None:
    args = parse_args()

    rows = load_rows(args.features.resolve())
    if not rows:
        raise SystemExit("No usable semiquant rows found in features.csv")

    groups = [row.get("event_id", "") for row in rows]
    feature_space = detect_feature_space(rows)
    splitter = GroupShuffleSplit(
        n_splits=args.repeats,
        test_size=args.test_size,
        random_state=args.seed,
    )

    split_reports: list[dict[str, Any]] = []

    for split_index, (train_idx, test_idx) in enumerate(splitter.split(rows, groups=groups), start=1):
        train_rows = [rows[i] for i in train_idx]
        test_rows = [rows[i] for i in test_idx]

        report = evaluate_split(
            train_rows=train_rows,
            test_rows=test_rows,
            augment_target=args.semiquant_augment_target_per_level,
            prototype_mode=args.semiquant_prototype_mode,
            feature_space=feature_space,
            knn_k=args.semiquant_knn_k,
        )
        report["split_index"] = split_index
        split_reports.append(report)

    ok_reports = [r for r in split_reports if r.get("ok")]
    if not ok_reports:
        raise SystemExit("All holdout splits failed")

    metric_names = [
        "accuracy",
        "precision_macro",
        "recall_macro",
        "f1_macro",
        "f1_weighted",
        "cohen_kappa",
    ]
    summary_metrics: dict[str, dict[str, float]] = {}

    for metric in metric_names:
        values = [float(r["overall"][metric]) for r in ok_reports]
        summary_metrics[metric] = {
            "mean": float(statistics.mean(values)),
            "stdev": float(statistics.pstdev(values)) if len(values) > 1 else 0.0,
            "min": float(min(values)),
            "max": float(max(values)),
        }

    output = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "features_path": str(args.features.resolve()),
        "config": {
            "test_size": args.test_size,
            "repeats": args.repeats,
            "seed": args.seed,
            "semiquant_augment_target_per_level": args.semiquant_augment_target_per_level,
            "semiquant_prototype_mode": args.semiquant_prototype_mode,
            "semiquant_knn_k": args.semiquant_knn_k,
            "feature_space": feature_space,
            "splitter": "GroupShuffleSplit(event_id)",
        },
        "dataset": {
            "rows_total": len(rows),
            "unique_events": len(set(groups)),
        },
        "summary": summary_metrics,
        "splits": split_reports,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump(output, file, indent=2)

    print(f"Saved holdout report -> {args.output.resolve()}")
    print("Holdout summary (mean across splits):")
    print(f"  Accuracy:    {summary_metrics['accuracy']['mean']:.4f}")
    print(f"  Precision:   {summary_metrics['precision_macro']['mean']:.4f}")
    print(f"  Recall:      {summary_metrics['recall_macro']['mean']:.4f}")
    print(f"  F1 macro:    {summary_metrics['f1_macro']['mean']:.4f}")
    print(f"  F1 weighted: {summary_metrics['f1_weighted']['mean']:.4f}")
    print(f"  Kappa:       {summary_metrics['cohen_kappa']['mean']:.4f}")


if __name__ == "__main__":
    main()
