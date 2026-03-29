#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import pathlib

NORMAL_BASELINE: dict[str, str] = {
    "Leukocytes": "Neg",
    "Nitrite": "Neg",
    "Urobilinogen": "3.2",
    "Protein": "Neg",
    "pH": "6.0",
    "Blood": "Neg",
    "Specific Gravity": "1.015",
    "Ketone": "Neg",
    "Bilirubin": "Neg",
    "Glucose": "Neg",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Derive binary features.csv from semiquant rows")
    parser.add_argument(
        "--input",
        type=pathlib.Path,
        default=pathlib.Path(__file__).parent / "dataset" / "features.csv",
        help="Input semiquant features CSV",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path(__file__).parent / "dataset" / "features_binary_derived.csv",
        help="Output derived binary features CSV",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    with open(args.input, newline="", encoding="utf-8") as file:
        reader = csv.DictReader(file)
        rows = list(reader)
        fieldnames = list(reader.fieldnames or [])

    if not rows or not fieldnames:
        raise SystemExit(f"No rows found in {args.input}")

    converted = 0
    normal = 0
    abnormal = 0
    skipped = 0

    out_rows: list[dict[str, str]] = []
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()

        if analyte and level and analyte in NORMAL_BASELINE:
            is_normal = level == NORMAL_BASELINE[analyte]
            class_label = "Normal" if is_normal else "Abnormal"
            class_id = "1" if is_normal else "2"

            if "label_mode" in row:
                row["label_mode"] = "binary"
            row["class_label"] = class_label
            row["class_id"] = class_id
            row["label_raw"] = class_label
            row["label_canonical"] = class_label
            row["analyte"] = ""
            row["level"] = ""

            converted += 1
            if is_normal:
                normal += 1
            else:
                abnormal += 1
        else:
            skipped += 1

        out_rows.append(row)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)

    print(f"Input rows: {len(rows)}")
    print(f"Converted semiquant->binary rows: {converted}")
    print(f"  Normal: {normal}")
    print(f"  Abnormal: {abnormal}")
    print(f"Skipped rows: {skipped}")
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()
