#!/usr/bin/env python3
"""
Build a Uritect training ZIP package from existing photo folders.

Creates a ZIP with:
  - training_index.csv
  - images/<files>

Default output directory:
  ~/Documents/uritect_training_dataset/packages/

Examples:
  python pipeline/build_training_package.py --input-dir "C:/data/color_wheel" --label Normal --light-kelvin 4000 --batch-id BATCH_COOL

  python pipeline/build_training_package.py --input-dir "C:/data/mixed" --batch-id BATCH_MIXED
  (auto-detects label from folder/file names containing normal/abnormal,
   and light from 2700K/4000K/5500K tokens in folder/file names)
"""

from __future__ import annotations

import argparse
import csv
import io
import pathlib
import re
import sys
import zipfile
from datetime import datetime

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
DEFAULT_PACKAGES_DIR = pathlib.Path.home() / "Documents" / "uritect_training_dataset" / "packages"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build training package ZIP for pipeline/ingest.py")
    parser.add_argument("--input-dir", required=True, type=pathlib.Path, help="Folder containing photos")
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=DEFAULT_PACKAGES_DIR,
        help=f"Where ZIP is saved (default: {DEFAULT_PACKAGES_DIR})",
    )
    parser.add_argument(
        "--zip-name",
        default="",
        help="Output ZIP file name (optional). If omitted, generated from batch + timestamp.",
    )
    parser.add_argument("--batch-id", default="", help="Batch id written to training_index.csv")
    parser.add_argument(
        "--split",
        choices=["train", "val", "test"],
        default="train",
        help="Dataset split for all rows (default: train)",
    )
    parser.add_argument(
        "--label",
        choices=["Normal", "Abnormal"],
        default="",
        help="Force one label for all images. If omitted, tries to infer from names.",
    )
    parser.add_argument(
        "--light-kelvin",
        default="",
        help="Force one light value for all images (e.g., 2700, 4000, 5500). If omitted, tries to infer.",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="Include images from subfolders recursively",
    )
    parser.add_argument(
        "--allow-missing-light",
        action="store_true",
        help="Allow blank light_kelvin when not provided and not inferable",
    )
    parser.add_argument(
        "--allow-missing-label",
        action="store_true",
        help="Allow skipping label requirement (not recommended)",
    )
    return parser.parse_args()


def _find_images(input_dir: pathlib.Path, recursive: bool) -> list[pathlib.Path]:
    if recursive:
        candidates = [p for p in input_dir.rglob("*") if p.is_file()]
    else:
        candidates = [p for p in input_dir.iterdir() if p.is_file()]
    return sorted([p for p in candidates if p.suffix.lower() in IMAGE_EXTS])


def _infer_label(path: pathlib.Path) -> str:
    text = str(path).lower()
    if "abnormal" in text or "positive" in text:
        return "Abnormal"
    if "normal" in text or "negative" in text:
        return "Normal"
    return ""


def _infer_kelvin(path: pathlib.Path) -> str:
    text = str(path)
    match = re.search(r"(?<!\d)(2700|4000|5500)\s*[kK]?(?!\d)", text)
    if match:
        return match.group(1)
    return ""


def _safe_token(raw: str) -> str:
    token = re.sub(r"[^A-Za-z0-9_-]+", "_", raw.strip())
    return token.strip("_") or "batch"


def main() -> None:
    args = parse_args()
    input_dir = args.input_dir.resolve()

    if not input_dir.exists() or not input_dir.is_dir():
        print(f"Input directory not found or not a folder: {input_dir}")
        sys.exit(1)

    images = _find_images(input_dir, recursive=args.recursive)
    if not images:
        print(f"No images found in: {input_dir}")
        sys.exit(1)

    batch_id = args.batch_id.strip() or _safe_token(input_dir.name)
    timestamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    zip_name = args.zip_name.strip() or f"{batch_id}_{timestamp}.zip"
    if not zip_name.lower().endswith(".zip"):
        zip_name += ".zip"

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    zip_path = output_dir / zip_name

    rows: list[dict[str, str]] = []
    skipped: list[str] = []

    seen_names: set[str] = set()

    for index, image_path in enumerate(images, start=1):
        label = args.label or _infer_label(image_path)
        if not label and not args.allow_missing_label:
            skipped.append(f"{image_path.name} (missing label)")
            continue

        light_kelvin = args.light_kelvin or _infer_kelvin(image_path)
        if not light_kelvin and not args.allow_missing_light:
            skipped.append(f"{image_path.name} (missing light_kelvin)")
            continue

        stem = _safe_token(image_path.stem)
        event_id = f"{batch_id}_{stem}_{index:04d}"

        file_name = image_path.name
        if file_name in seen_names:
            file_name = f"{image_path.stem}_{index:04d}{image_path.suffix.lower()}"
        seen_names.add(file_name)

        rows.append(
            {
                "event_id": event_id,
                "batch_id": batch_id,
                "split": args.split,
                "light_kelvin": str(light_kelvin),
                "label": label,
                "relative_image_path": f"images/{file_name}",
                "__src_path__": str(image_path),
                "__zip_file_name__": file_name,
            }
        )

    if not rows:
        print("No rows to package after filtering. Nothing to do.")
        if skipped:
            print("Examples of skipped files:")
            for message in skipped[:10]:
                print(f"  - {message}")
        sys.exit(1)

    fieldnames = [
        "event_id",
        "batch_id",
        "split",
        "light_kelvin",
        "label",
        "relative_image_path",
    ]

    csv_buffer = io.StringIO()
    writer = csv.DictWriter(csv_buffer, fieldnames=fieldnames)
    writer.writeheader()
    for row in rows:
        writer.writerow({key: row[key] for key in fieldnames})

    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("training_index.csv", csv_buffer.getvalue().encode("utf-8"))
        for row in rows:
            src = pathlib.Path(row["__src_path__"])
            dst = f"images/{row['__zip_file_name__']}"
            archive.write(src, arcname=dst)

    print(f"Created package: {zip_path}")
    print(f"Rows written: {len(rows)}")
    print(f"Skipped files: {len(skipped)}")

    if skipped:
        print("First skipped files:")
        for message in skipped[:10]:
            print(f"  - {message}")

    print("\nNext steps:")
    print("  1) python pipeline/ingest.py")
    print("  2) python pipeline/check_training_readiness.py --mode binary --min-total 12 --min-class 6")
    print("  3) python pipeline/train.py")


if __name__ == "__main__":
    main()
