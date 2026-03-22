#!/usr/bin/env python3
"""
Create/apply multi-analyte semiquant annotations for a training package ZIP.

This script supports the color-wheel workflow where each image contains all 10
pads and should carry levels for all analytes.

Workflow:
1) Generate template CSV from an existing package:
   python pipeline/annotate_multianalyte_package.py \
     --input-zip "C:/.../COLORWHEEL_2700_READY.zip" \
     --write-template "C:/.../labels/COLORWHEEL_2700_multianalyte.csv"

2) Fill template columns:
   leukocytes_level,nitrite_level,urobilinogen_level,protein_level,ph_level,
   blood_level,specific_gravity_level,ketone_level,bilirubin_level,glucose_level

3) Apply annotations to produce semiquant package:
   python pipeline/annotate_multianalyte_package.py \
     --input-zip "C:/.../COLORWHEEL_2700_READY.zip" \
     --mapping-csv "C:/.../labels/COLORWHEEL_2700_multianalyte.csv" \
     --output-zip "C:/.../COLORWHEEL_2700_SEMIQUANT.zip"
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import zipfile

ANALYTES = [
    ("Leukocytes", "leukocytes_level"),
    ("Nitrite", "nitrite_level"),
    ("Urobilinogen", "urobilinogen_level"),
    ("Protein", "protein_level"),
    ("pH", "ph_level"),
    ("Blood", "blood_level"),
    ("Specific Gravity", "specific_gravity_level"),
    ("Ketone", "ketone_level"),
    ("Bilirubin", "bilirubin_level"),
    ("Glucose", "glucose_level"),
]

ANALYTE_LEVEL_COLUMNS = [column for _, column in ANALYTES]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Annotate package with multi-analyte semiquant levels")
    parser.add_argument("--input-zip", required=True, type=pathlib.Path, help="Source package ZIP")
    parser.add_argument("--output-zip", type=pathlib.Path, default=None, help="Output package ZIP")
    parser.add_argument("--mapping-csv", type=pathlib.Path, default=None, help="Annotation CSV to apply")
    parser.add_argument("--write-template", type=pathlib.Path, default=None, help="Write annotation template CSV")
    parser.add_argument(
        "--drop-unmapped",
        action="store_true",
        help="Drop rows not found in mapping CSV (default keeps existing row)",
    )
    return parser.parse_args()


def read_index(zip_path: pathlib.Path) -> tuple[list[dict[str, str]], list[zipfile.ZipInfo]]:
    with zipfile.ZipFile(zip_path, "r") as archive:
        names = archive.namelist()
        if "training_index.csv" not in names:
            raise ValueError(f"No training_index.csv found in {zip_path}")

        with archive.open("training_index.csv") as file:
            rows = list(csv.DictReader(io.TextIOWrapper(file, encoding="utf-8")))

        infos = archive.infolist()

    return rows, infos


def write_template(template_path: pathlib.Path, rows: list[dict[str, str]]) -> None:
    template_path.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = ["relative_image_path", "image_name"] + ANALYTE_LEVEL_COLUMNS + ["notes"]

    with open(template_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            rel = row.get("relative_image_path", "").strip()
            item = {
                "relative_image_path": rel,
                "image_name": pathlib.Path(rel).name,
                "notes": "",
            }
            for column in ANALYTE_LEVEL_COLUMNS:
                item[column] = ""
            writer.writerow(item)


def load_mapping(mapping_csv: pathlib.Path) -> dict[str, dict[str, str]]:
    with open(mapping_csv, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    mapping: dict[str, dict[str, str]] = {}

    for row in rows:
        rel = row.get("relative_image_path", "").strip()
        image_name = row.get("image_name", "").strip()

        levels = {column: row.get(column, "").strip() for column in ANALYTE_LEVEL_COLUMNS}
        if not any(levels.values()):
            continue

        if rel:
            mapping[rel] = levels
        if image_name:
            mapping[image_name] = levels

    if not mapping:
        raise ValueError("No usable analyte levels found in mapping CSV.")

    return mapping


def apply_mapping(
    rows: list[dict[str, str]],
    mapping: dict[str, dict[str, str]],
    drop_unmapped: bool,
) -> tuple[list[dict[str, str]], int, int]:
    out_rows: list[dict[str, str]] = []
    changed = 0
    dropped = 0

    for row in rows:
        rel = row.get("relative_image_path", "").strip()
        image_name = pathlib.Path(rel).name
        levels = mapping.get(rel) or mapping.get(image_name)

        if levels is None:
            if drop_unmapped:
                dropped += 1
                continue
            out_rows.append(dict(row))
            continue

        updated = dict(row)

        for column in ANALYTE_LEVEL_COLUMNS:
            updated[column] = levels.get(column, "")

        if "label" in updated:
            updated["label"] = ""

        if updated != row:
            changed += 1

        out_rows.append(updated)

    return out_rows, changed, dropped


def write_package(
    input_zip: pathlib.Path,
    output_zip: pathlib.Path,
    rows: list[dict[str, str]],
) -> None:
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(input_zip, "r") as src, zipfile.ZipFile(
        output_zip,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as dst:
        for info in src.infolist():
            if info.filename == "training_index.csv":
                continue
            dst.writestr(info, src.read(info.filename))

        if not rows:
            raise ValueError("No rows remain to write.")

        fieldnames = list(rows[0].keys())
        for column in ANALYTE_LEVEL_COLUMNS:
            if column not in fieldnames:
                fieldnames.append(column)

        buffer = io.StringIO()
        writer = csv.DictWriter(buffer, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
        dst.writestr("training_index.csv", buffer.getvalue().encode("utf-8"))


def main() -> None:
    args = parse_args()

    input_zip = args.input_zip.resolve()
    if not input_zip.exists():
        raise FileNotFoundError(f"Input ZIP not found: {input_zip}")

    rows, _ = read_index(input_zip)

    if args.write_template is not None:
        template_path = args.write_template.resolve()
        write_template(template_path, rows)
        print(f"Template written: {template_path}")
        print(f"Rows listed: {len(rows)}")
        if args.mapping_csv is None:
            return

    if args.mapping_csv is None:
        raise ValueError("--mapping-csv is required unless using only --write-template")

    mapping = load_mapping(args.mapping_csv.resolve())
    updated_rows, changed, dropped = apply_mapping(rows, mapping, args.drop_unmapped)

    default_output = input_zip.with_name(f"{input_zip.stem}_SEMIQUANT.zip")
    output_zip = args.output_zip.resolve() if args.output_zip else default_output

    write_package(input_zip=input_zip, output_zip=output_zip, rows=updated_rows)

    print(f"Semiquant package written: {output_zip}")
    print(f"Rows total: {len(rows)}")
    print(f"Rows changed: {changed}")
    print(f"Rows dropped: {dropped}")


if __name__ == "__main__":
    main()
