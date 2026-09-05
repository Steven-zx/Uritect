#!/usr/bin/env python3
"""Evaluate semiquant KNN generalization across collection sites.

This is a non-production experiment runner. It trains temporary per-analyte
models from selected source ZIP filters and evaluates them on a separate source
filter, without overwriting the app's saved model files.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
from collections import defaultdict
from statistics import mean

from sklearn.metrics import accuracy_score
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


DEFAULT_FEATURES = (
    pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv.csv",
    pathlib.Path(__file__).parent / "dataset" / "cabatuan_holdout_features_normalized_hsv.csv",
)
DEFAULT_METADATA = pathlib.Path(__file__).parent / "output" / "semiquant_models" / "semiquant_models_metadata.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate cross-site semiquant model adaptation.")
    parser.add_argument(
        "--features",
        type=pathlib.Path,
        nargs="+",
        default=list(DEFAULT_FEATURES),
        help="One or more normalized-HSV semiquant feature CSV files.",
    )
    parser.add_argument(
        "--metadata",
        type=pathlib.Path,
        default=DEFAULT_METADATA,
        help="Saved semiquant model metadata containing k/metric/transform settings.",
    )
    parser.add_argument(
        "--train-source-contains",
        action="append",
        required=True,
        help="Substring for source_zip rows included in temporary training. Repeatable.",
    )
    parser.add_argument(
        "--test-source-contains",
        action="append",
        required=True,
        help="Substring for source_zip rows included in evaluation. Repeatable.",
    )
    parser.add_argument("--output", type=pathlib.Path, help="Optional JSON report path.")
    return parser.parse_args()


def _matches_any(value: str, needles: list[str]) -> bool:
    lowered = value.lower()
    return any(needle.lower() in lowered for needle in needles)


def load_rows(paths: list[pathlib.Path]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in paths:
        with open(path, newline="", encoding="utf-8") as file:
            rows.extend(csv.DictReader(file))
    return rows


def _make_model(metadata: dict, n_samples: int):
    k = max(1, min(int(metadata.get("k", metadata.get("best_k", 5))), n_samples))
    metric = str(metadata.get("metric", metadata.get("best_metric", "euclidean")))
    transform = str(metadata.get("feature_transform", "raw"))
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


def main() -> None:
    args = parse_args()
    rows = load_rows(args.features)
    with open(args.metadata, encoding="utf-8") as file:
        metadata = json.load(file)

    report: dict[str, object] = {
        "features": [str(path) for path in args.features],
        "train_source_contains": args.train_source_contains,
        "test_source_contains": args.test_source_contains,
        "per_analyte": {},
    }

    total_correct = 0
    total_rows = 0
    accuracies: list[float] = []

    print("Cross-site semiquant evaluation")
    print(f"Train filters: {', '.join(args.train_source_contains)}")
    print(f"Test filters:  {', '.join(args.test_source_contains)}")
    print()
    print(f"{'Analyte':<20} {'Correct':>8} {'Total':>8} {'Accuracy':>10} {'Train n':>8}")
    print("-" * 62)

    for analyte in ANALYTE_ORDER:
        cols = feature_columns_for_analyte(analyte, feature_space="normalized_hsv")
        train_x: list[list[float]] = []
        train_y: list[str] = []
        test_x: list[list[float]] = []
        test_y: list[str] = []

        for row in rows:
            if row.get("analyte", "").strip() != analyte:
                continue
            level = canonicalize_level(analyte, row.get("level", ""))
            if level is None:
                continue
            try:
                features = [float(row[col]) for col in cols]
            except (KeyError, TypeError, ValueError):
                continue

            source_zip = row.get("source_zip", "")
            if _matches_any(source_zip, args.train_source_contains):
                train_x.append(features)
                train_y.append(level)
            elif _matches_any(source_zip, args.test_source_contains):
                test_x.append(features)
                test_y.append(level)

        if not train_x or not test_x:
            print(f"{analyte:<20} {'-':>8} {'-':>8} {'N/A':>10} {len(train_x):>8}")
            continue

        model = _make_model(metadata.get(analyte, {}), len(train_x))
        model.fit(train_x, train_y)
        predictions = model.predict(test_x)
        correct = int(sum(pred == truth for pred, truth in zip(predictions, test_y)))
        total = len(test_y)
        accuracy = float(accuracy_score(test_y, predictions))

        total_correct += correct
        total_rows += total
        accuracies.append(accuracy)
        report["per_analyte"][analyte] = {
            "correct": correct,
            "total": total,
            "accuracy": accuracy,
            "train_rows": len(train_x),
            "train_levels": sorted(set(train_y)),
            "test_levels": sorted(set(test_y)),
        }
        print(f"{analyte:<20} {correct:>8} {total:>8} {accuracy * 100:>9.2f}% {len(train_x):>8}")

    overall_accuracy = total_correct / total_rows if total_rows else 0.0
    macro_accuracy = mean(accuracies) if accuracies else 0.0
    report["overall"] = {
        "correct": total_correct,
        "total": total_rows,
        "accuracy": overall_accuracy,
        "macro_accuracy": macro_accuracy,
        "target_reached": overall_accuracy >= 0.80,
    }

    print()
    print(f"Overall accuracy: {overall_accuracy:.4f} ({overall_accuracy * 100:.2f}%)")
    print(f"Macro accuracy:   {macro_accuracy:.4f} ({macro_accuracy * 100:.2f}%)")
    print(f"Target:           {'reached' if overall_accuracy >= 0.80 else 'below 80%'}")

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as file:
            json.dump(report, file, indent=2)
        print(f"Report: {args.output}")


if __name__ == "__main__":
    main()
