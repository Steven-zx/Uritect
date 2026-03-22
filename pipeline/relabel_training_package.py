#!/usr/bin/env python3
"""
Relabel an existing Uritect training package ZIP.

Use this to convert binary placeholders (e.g., Normal) to semiquant labels
in the format: <Analyte>:<Level>

Examples:
  # 1) Generate a template CSV listing all images in package
  python pipeline/relabel_training_package.py \
    --input-zip "C:/Users/acer/Documents/uritect_training_dataset/packages/COLORWHEEL_2700_READY.zip" \
    --write-template "C:/Users/acer/Documents/uritect_training_dataset/labels/COLORWHEEL_2700_labels.csv"

  # 2) Apply per-image labels from template CSV and write a new ZIP
  python pipeline/relabel_training_package.py \
    --input-zip "C:/Users/acer/Documents/uritect_training_dataset/packages/COLORWHEEL_2700_READY.zip" \
    --mapping-csv "C:/Users/acer/Documents/uritect_training_dataset/labels/COLORWHEEL_2700_labels.csv" \
    --output-zip "C:/Users/acer/Documents/uritect_training_dataset/packages/COLORWHEEL_2700_SEMIQUANT.zip"
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import zipfile

ANALYTE_ORDER = {
    "Leukocytes",
    "Nitrite",
    "Urobilinogen",
    "Protein",
    "pH",
    "Blood",
    "Specific Gravity",
    "Ketone",
    "Bilirubin",
    "Glucose",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Relabel training_index.csv inside a package ZIP")
    parser.add_argument("--input-zip", required=True, type=pathlib.Path, help="Path to source package ZIP")
    parser.add_argument(
        "--output-zip",
        type=pathlib.Path,
        default=None,
        help="Path to output ZIP (default: <input_stem>_RELABELED.zip)",
    )
    parser.add_argument(
        "--mapping-csv",
        type=pathlib.Path,
        default=None,
        help=(
            "CSV with per-image labels. Required columns: relative_image_path,label. "
            "Alternative key column: image_name"
        ),
    )
    parser.add_argument(
        "--set-label",
        default="",
        help="Set one label for all rows (e.g., Protein:1+).",
    )
    parser.add_argument(
        "--write-template",
        type=pathlib.Path,
        default=None,
        help="Write a template CSV for manual per-image labels and exit.",
    )
    parser.add_argument(
        "--drop-unmapped",
        action="store_true",
        help="Drop rows not found in mapping CSV. Default keeps original label when unmapped.",
    )
    return parser.parse_args()


def parse_semiquant_label(label: str) -> tuple[str, str] | None:
    trimmed = label.strip()
    if not trimmed or ":" not in trimmed:
        return None

    analyte, level = trimmed.split(":", 1)
    analyte = analyte.strip()
    level = level.strip()

    if analyte not in ANALYTE_ORDER or not level:
        return None

    return analyte, level


def read_index_rows(zip_path: pathlib.Path) -> tuple[list[dict[str, str]], list[str]]:
    with zipfile.ZipFile(zip_path, "r") as archive:
        names = archive.namelist()
        if "training_index.csv" not in names:
            raise ValueError(f"No training_index.csv found in {zip_path}")

        with archive.open("training_index.csv") as file:
            rows = list(csv.DictReader(io.TextIOWrapper(file, encoding="utf-8")))

    return rows, names


def write_template(template_path: pathlib.Path, rows: list[dict[str, str]]) -> None:
    template_path.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = ["relative_image_path", "image_name", "label", "notes"]
    with open(template_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()

        for row in rows:
            rel = row.get("relative_image_path", "").strip()
            image_name = pathlib.Path(rel).name
            writer.writerow(
                {
                    "relative_image_path": rel,
                    "image_name": image_name,
                    "label": "",
                    "notes": "",
                }
            )


def load_mapping(mapping_csv: pathlib.Path) -> dict[str, str]:
    with open(mapping_csv, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    mapping: dict[str, str] = {}
    for row in rows:
        rel = row.get("relative_image_path", "").strip()
        image_name = row.get("image_name", "").strip()
        label = row.get("label", "").strip()

        if not label:
            continue

        if parse_semiquant_label(label) is None:
            raise ValueError(
                f"Invalid semiquant label '{label}'. Expected format <Analyte>:<Level> "
                f"with analyte in {sorted(ANALYTE_ORDER)}"
            )

        if rel:
            mapping[rel] = label
        if image_name:
            mapping[image_name] = label

    if not mapping:
        raise ValueError("Mapping CSV has no usable labels.")

    return mapping


def relabel_rows(
    rows: list[dict[str, str]],
    mapping: dict[str, str] | None,
    set_label: str,
    drop_unmapped: bool,
) -> tuple[list[dict[str, str]], int, int]:
    output_rows: list[dict[str, str]] = []
    changed = 0
    dropped = 0

    for row in rows:
        rel = row.get("relative_image_path", "").strip()
        image_name = pathlib.Path(rel).name

        label = set_label
        if not label and mapping is not None:
            label = mapping.get(rel, mapping.get(image_name, ""))

        if not label:
            if drop_unmapped:
                dropped += 1
                continue
            output_rows.append(row)
            continue

        parsed = parse_semiquant_label(label)
        if parsed is None:
            raise ValueError(
                f"Invalid semiquant label '{label}'. Expected format <Analyte>:<Level>"
            )

        updated = dict(row)
        updated["label"] = label

        if updated != row:
            changed += 1

        output_rows.append(updated)

    return output_rows, changed, dropped


def write_relabeled_zip(
    input_zip: pathlib.Path,
    output_zip: pathlib.Path,
    new_rows: list[dict[str, str]],
) -> None:
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(input_zip, "r") as src, zipfile.ZipFile(
        output_zip,
        "w",
        compression=zipfile.ZIP_DEFLATED,
    ) as dst:
        for item in src.infolist():
            if item.filename == "training_index.csv":
                continue
            dst.writestr(item, src.read(item.filename))

        if not new_rows:
            raise ValueError("No rows remain after relabeling.")

        fieldnames = list(new_rows[0].keys())
        csv_buffer = io.StringIO()
        writer = csv.DictWriter(csv_buffer, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(new_rows)

        dst.writestr("training_index.csv", csv_buffer.getvalue().encode("utf-8"))


def main() -> None:
    args = parse_args()

    input_zip = args.input_zip.resolve()
    if not input_zip.exists():
        raise FileNotFoundError(f"Input ZIP not found: {input_zip}")

    if args.mapping_csv is None and not args.set_label and args.write_template is None:
        raise ValueError("Provide at least one of: --mapping-csv, --set-label, --write-template")

    rows, _ = read_index_rows(input_zip)

    if args.write_template is not None:
        write_template(args.write_template.resolve(), rows)
        print(f"Template written: {args.write_template.resolve()}")
        print(f"Rows listed: {len(rows)}")
        if args.mapping_csv is None and not args.set_label:
            return

    mapping = None
    if args.mapping_csv is not None:
        mapping = load_mapping(args.mapping_csv.resolve())

    set_label = args.set_label.strip()
    if set_label:
        if parse_semiquant_label(set_label) is None:
            raise ValueError(
                "--set-label must be semiquant in format <Analyte>:<Level> "
                f"with analyte in {sorted(ANALYTE_ORDER)}"
            )

    new_rows, changed, dropped = relabel_rows(
        rows=rows,
        mapping=mapping,
        set_label=set_label,
        drop_unmapped=args.drop_unmapped,
    )

    default_output = input_zip.with_name(f"{input_zip.stem}_RELABELED.zip")
    output_zip = args.output_zip.resolve() if args.output_zip is not None else default_output

    write_relabeled_zip(input_zip=input_zip, output_zip=output_zip, new_rows=new_rows)

    print(f"Relabeled ZIP written: {output_zip}")
    print(f"Rows total: {len(rows)}")
    print(f"Rows changed: {changed}")
    print(f"Rows dropped: {dropped}")


if __name__ == "__main__":
    main()
