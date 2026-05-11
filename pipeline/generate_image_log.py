#!/usr/bin/env python3
"""Generate an image log mapping photos to event_ids from the locked sample master.

Usage:
  python pipeline/generate_image_log.py \
    --photos-dir pipeline/photos \
    --sample-master pipeline/dataset/rhu_sample_master_from_uritect_locked_v1.csv \
    --out pipeline/dataset/rhu_image_log_from_uritect_locked_v1.csv

This script expects photo folders named with 3-digit sample IDs (e.g., 001) and
files named like "001-Warm.jpg", "001-Cool.jpg", "001-Daylight.jpg".
"""
from pathlib import Path
import csv
import argparse
import re
from collections import defaultdict

LIGHT_MAP = {"warm": "2700", "cool": "4000", "daylight": "5500"}


def load_master(master_path: Path):
    with master_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    # build lookup: (participant_id, light_kelvin) -> event_id
    lookup = {}
    for r in rows:
        participant = r.get("participant_id")
        light = r.get("light_kelvin")
        event = r.get("event_id")
        if participant and light and event:
            lookup[(participant, light)] = event
    return lookup


def detect_light_from_name(name: str):
    # match labels Warm/Cool/Daylight in filename (case-insensitive)
    for label in LIGHT_MAP.keys():
        if re.search(rf"[-_]{label}(?:\.|_|$)", name, flags=re.IGNORECASE):
            return label, LIGHT_MAP[label]
    return None, None


def generate_image_log(photos_dir: Path, master_lookup: dict):
    rows = []
    skipped = []
    for sample_dir in sorted(photos_dir.iterdir()):
        if not sample_dir.is_dir():
            continue
        sample_name = sample_dir.name
        # normalize sample folder name to 3-digit
        try:
            sample_num = int(sample_name)
            sample_id = f"{sample_num:03d}"
        except Exception:
            sample_id = sample_name.zfill(3)

        participant_id = f"P{sample_id}"
        sample_label = f"{participant_id}-S1"

        for img in sorted(sample_dir.iterdir()):
            if not img.is_file():
                continue
            if img.suffix.lower() not in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}:
                continue
            fname = img.name
            label, kelvin = detect_light_from_name(fname)
            if label is None:
                skipped.append((str(img), "no_light_label"))
                continue
            event_id = master_lookup.get((participant_id, kelvin))
            if event_id is None:
                skipped.append((str(img), f"no_event_for_{participant_id}_{kelvin}"))
                continue

            rows.append({
                "event_id": event_id,
                "participant_id": participant_id,
                "sample_id": sample_label,
                "light_kelvin": kelvin,
                "file_name": fname,
                "qc_pass": "1",
            })

    return rows, skipped


def write_image_log(rows, out_path: Path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["event_id", "participant_id", "sample_id", "light_kelvin", "file_name", "qc_pass"]
    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)


def main():
    p = argparse.ArgumentParser(description="Generate image log for RHU dataset")
    p.add_argument("--photos-dir", default="pipeline/photos")
    p.add_argument("--sample-master", default="pipeline/dataset/rhu_sample_master_from_uritect_locked_v1.csv")
    p.add_argument("--out", default="pipeline/dataset/rhu_image_log_from_uritect_locked_v1.csv")
    args = p.parse_args()

    photos_dir = Path(args.photos_dir)
    master_path = Path(args.sample_master)
    out_path = Path(args.out)

    if not photos_dir.exists():
        raise SystemExit(f"Photos dir not found: {photos_dir}")
    if not master_path.exists():
        raise SystemExit(f"Sample master not found: {master_path}")

    master_lookup = load_master(master_path)
    rows, skipped = generate_image_log(photos_dir, master_lookup)

    write_image_log(rows, out_path)

    print(f"Written image log: {out_path} (rows: {len(rows)})")
    counts = defaultdict(int)
    for r in rows:
        counts[r["light_kelvin"]] += 1
    print("By light:")
    for k in sorted(counts.keys()):
        print(f"  {k}: {counts[k]}")
    if skipped:
        print(f"Skipped {len(skipped)} files (see first 10):")
        for s in skipped[:10]:
            print(" ", s)


if __name__ == "__main__":
    main()
