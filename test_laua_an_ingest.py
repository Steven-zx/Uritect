#!/usr/bin/env python3
"""Test script to ingest just the Laua-an package."""

import sys
import pathlib
import csv
import os

# Change to pipeline dir for imports to work
os.chdir(pathlib.Path(__file__).parent / 'pipeline')
sys.path.insert(0, str(pathlib.Path(__file__).parent / 'pipeline'))

# Now import from pipeline dir
from vision_pipeline import BurstFeaturePipeline, VisionPipelineConfig, all_feature_columns, ANALYTE_ORDER

# Go back to root
os.chdir(pathlib.Path(__file__).parent)
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from pipeline.ingest import process_zip

LAUA_AN_ZIP = pathlib.Path.home() / "Documents" / "uritect_training_dataset" / "packages" / "LAUAAN_20260730_ID_CLEANED_2026-07-30.zip"
OUTPUT_CSV = pathlib.Path("pipeline/dataset/features_laua_an_only.csv")

print(f"Processing: {LAUA_AN_ZIP}")
if not LAUA_AN_ZIP.exists():
    print(f"ERROR: ZIP not found: {LAUA_AN_ZIP}")
    sys.exit(1)

pipeline = BurstFeaturePipeline(VisionPipelineConfig(feature_space="lab"))
print("Pipeline created; processing ZIP...")

try:
    rows, skipped = process_zip(LAUA_AN_ZIP, pipeline, feature_space="lab")
    print(f"✓ Processed {len(rows)} rows, skipped {skipped} bursts")
except Exception as e:
    print(f"ERROR during processing: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

if rows:
    OUTPUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "event_id",
        "batch_id",
        "split",
        "light_kelvin",
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
    ] + all_feature_columns(ANALYTE_ORDER, feature_space="lab")
    
    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"✓ Saved {len(rows)} rows to {OUTPUT_CSV}")
else:
    print("No rows produced!")
    sys.exit(1)

print("\nDone!")
