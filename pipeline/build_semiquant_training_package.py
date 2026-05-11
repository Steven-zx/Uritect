#!/usr/bin/env python3
"""
Build semiquant training ZIP package from RHU sample master + image log.

This script creates a package compatible with pipeline/ingest.py containing:
  - training_index.csv
  - images/<copied files>

Compared to build_training_package.py, this script is designed for multi-analyte
labels from field templates and supports participant/event split manifests.
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import sys
import zipfile
from datetime import datetime


IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
DEFAULT_PACKAGES_DIR = pathlib.Path.home() / "Documents" / "uritect_training_dataset" / "packages"

ANALYTE_LEVEL_COLUMNS = [
    "leukocytes_level",
    "nitrite_level",
    "urobilinogen_level",
    "protein_level",
    "ph_level",
    "blood_level",
    "specific_gravity_level",
    "ketone_level",
    "bilirubin_level",
    "glucose_level",
]

TRUTHY = {"1", "true", "yes", "y"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build semiquant training ZIP package from RHU CSV templates")
    parser.add_argument("--sample-master", required=True, type=pathlib.Path, help="Path to rhu_sample_master CSV")
    parser.add_argument("--image-log", required=True, type=pathlib.Path, help="Path to rhu_image_log CSV")
    parser.add_argument(
        "--images-dir",
        required=True,
        type=pathlib.Path,
        help="Root folder containing transferred image files",
    )
    parser.add_argument(
        "--split-manifest",
        type=pathlib.Path,
        default=None,
        help="Optional CSV with split assignment by event_id or participant_id",
    )
    parser.add_argument(
        "--default-split",
        choices=["train", "val", "test"],
        default="train",
        help="Split to use when split-manifest is not provided or no match is found",
    )
    parser.add_argument("--batch-id", default="", help="Batch ID written to training_index.csv")
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=DEFAULT_PACKAGES_DIR,
        help=f"Output directory for ZIP package (default: {DEFAULT_PACKAGES_DIR})",
    )
    parser.add_argument("--zip-name", default="", help="Output ZIP name (optional)")
    parser.add_argument(
        "--recursive-images",
        action="store_true",
        help="Search images recursively in --images-dir",
    )
    parser.add_argument(
        "--include-qc-fail",
        action="store_true",
        help="Include rows where qc_pass != 1 (default excludes these)",
    )
    parser.add_argument(
        "--require-medtech-complete",
        action="store_true",
        help="Require medtech_read_complete == 1",
    )
    parser.add_argument(
        "--allow-missing-image",
        action="store_true",
        help="Skip missing image files instead of failing",
    )
    return parser.parse_args()


def _safe_token(raw: str) -> str:
    token = "".join(char if (char.isalnum() or char in "_-") else "_" for char in raw.strip())
    token = token.strip("_")
    return token or "batch"


def _is_truthy(raw: str) -> bool:
    return str(raw).strip().lower() in TRUTHY


def _norm_light(raw: str) -> str:
    light = str(raw).strip()
    if light.endswith("K") or light.endswith("k"):
        light = light[:-1].strip()
    return light


def _read_csv(path: pathlib.Path) -> list[dict[str, str]]:
    with open(path, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))
    if not rows:
        raise ValueError(f"CSV has no data rows: {path}")
    return rows


def _check_required_columns(rows: list[dict[str, str]], required: list[str], label: str) -> None:
    fieldnames = list(rows[0].keys())
    missing = [column for column in required if column not in fieldnames]
    if missing:
        raise ValueError(f"Missing required columns in {label}: {missing}")


def _load_split_manifest(split_manifest_path: pathlib.Path) -> tuple[dict[str, str], dict[str, str]]:
    rows = _read_csv(split_manifest_path)
    fieldnames = set(rows[0].keys())
    if "split" not in fieldnames:
        raise ValueError("split-manifest must include 'split' column")

    by_event: dict[str, str] = {}
    by_participant: dict[str, str] = {}
    for row in rows:
        split = str(row.get("split", "")).strip().lower()
        if split not in {"train", "val", "test"}:
            continue
        event_id = str(row.get("event_id", "")).strip()
        participant_id = str(row.get("participant_id", "")).strip()
        if event_id:
            by_event[event_id] = split
        if participant_id:
            by_participant[participant_id] = split

    if not by_event and not by_participant:
        raise ValueError("split-manifest had no usable event_id or participant_id assignments")
    return by_event, by_participant


def _build_image_lookup(images_dir: pathlib.Path, recursive: bool) -> dict[str, pathlib.Path]:
    paths = images_dir.rglob("*") if recursive else images_dir.iterdir()
    file_candidates = [path for path in paths if path.is_file() and path.suffix.lower() in IMAGE_EXTS]

    if not file_candidates:
        raise ValueError(f"No image files found under {images_dir}")

    lookup: dict[str, pathlib.Path] = {}
    duplicates: set[str] = set()
    for path in sorted(file_candidates):
        name = path.name
        if name in lookup:
            duplicates.add(name)
            continue
        lookup[name] = path

    if duplicates:
        sample = sorted(duplicates)[:5]
        raise ValueError(
            "Duplicate image names found in images-dir; use unique filenames or separate folders. "
            f"Examples: {sample}"
        )

    return lookup


def _event_label_rows(
    sample_rows: list[dict[str, str]],
    include_qc_fail: bool,
    require_medtech_complete: bool,
) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}

    for row in sample_rows:
        participant_id = str(row.get("participant_id", "")).strip()
        event_id = str(row.get("event_id", "")).strip()
        light_kelvin = _norm_light(row.get("light_kelvin", ""))

        if not participant_id or not event_id or not light_kelvin:
            continue
        if not include_qc_fail and not _is_truthy(row.get("qc_pass", "")):
            continue
        if require_medtech_complete and not _is_truthy(row.get("medtech_read_complete", "")):
            continue

        label_row = {
            "participant_id": participant_id,
            "event_id": event_id,
            "sample_id": str(row.get("sample_id", "")).strip(),
            "light_kelvin": light_kelvin,
        }
        for column in ANALYTE_LEVEL_COLUMNS:
            label_row[column] = str(row.get(column, "")).strip()

        # Last-wins on duplicate event rows in source CSV.
        out[event_id] = label_row

    if not out:
        raise ValueError("No usable sample_master rows after filtering.")

    return out


def _resolve_split(
    event_id: str,
    participant_id: str,
    default_split: str,
    split_by_event: dict[str, str],
    split_by_participant: dict[str, str],
) -> str:
    return split_by_event.get(event_id) or split_by_participant.get(participant_id) or default_split


def main() -> None:
    args = parse_args()

    sample_master_path = args.sample_master.resolve()
    image_log_path = args.image_log.resolve()
    images_dir = args.images_dir.resolve()

    if not sample_master_path.exists():
        print(f"sample-master not found: {sample_master_path}", file=sys.stderr)
        sys.exit(2)
    if not image_log_path.exists():
        print(f"image-log not found: {image_log_path}", file=sys.stderr)
        sys.exit(2)
    if not images_dir.exists() or not images_dir.is_dir():
        print(f"images-dir not found or not a directory: {images_dir}", file=sys.stderr)
        sys.exit(2)

    try:
        sample_rows = _read_csv(sample_master_path)
        image_rows = _read_csv(image_log_path)
        _check_required_columns(
            sample_rows,
            ["participant_id", "event_id", "sample_id", "light_kelvin", "qc_pass", "medtech_read_complete"]
            + ANALYTE_LEVEL_COLUMNS,
            "sample-master",
        )
        _check_required_columns(
            image_rows,
            ["event_id", "participant_id", "sample_id", "light_kelvin", "file_name", "qc_pass"],
            "image-log",
        )

        split_by_event: dict[str, str] = {}
        split_by_participant: dict[str, str] = {}
        if args.split_manifest is not None:
            split_by_event, split_by_participant = _load_split_manifest(args.split_manifest.resolve())

        image_lookup = _build_image_lookup(images_dir, recursive=args.recursive_images)
        labels_by_event = _event_label_rows(
            sample_rows,
            include_qc_fail=args.include_qc_fail,
            require_medtech_complete=args.require_medtech_complete,
        )
    except ValueError as error:
        print(f"Validation failed: {error}", file=sys.stderr)
        sys.exit(1)

    batch_id = args.batch_id.strip() or _safe_token(sample_master_path.stem)
    timestamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    zip_name = args.zip_name.strip() or f"{batch_id}_{timestamp}.zip"
    if not zip_name.lower().endswith(".zip"):
        zip_name += ".zip"

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    zip_path = output_dir / zip_name

    rows_out: list[dict[str, str]] = []
    missing_image_files: list[str] = []
    missing_event_labels = 0
    skipped_qc = 0
    copied_sources: list[tuple[pathlib.Path, str]] = []
    seen_zip_names: set[str] = set()

    for row in image_rows:
        event_id = str(row.get("event_id", "")).strip()
        participant_id = str(row.get("participant_id", "")).strip()
        sample_id = str(row.get("sample_id", "")).strip()
        image_name = str(row.get("file_name", "")).strip()

        if not event_id or not participant_id or not image_name:
            continue

        if not args.include_qc_fail and not _is_truthy(row.get("qc_pass", "")):
            skipped_qc += 1
            continue

        label_info = labels_by_event.get(event_id)
        if label_info is None:
            missing_event_labels += 1
            continue

        src = image_lookup.get(image_name)
        if src is None:
            missing_image_files.append(image_name)
            continue

        split = _resolve_split(
            event_id=event_id,
            participant_id=participant_id,
            default_split=args.default_split,
            split_by_event=split_by_event,
            split_by_participant=split_by_participant,
        )

        zip_image_name = image_name
        if zip_image_name in seen_zip_names:
            stem = pathlib.Path(image_name).stem
            suffix = pathlib.Path(image_name).suffix
            zip_image_name = f"{stem}_{len(seen_zip_names):05d}{suffix}"
        seen_zip_names.add(zip_image_name)

        out_row = {
            "event_id": event_id,
            "batch_id": batch_id,
            "split": split,
            "light_kelvin": label_info["light_kelvin"],
            "label": "",
            "relative_image_path": f"images/{zip_image_name}",
            "participant_id": participant_id,
            "sample_id": sample_id,
        }
        for column in ANALYTE_LEVEL_COLUMNS:
            out_row[column] = label_info[column]

        rows_out.append(out_row)
        copied_sources.append((src, zip_image_name))

    if missing_image_files and not args.allow_missing_image:
        print("Missing images referenced in image-log (first 20):", file=sys.stderr)
        for name in sorted(set(missing_image_files))[:20]:
            print(f"  - {name}", file=sys.stderr)
        sys.exit(1)

    if not rows_out:
        print("No rows to package after filtering. Nothing written.", file=sys.stderr)
        sys.exit(1)

    fieldnames = [
        "event_id",
        "batch_id",
        "split",
        "light_kelvin",
        "label",
        "relative_image_path",
        "participant_id",
        "sample_id",
    ] + ANALYTE_LEVEL_COLUMNS

    csv_buffer = io.StringIO()
    writer = csv.DictWriter(csv_buffer, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows_out)

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("training_index.csv", csv_buffer.getvalue().encode("utf-8"))
        for src, zip_name_member in copied_sources:
            archive.write(src, arcname=f"images/{zip_name_member}")

    split_counts: dict[str, int] = {"train": 0, "val": 0, "test": 0}
    for row in rows_out:
        split_counts[row["split"]] = split_counts.get(row["split"], 0) + 1

    print(f"Created semiquant package: {zip_path}")
    print(f"Rows written: {len(rows_out)}")
    print(f"Rows skipped (image qc): {skipped_qc}")
    print(f"Rows skipped (missing sample-master event): {missing_event_labels}")
    print(f"Missing images: {len(missing_image_files)}")
    print("Split counts:")
    print(f"  train: {split_counts.get('train', 0)}")
    print(f"  val:   {split_counts.get('val', 0)}")
    print(f"  test:  {split_counts.get('test', 0)}")
    if missing_image_files and args.allow_missing_image:
        print("First missing images (allowed):")
        for name in sorted(set(missing_image_files))[:10]:
            print(f"  - {name}")

    print("\nNext steps:")
    print("  1) python pipeline/ingest.py")
    print("  2) python pipeline/validate_semiquant_labels.py --strict")
    print("  3) python pipeline/check_training_readiness.py --json")
    print("  4) python pipeline/train.py --enforce-readiness")


if __name__ == "__main__":
    main()
