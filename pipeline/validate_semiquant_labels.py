#!/usr/bin/env python3
"""
Validate semiquant label integrity in pipeline/dataset/features.csv.

Checks:
- analyte exists in known analyte schema
- level token is canonical/alias-resolvable for that analyte
- required analyte HSV feature columns are present
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys

from semiquant_schema import ANALYTE_LEVEL_SCHEMA, canonicalize_level
from vision_pipeline import feature_columns_for_analyte

FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_REPORT = pathlib.Path(__file__).parent / "output" / "semiquant_label_validation_standalone.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate semiquant rows in features.csv")
    parser.add_argument("--features", type=pathlib.Path, default=FEATURES_PATH, help="Path to features.csv")
    parser.add_argument("--report", type=pathlib.Path, default=DEFAULT_REPORT, help="Path to JSON report output")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero on invalid rows")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    features_path = args.features.resolve()

    if not features_path.exists():
        print(f"features.csv not found: {features_path}")
        sys.exit(2)

    with open(features_path, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    semiquant_rows = []
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        if analyte and level:
            semiquant_rows.append(row)

    invalid = []
    valid_count = 0

    for idx, row in enumerate(semiquant_rows, start=1):
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()

        if analyte not in ANALYTE_LEVEL_SCHEMA:
            invalid.append(
                {
                    "row_index": idx,
                    "event_id": row.get("event_id", ""),
                    "reason": f"invalid analyte '{analyte}'",
                    "analyte": analyte,
                    "level": level,
                }
            )
            continue

        canonical = canonicalize_level(analyte, level)
        if canonical is None:
            invalid.append(
                {
                    "row_index": idx,
                    "event_id": row.get("event_id", ""),
                    "reason": f"invalid level '{level}' for analyte '{analyte}'",
                    "analyte": analyte,
                    "level": level,
                    "allowed_levels": ANALYTE_LEVEL_SCHEMA[analyte],
                }
            )
            continue

        missing_cols = [
            col for col in feature_columns_for_analyte(analyte) if row.get(col, "").strip() == ""
        ]
        if missing_cols:
            invalid.append(
                {
                    "row_index": idx,
                    "event_id": row.get("event_id", ""),
                    "reason": "missing analyte feature columns",
                    "analyte": analyte,
                    "level": level,
                    "missing_columns": missing_cols,
                }
            )
            continue

        valid_count += 1

    report = {
        "features_path": str(features_path),
        "total_rows": len(rows),
        "semiquant_rows": len(semiquant_rows),
        "valid_rows": valid_count,
        "invalid_rows": len(invalid),
        "invalid_examples": invalid[:100],
    }

    report_path = args.report.resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Semiquant rows: {len(semiquant_rows)}")
    print(f"Valid: {valid_count}")
    print(f"Invalid: {len(invalid)}")
    print(f"Report: {report_path}")

    if args.strict and invalid:
        sys.exit(1)


if __name__ == "__main__":
    main()
