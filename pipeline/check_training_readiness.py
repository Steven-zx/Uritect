#!/usr/bin/env python3
"""
Uritect training readiness preflight checker.

Use this before `train.py` to fail fast when the binary dataset is not ready.

Examples:
  python pipeline/check_training_readiness.py
    python pipeline/check_training_readiness.py --mode binary --min-total 12 --min-class 6
  python pipeline/check_training_readiness.py --json

Exit codes:
  0 -> ready
  1 -> not ready (action required)
  2 -> setup/input error (missing file, malformed data)
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from typing import Any

FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
EXPECTED_LIGHTS = (2700, 4000, 5500)

BINARY_LABEL_ALIASES = {
    "normal": "Normal",
    "negative": "Normal",
    "class1": "Normal",
    "class_1": "Normal",
    "class 1": "Normal",
    "1": "Normal",
    "abnormal": "Abnormal",
    "positive": "Abnormal",
    "class2": "Abnormal",
    "class_2": "Abnormal",
    "class 2": "Abnormal",
    "2": "Abnormal",
}


@dataclass
class ReadinessResult:
    ready: bool
    mode: str
    blockers: list[str]
    warnings: list[str]
    summary: dict[str, Any]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check if Uritect dataset is ready for model training.",
    )
    parser.add_argument(
        "--mode",
        choices=["binary", "semiquant", "auto"],
        default="auto",
        help="Validation mode. auto picks binary if binary rows exist, else semiquant.",
    )
    parser.add_argument(
        "--min-total",
        type=int,
        default=12,
        help="Minimum total binary samples required for readiness (default: 12).",
    )
    parser.add_argument(
        "--min-class",
        type=int,
        default=6,
        help="Minimum samples required per binary class (default: 6).",
    )
    parser.add_argument(
        "--require-all-lights",
        action="store_true",
        help="Require each binary class to include 2700K, 4000K, and 5500K samples.",
    )
    parser.add_argument(
        "--require-split-coverage",
        action="store_true",
        help="Require both classes to appear in train and val/test splits.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON output.",
    )
    return parser.parse_args()


def load_rows() -> list[dict[str, str]]:
    if not FEATURES_PATH.exists():
        print(f"features.csv not found at:\n  {FEATURES_PATH}")
        print("Run ingest.py first.")
        sys.exit(2)

    with open(FEATURES_PATH, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    if not rows:
        print("features.csv is empty. Run ingest.py with labelled ZIPs first.")
        sys.exit(2)

    return rows


def canonical_binary_label(raw: str) -> str | None:
    key = raw.strip().lower()
    if not key:
        return None
    return BINARY_LABEL_ALIASES.get(key)


def detect_mode(row: dict[str, str]) -> str:
    explicit = row.get("label_mode", "").strip().lower()
    if explicit in {"binary", "semiquant"}:
        return explicit

    analyte = row.get("analyte", "").strip()
    level = row.get("level", "").strip()
    if analyte and level:
        return "semiquant"

    for candidate in (
        row.get("class_label", ""),
        row.get("label_canonical", ""),
        row.get("label_raw", ""),
    ):
        if ":" in candidate:
            continue
        if canonical_binary_label(candidate) is not None:
            return "binary"

    return "unknown"


def extract_binary_label(row: dict[str, str]) -> str | None:
    for candidate in (
        row.get("class_label", ""),
        row.get("level", ""),
        row.get("label_canonical", ""),
        row.get("label_raw", ""),
    ):
        label = canonical_binary_label(candidate)
        if label is not None:
            return label
    return None


def safe_int(value: str) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def evaluate_binary(
    rows: list[dict[str, str]],
    min_total: int,
    min_class: int,
    require_all_lights: bool,
    require_split_coverage: bool,
) -> ReadinessResult:
    blockers: list[str] = []
    warnings: list[str] = []

    class_counts = Counter()
    split_class_counts: dict[str, Counter[str]] = defaultdict(Counter)
    lights_by_class: dict[str, set[int]] = defaultdict(set)

    usable_rows = 0
    for row in rows:
        label = extract_binary_label(row)
        if label is None:
            continue

        usable_rows += 1
        class_counts[label] += 1

        split_name = row.get("split", "").strip().lower() or "unspecified"
        split_class_counts[split_name][label] += 1

        light_kelvin = safe_int(row.get("light_kelvin", ""))
        if light_kelvin is not None:
            lights_by_class[label].add(light_kelvin)

    if usable_rows == 0:
        blockers.append("No usable binary rows found in features.csv.")

    if usable_rows < min_total:
        blockers.append(
            f"Total binary samples is {usable_rows}, below required minimum {min_total}."
        )

    for label in ("Normal", "Abnormal"):
        if class_counts[label] == 0:
            blockers.append(f"Missing class '{label}' in binary dataset.")
        elif class_counts[label] < min_class:
            blockers.append(
                f"Class '{label}' has {class_counts[label]} samples, below minimum {min_class}."
            )

    if require_all_lights:
        for label in ("Normal", "Abnormal"):
            if class_counts[label] == 0:
                continue
            missing_lights = sorted(set(EXPECTED_LIGHTS) - lights_by_class[label])
            if missing_lights:
                blockers.append(
                    f"Class '{label}' missing lighting conditions: {missing_lights}."
                )

    if require_split_coverage:
        train_counts = split_class_counts.get("train", Counter())
        eval_counts = split_class_counts.get("val", Counter()) + split_class_counts.get("test", Counter())

        if train_counts.get("Normal", 0) == 0 or train_counts.get("Abnormal", 0) == 0:
            blockers.append("Train split does not contain both Normal and Abnormal classes.")

        if eval_counts.get("Normal", 0) == 0 or eval_counts.get("Abnormal", 0) == 0:
            blockers.append("Validation/Test splits do not contain both Normal and Abnormal classes.")

    if class_counts:
        larger = max(class_counts.values())
        smaller = min(class_counts.values()) if min(class_counts.values()) > 0 else 0
        if smaller > 0:
            ratio = larger / smaller
            if ratio > 2.0:
                warnings.append(
                    f"Class imbalance ratio is {ratio:.2f}:1 (>2:1). Consider collecting more minority samples."
                )

    summary = {
        "features_path": str(FEATURES_PATH),
        "total_rows": len(rows),
        "usable_binary_rows": usable_rows,
        "class_counts": {
            "Normal": class_counts.get("Normal", 0),
            "Abnormal": class_counts.get("Abnormal", 0),
        },
        "split_class_counts": {
            split: {
                "Normal": counts.get("Normal", 0),
                "Abnormal": counts.get("Abnormal", 0),
            }
            for split, counts in sorted(split_class_counts.items())
        },
        "lights_by_class": {
            label: sorted(list(lights_by_class.get(label, set())))
            for label in ("Normal", "Abnormal")
        },
        "requirements": {
            "min_total": min_total,
            "min_class": min_class,
            "require_all_lights": require_all_lights,
            "require_split_coverage": require_split_coverage,
        },
    }

    return ReadinessResult(
        ready=len(blockers) == 0,
        mode="binary",
        blockers=blockers,
        warnings=warnings,
        summary=summary,
    )


def evaluate_semiquant(rows: list[dict[str, str]]) -> ReadinessResult:
    blockers: list[str] = []
    warnings: list[str] = []

    analyte_levels: dict[str, set[str]] = defaultdict(set)
    level_counts = Counter()
    usable_rows = 0

    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        if not analyte or not level:
            continue
        usable_rows += 1
        analyte_levels[analyte].add(level)
        level_counts[(analyte, level)] += 1

    if usable_rows == 0:
        blockers.append("No usable semiquant rows found in features.csv.")

    if len(analyte_levels) < 3:
        warnings.append(
            "Very low analyte coverage for semiquant training. Collect more analytes/levels before upgrade."
        )

    sparse_levels = [
        (analyte, level, count)
        for (analyte, level), count in level_counts.items()
        if count < 5
    ]
    if sparse_levels:
        warnings.append(
            f"{len(sparse_levels)} analyte-level groups have fewer than 5 samples."
        )

    summary = {
        "features_path": str(FEATURES_PATH),
        "total_rows": len(rows),
        "usable_semiquant_rows": usable_rows,
        "analyte_count": len(analyte_levels),
        "levels_per_analyte": {
            analyte: sorted(list(levels))
            for analyte, levels in sorted(analyte_levels.items())
        },
    }

    return ReadinessResult(
        ready=len(blockers) == 0,
        mode="semiquant",
        blockers=blockers,
        warnings=warnings,
        summary=summary,
    )


def print_human(result: ReadinessResult) -> None:
    print(f"Training readiness mode: {result.mode}")
    print(f"features.csv: {result.summary.get('features_path')}")

    if result.mode == "binary":
        print(f"Total rows: {result.summary.get('total_rows', 0)}")
        print(f"Usable binary rows: {result.summary.get('usable_binary_rows', 0)}")
        counts = result.summary.get("class_counts", {})
        print(
            "Class counts: "
            f"Normal={counts.get('Normal', 0)}, "
            f"Abnormal={counts.get('Abnormal', 0)}"
        )

        split_counts = result.summary.get("split_class_counts", {})
        if split_counts:
            print("Split coverage:")
            for split, split_count in split_counts.items():
                print(
                    f"  {split:10s} "
                    f"Normal={split_count.get('Normal', 0):3d} "
                    f"Abnormal={split_count.get('Abnormal', 0):3d}"
                )

        lights = result.summary.get("lights_by_class", {})
        if lights:
            print(
                "Light coverage: "
                f"Normal={lights.get('Normal', [])}, "
                f"Abnormal={lights.get('Abnormal', [])}"
            )
    else:
        print(f"Total rows: {result.summary.get('total_rows', 0)}")
        print(f"Usable semiquant rows: {result.summary.get('usable_semiquant_rows', 0)}")
        print(f"Analytes covered: {result.summary.get('analyte_count', 0)}")

    if result.blockers:
        print("\nBLOCKERS:")
        for blocker in result.blockers:
            print(f"  - {blocker}")

    if result.warnings:
        print("\nWARNINGS:")
        for warning in result.warnings:
            print(f"  - {warning}")

    if result.ready:
        print("\nREADY: dataset passes readiness checks.")
    else:
        print("\nNOT READY: fix blockers before running train.py.")


def main() -> None:
    args = parse_args()
    rows = load_rows()

    mode_counts = Counter(detect_mode(row) for row in rows)
    requested_mode = args.mode
    if requested_mode == "auto":
        mode = "binary" if mode_counts.get("binary", 0) > 0 else "semiquant"
    else:
        mode = requested_mode

    if mode == "binary":
        result = evaluate_binary(
            rows=rows,
            min_total=args.min_total,
            min_class=args.min_class,
            require_all_lights=args.require_all_lights,
            require_split_coverage=args.require_split_coverage,
        )
    else:
        result = evaluate_semiquant(rows)

    envelope = {
        "ready": result.ready,
        "mode": result.mode,
        "blockers": result.blockers,
        "warnings": result.warnings,
        "summary": result.summary,
        "mode_counts": dict(mode_counts),
    }

    if args.json:
        print(json.dumps(envelope, indent=2))
    else:
        print_human(result)

    sys.exit(0 if result.ready else 1)


if __name__ == "__main__":
    main()
