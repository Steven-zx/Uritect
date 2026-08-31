#!/usr/bin/env python3
"""Comprehensive semiquant evaluation for the 10-parameter Uritect model.

This intentionally excludes binary screening. The headline metric is the
cross-validated 10-analyte semiquant accuracy produced by optimize_semiquant.py.
"""

from __future__ import annotations

import csv
import json
import pathlib
import sys
from statistics import mean

sys.path.insert(0, str(pathlib.Path(__file__).parent / "pipeline"))

from semiquant_schema import ANALYTE_ORDER, canonicalize_level
from vision_pipeline import feature_columns_for_analyte


FEATURES_PATH = pathlib.Path("pipeline/dataset/features_normalized_hsv.csv")
OPTIMIZATION_PATH = pathlib.Path("pipeline/output/semiquant_optimization_results.json")
TARGET_ACCURACY = 0.80


def load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def usable_rows_by_analyte(rows: list[dict[str, str]]) -> dict[str, int]:
    counts = {analyte: 0 for analyte in ANALYTE_ORDER}
    for row in rows:
        analyte = row.get("analyte", "").strip()
        if analyte not in counts:
            continue
        if canonicalize_level(analyte, row.get("level", "")) is None:
            continue
        columns = feature_columns_for_analyte(analyte)
        if all(row.get(column, "").strip() for column in columns):
            counts[analyte] += 1
    return counts


def main() -> None:
    print("=" * 72)
    print("URITECT 10-PARAMETER SEMIQUANT METRIC EVALUATION")
    print("=" * 72)

    if not FEATURES_PATH.exists():
        raise SystemExit(f"Missing features: {FEATURES_PATH}")
    if not OPTIMIZATION_PATH.exists():
        raise SystemExit(f"Missing optimization results: {OPTIMIZATION_PATH}")

    rows = load_rows(FEATURES_PATH)
    with OPTIMIZATION_PATH.open(encoding="utf-8") as file:
        optimization = json.load(file)

    counts = usable_rows_by_analyte(rows)
    print(f"\nFeature file: {FEATURES_PATH}")
    print(f"Rows: {len(rows)}")
    print("\nPer-analyte cross-validation:")
    print(f"{'Analyte':<20} {'Rows':<8} {'k':<4} {'Metric':<12} {'Transform':<16} Accuracy")
    print("-" * 80)

    accuracies: list[float] = []
    weighted_correct = 0.0
    weighted_total = 0

    for analyte in ANALYTE_ORDER:
        result = optimization.get(analyte)
        if not result:
            print(f"{analyte:<20} {counts[analyte]:<8} missing")
            continue

        accuracy = float(result["accuracy"])
        total = int(counts[analyte])
        accuracies.append(accuracy)
        weighted_correct += accuracy * total
        weighted_total += total

        print(
            f"{analyte:<20} "
            f"{total:<8} "
            f"{int(result['best_k']):<4} "
            f"{str(result['best_metric']):<12} "
            f"{str(result.get('feature_transform', 'raw')):<16} "
            f"{accuracy:.4f} ({accuracy*100:.2f}%)"
        )

    macro_accuracy = mean(accuracies) if accuracies else 0.0
    overall_accuracy = weighted_correct / weighted_total if weighted_total else 0.0

    print("\nSummary:")
    print(f"Overall accuracy: {overall_accuracy:.4f} ({overall_accuracy*100:.2f}%)")
    print(f"Macro average: {macro_accuracy:.4f} ({macro_accuracy*100:.2f}%)")
    print(f"Target: {TARGET_ACCURACY:.2%}")
    print(f"Status: {'TARGET REACHED' if overall_accuracy >= TARGET_ACCURACY else 'Below target'}")

    if overall_accuracy < TARGET_ACCURACY:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
