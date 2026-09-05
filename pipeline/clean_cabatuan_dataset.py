#!/usr/bin/env python3
"""Clean raw Cabatuan labels/photos into Uritect semiquant packages.

Rules implemented from the Cabatuan collection notes:
- correlate Excel rows to photo folders using the ID column
- each sample folder contains three photos ordered by capture time
- lowest timestamp -> Cool, middle -> Warm, highest -> Daylight
- write cleaned copies; do not modify the original uploaded ZIP/XLSX files
"""

from __future__ import annotations

import argparse
import csv
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd


ANALYTES = [
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
]

ANALYTE_OUTPUT_COLUMNS = {
    "Leukocytes": "leukocytes_level",
    "Nitrite": "nitrite_level",
    "Urobilinogen": "urobilinogen_level",
    "Protein": "protein_level",
    "pH": "ph_level",
    "Blood": "blood_level",
    "Specific Gravity": "specific_gravity_level",
    "Ketone": "ketone_level",
    "Bilirubin": "bilirubin_level",
    "Glucose": "glucose_level",
}

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
LIGHT_ORDER = ["Cool", "Warm", "Daylight"]


@dataclass(frozen=True)
class DatasetInputs:
    dataset_dir: Path
    label_xlsx: Path
    photos_zip: Path
    batch_id: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Clean Cabatuan raw labels/photos.")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("new_uritect_dataset"),
        help="Root containing uritect_2026-7-15_Cabatuan and uritect_2026-7-17_Cabatuan.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path("pipeline/dataset/cabatuan_cleaned"),
        help="Output folder for cleaned photos, CSVs, and package ZIPs.",
    )
    parser.add_argument(
        "--dates",
        nargs="*",
        default=["2026-7-15", "2026-7-17"],
        help="Cabatuan date tokens to process.",
    )
    return parser.parse_args()


def _norm_id(value: Any) -> str:
    if pd.isna(value):
        return ""
    text = str(value).strip()
    if text.endswith(".0") and text[:-2].isdigit():
        text = text[:-2]
    return text


def _id_aliases(value: str) -> set[str]:
    text = _norm_id(value)
    aliases = {text} if text else set()
    if text.isdigit():
        numeric = str(int(text))
        aliases.add(numeric)
        aliases.add(numeric.zfill(3))
    return aliases


def _norm_col(value: Any) -> str:
    return re.sub(r"[^a-z0-9]+", "", str(value).strip().lower())


def _safe_token(raw: str) -> str:
    token = re.sub(r"[^A-Za-z0-9_-]+", "_", raw.strip()).strip("_")
    return token or "sample"


def _timestamp_key(path: Path) -> tuple[int, str]:
    numbers = re.findall(r"\d+", path.stem)
    if not numbers:
        return (0, path.name)
    return (int(numbers[-1]), path.name)


def _find_inputs(root: Path, date_token: str) -> DatasetInputs:
    dataset_dir = root / f"uritect_{date_token}_Cabatuan"
    if not dataset_dir.exists():
        raise FileNotFoundError(f"Missing dataset folder: {dataset_dir}")

    label_matches = sorted(dataset_dir.glob("*Labels*.xlsx"))
    zip_matches = sorted(dataset_dir.glob("*RHU*.zip"))
    if len(label_matches) != 1:
        raise FileNotFoundError(f"Expected one labels xlsx in {dataset_dir}, found {len(label_matches)}")
    if len(zip_matches) != 1:
        raise FileNotFoundError(f"Expected one RHU zip in {dataset_dir}, found {len(zip_matches)}")

    return DatasetInputs(
        dataset_dir=dataset_dir,
        label_xlsx=label_matches[0],
        photos_zip=zip_matches[0],
        batch_id=f"uritect_{date_token}_Cabatuan",
    )


def _read_labels(path: Path) -> tuple[pd.DataFrame, str, dict[str, str]]:
    df = pd.read_excel(path, sheet_name=0, dtype=str)
    df = df.dropna(how="all")
    if df.empty:
        raise ValueError(f"No label rows found in {path}")

    columns_by_norm = {_norm_col(column): str(column) for column in df.columns}
    id_column = None
    for candidate in ("id", "sampleid", "sample", "participantid"):
        if candidate in columns_by_norm:
            id_column = columns_by_norm[candidate]
            break
    if id_column is None:
        raise ValueError(f"Could not find ID column in {path}. Columns: {list(df.columns)}")

    analyte_columns: dict[str, str] = {}
    for analyte in ANALYTES:
        wanted = _norm_col(analyte)
        candidates = [
            column
            for key, column in columns_by_norm.items()
            if key == wanted or key.endswith(wanted) or wanted in key
        ]
        if not candidates and analyte == "pH":
            candidates = [column for key, column in columns_by_norm.items() if key == "ph"]
        if not candidates:
            raise ValueError(f"Missing analyte column for {analyte} in {path}. Columns: {list(df.columns)}")
        analyte_columns[analyte] = candidates[0]

    df["_clean_id"] = df[id_column].map(_norm_id)
    df = df[df["_clean_id"] != ""].copy()
    return df, id_column, analyte_columns


def _extract_zip(zip_path: Path, extract_dir: Path) -> Path:
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(extract_dir)

    dirs = [path for path in extract_dir.rglob("*") if path.is_dir()]
    image_dirs = [path for path in dirs if any(child.is_file() and child.suffix.lower() in IMAGE_EXTS for child in path.iterdir())]
    common_parent_counts: dict[Path, int] = {}
    for path in image_dirs:
        common_parent_counts[path.parent] = common_parent_counts.get(path.parent, 0) + 1
    if common_parent_counts:
        return max(common_parent_counts.items(), key=lambda item: item[1])[0]
    return extract_dir


def _folder_lookup(images_root: Path) -> dict[str, Path]:
    lookup: dict[str, Path] = {}
    for path in images_root.rglob("*"):
        if not path.is_dir():
            continue
        if not any(child.is_file() and child.suffix.lower() in IMAGE_EXTS for child in path.iterdir()):
            continue
        for alias in _id_aliases(path.name):
            lookup.setdefault(alias, path)
    return lookup


def _image_files(folder: Path) -> list[Path]:
    return sorted(
        [path for path in folder.iterdir() if path.is_file() and path.suffix.lower() in IMAGE_EXTS],
        key=_timestamp_key,
    )


def _level(row: pd.Series, column: str) -> str:
    value = row.get(column, "")
    if pd.isna(value):
        return ""
    text = str(value).strip()
    if text.endswith(".0") and text[:-2].isdigit():
        text = text[:-2]
    return text


def clean_one(inputs: DatasetInputs, output_root: Path) -> dict[str, Any]:
    labels, id_column, analyte_columns = _read_labels(inputs.label_xlsx)
    work_dir = output_root / inputs.batch_id
    extract_dir = work_dir / "_extracted_raw"
    photos_out = work_dir / "photos"
    package_path = work_dir / f"{inputs.batch_id}_holdout_package.zip"
    report_path = work_dir / f"{inputs.batch_id}_cleaning_report.csv"
    sample_master_path = work_dir / f"{inputs.batch_id}_sample_master_cleaned.csv"

    work_dir.mkdir(parents=True, exist_ok=True)
    if photos_out.exists():
        shutil.rmtree(photos_out)
    photos_out.mkdir(parents=True, exist_ok=True)

    images_root = _extract_zip(inputs.photos_zip, extract_dir)
    folders = _folder_lookup(images_root)

    report_rows: list[dict[str, str]] = []
    index_rows: list[dict[str, str]] = []
    sample_rows: list[dict[str, str]] = []
    copied_images: list[tuple[Path, str]] = []

    seen_ids: set[str] = set()
    duplicate_ids: set[str] = set()

    for _, row in labels.iterrows():
        sample_id = str(row["_clean_id"]).strip()
        if sample_id in seen_ids:
            duplicate_ids.add(sample_id)
            report_rows.append({"id": sample_id, "status": "skipped_duplicate_label_id", "detail": ""})
            continue
        seen_ids.add(sample_id)

        folder = None
        for alias in _id_aliases(sample_id):
            folder = folders.get(alias)
            if folder is not None:
                break
        if folder is None:
            report_rows.append({"id": sample_id, "status": "skipped_missing_photo_folder", "detail": ""})
            continue

        images = _image_files(folder)
        if len(images) != 3:
            report_rows.append({
                "id": sample_id,
                "status": "skipped_expected_3_images",
                "detail": f"found {len(images)}: {', '.join(path.name for path in images)}",
            })
            continue

        levels = {analyte: _level(row, source_col) for analyte, source_col in analyte_columns.items()}
        missing_levels = [analyte for analyte, value in levels.items() if not value]
        if missing_levels:
            report_rows.append({
                "id": sample_id,
                "status": "skipped_missing_labels",
                "detail": ", ".join(missing_levels),
            })
            continue

        safe_id = _safe_token(sample_id)
        sample_folder = photos_out / safe_id
        sample_folder.mkdir(parents=True, exist_ok=True)

        for image, light in zip(images, LIGHT_ORDER, strict=True):
            ext = image.suffix.lower() if image.suffix else ".jpg"
            cleaned_name = f"{safe_id}-{light}{ext}"
            dest = sample_folder / cleaned_name
            shutil.copy2(image, dest)
            relative_path = f"{safe_id}/{cleaned_name}"
            copied_images.append((dest, relative_path))

            event_id = f"{inputs.batch_id}_{safe_id}_{light}"
            index_row = {
                "event_id": event_id,
                "batch_id": inputs.batch_id,
                "split": "test",
                "light_kelvin": light,
                "label": "",
                "relative_image_path": f"images/{relative_path}",
                "participant_id": safe_id,
                "sample_id": safe_id,
            }
            for analyte, out_col in ANALYTE_OUTPUT_COLUMNS.items():
                index_row[out_col] = levels[analyte]
            index_rows.append(index_row)

            sample_row = dict(index_row)
            sample_row["source_label_id"] = sample_id
            sample_row["source_image_name"] = image.name
            sample_rows.append(sample_row)

        report_rows.append({
            "id": sample_id,
            "status": "ok",
            "detail": "; ".join(f"{src.name}->{safe_id}-{light}{src.suffix.lower()}" for src, light in zip(images, LIGHT_ORDER, strict=True)),
        })

    matched_folders = {
        folder.resolve()
        for sample_id in seen_ids
        for alias in _id_aliases(sample_id)
        for folder in [folders.get(alias)]
        if folder is not None
    }
    unique_photo_folders = sorted({path.resolve() for path in folders.values()})
    for folder in unique_photo_folders:
        if folder not in matched_folders:
            report_rows.append({"id": folder.name, "status": "photo_folder_without_label", "detail": ""})

    if not index_rows:
        raise ValueError(f"No usable Cabatuan rows produced for {inputs.batch_id}")

    fieldnames = [
        "event_id",
        "batch_id",
        "split",
        "light_kelvin",
        "label",
        "relative_image_path",
        "participant_id",
        "sample_id",
    ] + list(ANALYTE_OUTPUT_COLUMNS.values())

    with open(sample_master_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames + ["source_label_id", "source_image_name"])
        writer.writeheader()
        writer.writerows(sample_rows)

    with open(report_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=["id", "status", "detail"])
        writer.writeheader()
        writer.writerows(report_rows)

    if package_path.exists():
        package_path.unlink()
    csv_buffer_rows = []
    for row in index_rows:
        csv_buffer_rows.append({key: row.get(key, "") for key in fieldnames})

    with zipfile.ZipFile(package_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        from io import StringIO

        buffer = StringIO()
        writer = csv.DictWriter(buffer, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(csv_buffer_rows)
        archive.writestr("training_index.csv", buffer.getvalue())
        for path, relative_path in copied_images:
            archive.write(path, arcname=f"images/{relative_path}")

    status_counts = pd.Series([row["status"] for row in report_rows]).value_counts().to_dict()
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    return {
        "batch_id": inputs.batch_id,
        "label_file": str(inputs.label_xlsx),
        "photo_zip": str(inputs.photos_zip),
        "id_column": id_column,
        "analyte_columns": analyte_columns,
        "usable_samples": len({row["sample_id"] for row in index_rows}),
        "package_rows": len(index_rows),
        "package_path": str(package_path),
        "report_path": str(report_path),
        "sample_master_path": str(sample_master_path),
        "status_counts": status_counts,
        "duplicate_ids": sorted(duplicate_ids),
    }


def main() -> None:
    args = parse_args()
    summaries: list[dict[str, Any]] = []
    for date_token in args.dates:
        try:
            inputs = _find_inputs(args.root, date_token)
            summaries.append(clean_one(inputs, args.output_root))
        except Exception as error:
            print(f"[FAILED] {date_token}: {error}", file=sys.stderr)
            sys.exit(1)

    for summary in summaries:
        print(f"\n{summary['batch_id']}")
        print(f"  ID column: {summary['id_column']}")
        print(f"  Usable samples: {summary['usable_samples']}")
        print(f"  Package rows: {summary['package_rows']}")
        print(f"  Package: {summary['package_path']}")
        print(f"  Report:  {summary['report_path']}")
        print("  Status counts:")
        for status, count in sorted(summary["status_counts"].items()):
            print(f"    {status}: {count}")


if __name__ == "__main__":
    main()
