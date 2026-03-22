#!/usr/bin/env python3
"""
Convert binary-labeled training packages to semiquant multi-analyte packages.

This script reads backup ZIP packages with binary labels (Normal/Abnormal),
creates 10-analyte semiquant columns, and writes semiquant-ready ZIPs.

Rules used:
- Normal -> fixed baseline levels (Neg / physiologic baseline)
- Abnormal -> deterministic cyclic assignment across non-baseline levels

Use this as a bootstrap conversion when original semiquant labels are missing.
Replace generated labels with true ground truth for thesis-grade evaluation.
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import zipfile
from typing import Any

from semiquant_schema import ANALYTE_LEVEL_SCHEMA, ANALYTE_ORDER


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

BINARY_NORMAL_KEYS = {"normal", "negative", "class1", "class_1", "class 1", "1"}
BINARY_ABNORMAL_KEYS = {"abnormal", "positive", "class2", "class_2", "class 2", "2"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert binary ZIP packages to semiquant ZIP packages")
    parser.add_argument(
        "--input-dir",
        type=pathlib.Path,
        required=True,
        help="Directory containing backup ZIP packages",
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        required=True,
        help="Directory to write semiquant ZIP packages",
    )
    parser.add_argument(
        "--pattern",
        default="*.zip",
        help="Glob pattern for source ZIP files (default: *.zip)",
    )
    parser.add_argument(
        "--only-binary-named",
        action="store_true",
        help="Only process ZIPs with names containing Normal/Abnormal/BATCH_",
    )
    return parser.parse_args()


def _is_binary_like_label(raw: str) -> bool:
    key = raw.strip().lower()
    return key in BINARY_NORMAL_KEYS or key in BINARY_ABNORMAL_KEYS


def _row_binary_state(row: dict[str, str]) -> str | None:
    for key in ("label", "class_label", "label_canonical", "label_raw", "class_id"):
        value = str(row.get(key, "")).strip()
        if not value:
            continue
        lowered = value.lower()
        if lowered in BINARY_NORMAL_KEYS or value == "1":
            return "normal"
        if lowered in BINARY_ABNORMAL_KEYS or value == "2":
            return "abnormal"
    return None


def _has_multianalyte_columns(fieldnames: list[str]) -> bool:
    expected = {f"{name.lower().replace(' ', '_')}_level" for name in ANALYTE_ORDER}
    return len(expected.intersection(set(fieldnames))) >= 5


def _non_baseline_levels(analyte: str) -> list[str]:
    all_levels = ANALYTE_LEVEL_SCHEMA[analyte]
    baseline = NORMAL_BASELINE[analyte]
    return [level for level in all_levels if level != baseline]


def _assign_levels(binary_state: str, row_index: int) -> dict[str, str]:
    levels: dict[str, str] = {}
    for analyte in ANALYTE_ORDER:
        col = f"{analyte.lower().replace(' ', '_')}_level"

        if binary_state == "normal":
            levels[col] = NORMAL_BASELINE[analyte]
            continue

        candidates = _non_baseline_levels(analyte)
        if not candidates:
            levels[col] = NORMAL_BASELINE[analyte]
            continue

        levels[col] = candidates[row_index % len(candidates)]

    return levels


def _convert_zip(source_zip: pathlib.Path, destination_zip: pathlib.Path) -> tuple[bool, dict[str, Any]]:
    with zipfile.ZipFile(source_zip, "r") as src:
        names = set(src.namelist())
        if "training_index.csv" not in names:
            return False, {"reason": "missing_training_index"}

        with src.open("training_index.csv") as f:
            rows = list(csv.DictReader(io.TextIOWrapper(f, encoding="utf-8")))

        if not rows:
            return False, {"reason": "empty_training_index"}

        fieldnames = list(rows[0].keys())
        if _has_multianalyte_columns(fieldnames):
            return False, {"reason": "already_semiquant"}

        binary_states: list[str | None] = [_row_binary_state(row) for row in rows]
        binary_like_count = sum(1 for item in binary_states if item is not None)
        if binary_like_count == 0:
            return False, {"reason": "not_binary_labeled"}

        converted_rows: list[dict[str, str]] = []
        normals = 0
        abnormals = 0

        for idx, (row, state) in enumerate(zip(rows, binary_states), start=0):
            if state is None:
                continue

            if state == "normal":
                normals += 1
            else:
                abnormals += 1

            out = dict(row)
            levels = _assign_levels(state, idx)
            out.update(levels)
            out["label"] = ""
            converted_rows.append(out)

        if not converted_rows:
            return False, {"reason": "no_rows_converted"}

        all_fields = list(converted_rows[0].keys())
        for analyte in ANALYTE_ORDER:
            col = f"{analyte.lower().replace(' ', '_')}_level"
            if col not in all_fields:
                all_fields.append(col)

        destination_zip.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(destination_zip, "w", compression=zipfile.ZIP_DEFLATED) as dst:
            for info in src.infolist():
                if info.filename == "training_index.csv":
                    continue
                dst.writestr(info, src.read(info.filename))

            buffer = io.StringIO()
            writer = csv.DictWriter(buffer, fieldnames=all_fields)
            writer.writeheader()
            writer.writerows(converted_rows)
            dst.writestr("training_index.csv", buffer.getvalue().encode("utf-8"))

    return True, {
        "rows_total": len(rows),
        "rows_converted": len(converted_rows),
        "normal_rows": normals,
        "abnormal_rows": abnormals,
    }


def _should_process_name(name: str, only_binary_named: bool) -> bool:
    lowered = name.lower()
    if "_semiquant" in lowered:
        return False
    if only_binary_named:
        return ("normal" in lowered) or ("abnormal" in lowered) or lowered.startswith("batch")
    return True


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()

    if not input_dir.exists():
        raise FileNotFoundError(f"Input directory not found: {input_dir}")

    zip_files = sorted(input_dir.glob(args.pattern))
    if not zip_files:
        print(f"No ZIP files found in {input_dir} with pattern {args.pattern}")
        return

    converted = 0
    skipped = 0

    print(f"Input ZIPs found: {len(zip_files)}")
    for source_zip in zip_files:
        if not _should_process_name(source_zip.name, args.only_binary_named):
            skipped += 1
            continue

        output_name = f"{source_zip.stem}_SEMIQUANT_FROM_BINARY.zip"
        output_zip = output_dir / output_name

        ok, info = _convert_zip(source_zip, output_zip)
        if ok:
            converted += 1
            print(
                f"[OK] {source_zip.name} -> {output_name} | "
                f"rows={info['rows_converted']} (normal={info['normal_rows']}, abnormal={info['abnormal_rows']})"
            )
        else:
            skipped += 1
            print(f"[SKIP] {source_zip.name} | {info.get('reason', 'unknown')}")

    print(f"\nDone. Converted: {converted}, Skipped: {skipped}")


if __name__ == "__main__":
    main()
