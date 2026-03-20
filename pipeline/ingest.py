#!/usr/bin/env python3
"""
Uritect training pipeline — ingestion stage.

Reads all training ZIPs from:
  ~/Documents/uritect_training_dataset/packages/

Outputs:
  pipeline/dataset/features.csv

This script implements burst-level vision preprocessing before feature extraction:
1) Macro-marker contour detection + perspective rectification
2) AWB using marker-center 10x10 patch
3) Grid-based 10-pad slicing using marker-calibrated px/mm
4) Temporal median filtering across burst frames
5) Mean HSV extraction for each of 10 pads

SUPPORTED LABEL FORMATS:
  1) Binary (current): Normal | Abnormal
  2) Semiquant (future): <AnalyteName>:<Level>
"""

from __future__ import annotations

import csv
import io
import pathlib
import sys
import zipfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from typing import Optional

try:
    from vision_pipeline import (
        ANALYTE_ORDER,
        BurstFeaturePipeline,
        decode_image_bytes,
        feature_columns_for_analyte,
        all_feature_columns,
    )
except ImportError as error:
    print(f"Failed to import vision pipeline modules: {error}", file=sys.stderr)
    print("Run from repository root and ensure dependencies are installed.", file=sys.stderr)
    sys.exit(1)

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

VALID_ANALYTES = set(ANALYTE_ORDER)

PACKAGES_DIR = pathlib.Path.home() / "Documents" / "uritect_training_dataset" / "packages"
OUTPUT_DIR = pathlib.Path(__file__).parent / "dataset"


@dataclass(frozen=True)
class ParsedLabel:
    label_mode: str
    label_canonical: str
    class_label: str
    class_id: str
    analyte: str
    level: str


@dataclass(frozen=True)
class BurstGroupKey:
    event_id: str
    batch_id: str
    split: str
    light_kelvin: str
    label_mode: str
    label_canonical: str
    class_label: str
    class_id: str
    analyte: str
    level: str


def _canonical_binary_label(raw: str) -> Optional[str]:
    key = raw.strip().lower()
    if not key:
        return None
    return BINARY_LABEL_ALIASES.get(key)


def parse_label(label: str) -> Optional[ParsedLabel]:
    trimmed = label.strip()
    if not trimmed:
        return None

    parts = trimmed.split(":", 1)
    if len(parts) == 2:
        analyte = parts[0].strip()
        level = parts[1].strip()
        if analyte in VALID_ANALYTES and level:
            return ParsedLabel(
                label_mode="semiquant",
                label_canonical=f"{analyte}:{level}",
                class_label="",
                class_id="",
                analyte=analyte,
                level=level,
            )

    binary = _canonical_binary_label(trimmed)
    if binary is not None:
        class_id = "1" if binary == "Normal" else "2"
        return ParsedLabel(
            label_mode="binary",
            label_canonical=binary,
            class_label=binary,
            class_id=class_id,
            analyte="",
            level=binary,
        )

    return None


def _safe_event_id(raw: str, zip_stem: str, row_index: int) -> str:
    trimmed = raw.strip()
    if trimmed:
        return trimmed
    return f"{zip_stem}_event_{row_index:04d}"


def _split_name(raw: str) -> str:
    split = raw.strip().lower()
    if split in {"train", "val", "test"}:
        return split
    return "train"


def process_zip(zip_path: pathlib.Path, pipeline: BurstFeaturePipeline) -> tuple[list[dict], int]:
    rows_out: list[dict] = []
    skipped_bursts = 0

    with zipfile.ZipFile(zip_path, "r") as zf:
        names = set(zf.namelist())
        if "training_index.csv" not in names:
            print(f"  [SKIP] No training_index.csv in {zip_path.name}")
            return rows_out, 0

        with zf.open("training_index.csv") as file:
            index_rows = list(csv.DictReader(io.TextIOWrapper(file, encoding="utf-8")))

        grouped_entries: dict[BurstGroupKey, list[str]] = defaultdict(list)

        for row_index, row in enumerate(index_rows, start=1):
            label_raw = row.get("label", "").strip()
            parsed = parse_label(label_raw)
            if parsed is None:
                print(
                    "  [SKIP] "
                    f"label='{label_raw}' -> use binary 'Normal/Abnormal' "
                    "or semiquant 'AnalyteName:Level'"
                )
                continue

            rel_path = row.get("relative_image_path", "").strip()
            image_name = "images/" + pathlib.Path(rel_path).name
            if image_name not in names:
                print(f"  [SKIP] {image_name} not found in ZIP")
                continue

            key = BurstGroupKey(
                event_id=_safe_event_id(row.get("event_id", ""), zip_path.stem, row_index),
                batch_id=row.get("batch_id", "").strip(),
                split=_split_name(row.get("split", "")),
                light_kelvin=row.get("light_kelvin", "").strip(),
                label_mode=parsed.label_mode,
                label_canonical=parsed.label_canonical,
                class_label=parsed.class_label,
                class_id=parsed.class_id,
                analyte=parsed.analyte,
                level=parsed.level,
            )
            grouped_entries[key].append(image_name)

        for key, image_entries in grouped_entries.items():
            burst_frames = []
            for image_name in image_entries:
                with zf.open(image_name) as image_file:
                    encoded = image_file.read()
                burst_frames.append(decode_image_bytes(encoded))

            try:
                burst_result = pipeline.process_burst(burst_frames)
            except Exception as error:
                skipped_bursts += 1
                print(
                    f"  [SKIP BURST] event={key.event_id}, label={key.label_canonical}: {error}"
                )
                continue

            row_out: dict[str, str | float | int] = {
                "event_id": key.event_id,
                "batch_id": key.batch_id,
                "split": key.split,
                "light_kelvin": key.light_kelvin,
                "label_mode": key.label_mode,
                "label_raw": key.label_canonical,
                "label_canonical": key.label_canonical,
                "class_label": key.class_label,
                "class_id": key.class_id,
                "analyte": key.analyte,
                "level": key.level,
                "source_zip": zip_path.name,
                "frames_total": burst_result.frames_total,
                "frames_used": burst_result.frames_used,
                "frames_skipped": burst_result.frames_skipped,
                "frame_errors": " | ".join(burst_result.frame_errors[:5]),
            }

            for analyte_name in ANALYTE_ORDER:
                h, s, v = burst_result.features_by_pad[analyte_name]
                col_h, col_s, col_v = feature_columns_for_analyte(analyte_name)
                row_out[col_h] = h
                row_out[col_s] = s
                row_out[col_v] = v

            rows_out.append(row_out)

    return rows_out, skipped_bursts


def main() -> None:
    if not PACKAGES_DIR.exists():
        print(f"Packages directory not found:\n  {PACKAGES_DIR}")
        print("Build at least one training package in the Uritect app first.")
        sys.exit(1)

    zip_files = sorted(PACKAGES_DIR.glob("*.zip"))
    if not zip_files:
        print(f"No ZIP files found in:\n  {PACKAGES_DIR}")
        sys.exit(1)

    print(f"Found {len(zip_files)} ZIP(s) in:\n  {PACKAGES_DIR}\n")

    pipeline = BurstFeaturePipeline()
    all_rows: list[dict] = []
    total_skipped_bursts = 0

    for zip_file in zip_files:
        print(f"Processing {zip_file.name} ...")
        rows, skipped_bursts = process_zip(zip_file, pipeline)
        all_rows.extend(rows)
        total_skipped_bursts += skipped_bursts
        print(f"  -> {len(rows)} burst feature vector(s), skipped bursts: {skipped_bursts}")

    if not all_rows:
        print(
            "\nNo valid burst feature vectors were produced."
            "\nEnsure Macro-Marker is visible and labels are valid."
        )
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "features.csv"

    fieldnames = [
        "event_id",
        "batch_id",
        "split",
        "light_kelvin",
        "label_mode",
        "label_raw",
        "label_canonical",
        "class_label",
        "class_id",
        "analyte",
        "level",
        "source_zip",
        "frames_total",
        "frames_used",
        "frames_skipped",
        "frame_errors",
    ] + all_feature_columns(ANALYTE_ORDER)

    with open(output_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(all_rows)

    mode_counts = Counter(row["label_mode"] for row in all_rows)
    class_counts = Counter(row["class_label"] for row in all_rows if row["label_mode"] == "binary")
    split_counts = Counter(row["split"] for row in all_rows)

    print(f"\nSaved {len(all_rows)} burst feature vector(s) -> {output_path}")
    print(f"Skipped bursts (total): {total_skipped_bursts}")
    print("\nCounts by label mode:")
    for mode, count in sorted(mode_counts.items()):
        print(f"  {mode:10s} {count:4d}")

    if class_counts:
        print("\nBinary class counts:")
        print(f"  {'Normal':10s} {class_counts.get('Normal', 0):4d}")
        print(f"  {'Abnormal':10s} {class_counts.get('Abnormal', 0):4d}")

    print("\nSplit counts:")
    for split, count in sorted(split_counts.items()):
        print(f"  {split:10s} {count:4d}")

    print("\nDone. Run check_training_readiness.py, then train.py.")


if __name__ == "__main__":
    main()
