#!/usr/bin/env python3
"""
Quick ingestion script for COLORWHEEL_5500_SEMIQUANT.zip only.
Appends rows to existing features.csv.
"""

import pathlib
import sys
import zipfile

try:
    from vision_pipeline import (
        BurstFeaturePipeline,
        decode_image_bytes,
        all_feature_columns,
        feature_columns_for_analyte,
        ANALYTE_ORDER,
    )
    from ingest import (
        process_zip,
        BINARY_LABEL_ALIASES,
        OUTPUT_DIR,
        parse_label,
        parse_multi_analyte_levels,
    )
except ImportError as error:
    print(f"Failed to import modules: {error}", file=sys.stderr)
    sys.exit(1)

import csv

COLORWHEEL_5500_ZIP = pathlib.Path.home() / "Documents" / "uritect_training_dataset" / "packages" / "COLORWHEEL_5500_SEMIQUANT.zip"
OUTPUT_CSV = OUTPUT_DIR / "features.csv"

if not COLORWHEEL_5500_ZIP.exists():
    print(f"ZIP not found: {COLORWHEEL_5500_ZIP}")
    sys.exit(1)

print(f"Processing: {COLORWHEEL_5500_ZIP.name}")

pipeline = BurstFeaturePipeline()
rows, skipped = process_zip(COLORWHEEL_5500_ZIP, pipeline)

print(f"  -> {len(rows)} rows extracted, {skipped} bursts skipped")

# Append to existing CSV
if rows:
    with open(OUTPUT_CSV, "a", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys())
        writer.writerows(rows)
    print(f"  -> Appended {len(rows)} rows to {OUTPUT_CSV}")

print("\nDone!")
