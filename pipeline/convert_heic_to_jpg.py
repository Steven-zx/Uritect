#!/usr/bin/env python3
"""
Convert HEIC/HEIF images to JPG for Uritect ingestion.

Examples:
  python pipeline/convert_heic_to_jpg.py --input-dir "C:/data/2700k" --output-dir "C:/data/2700k_jpg"
  python pipeline/convert_heic_to_jpg.py --input-dir "C:/data/all" --output-dir "C:/data/all_jpg" --recursive
"""

from __future__ import annotations

import argparse
import pathlib
import sys
from dataclasses import dataclass

try:
    from PIL import Image
except ImportError:
    print("Pillow is not installed. Run: pip install -r pipeline/requirements.txt")
    sys.exit(1)

try:
    import pillow_heif
except ImportError:
    pillow_heif = None

HEIC_EXTS = {".heic", ".heif"}


@dataclass
class ConversionStats:
    converted: int = 0
    skipped_existing: int = 0
    failed: int = 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert HEIC/HEIF files into JPG files")
    parser.add_argument("--input-dir", required=True, type=pathlib.Path, help="Folder containing HEIC files")
    parser.add_argument("--output-dir", required=True, type=pathlib.Path, help="Folder where JPG files will be written")
    parser.add_argument("--recursive", action="store_true", help="Scan subfolders recursively")
    parser.add_argument("--quality", type=int, default=95, help="JPG quality (1-100), default 95")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite JPG files if they already exist")
    parser.add_argument(
        "--flatten",
        action="store_true",
        help="Do not preserve subfolder structure in output (default preserves structure)",
    )
    return parser.parse_args()


def find_heic_files(input_dir: pathlib.Path, recursive: bool) -> list[pathlib.Path]:
    if recursive:
        candidates = [p for p in input_dir.rglob("*") if p.is_file()]
    else:
        candidates = [p for p in input_dir.iterdir() if p.is_file()]
    return sorted([p for p in candidates if p.suffix.lower() in HEIC_EXTS])


def get_output_path(
    src: pathlib.Path,
    input_dir: pathlib.Path,
    output_dir: pathlib.Path,
    flatten: bool,
) -> pathlib.Path:
    if flatten:
        return output_dir / f"{src.stem}.jpg"

    rel = src.relative_to(input_dir)
    return (output_dir / rel).with_suffix(".jpg")


def convert_one(src: pathlib.Path, dst: pathlib.Path, quality: int, overwrite: bool) -> str:
    if dst.exists() and not overwrite:
        return "skipped"

    dst.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(src) as image:
        converted = image.convert("RGB")
        converted.save(dst, format="JPEG", quality=quality)

    return "converted"


def main() -> None:
    args = parse_args()

    input_dir = args.input_dir.resolve()
    output_dir = args.output_dir.resolve()

    if pillow_heif is None:
        print("pillow-heif is not installed. Run: pip install -r pipeline/requirements.txt")
        sys.exit(1)

    pillow_heif.register_heif_opener()

    if not input_dir.exists() or not input_dir.is_dir():
        print(f"Input directory not found or not a folder: {input_dir}")
        sys.exit(1)

    heic_files = find_heic_files(input_dir, recursive=args.recursive)
    if not heic_files:
        print(f"No HEIC/HEIF files found in: {input_dir}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    quality = max(1, min(100, int(args.quality)))
    stats = ConversionStats()

    for file_path in heic_files:
        out_path = get_output_path(file_path, input_dir, output_dir, flatten=args.flatten)
        try:
            result = convert_one(file_path, out_path, quality=quality, overwrite=args.overwrite)
            if result == "converted":
                stats.converted += 1
            else:
                stats.skipped_existing += 1
        except Exception as error:
            stats.failed += 1
            print(f"[FAILED] {file_path} -> {error}")

    print("Conversion finished.")
    print(f"  Converted: {stats.converted}")
    print(f"  Skipped existing: {stats.skipped_existing}")
    print(f"  Failed: {stats.failed}")
    print(f"  Output directory: {output_dir}")


if __name__ == "__main__":
    main()
