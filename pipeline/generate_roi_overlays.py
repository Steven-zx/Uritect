#!/usr/bin/env python3
"""Generate numbered ROI overlay images for markerless dipstick scans."""
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable

import cv2

try:
    from .scan_dipstick import run_scan
except ImportError:
    import sys

    workspace_root = Path(__file__).resolve().parent.parent
    if str(workspace_root) not in sys.path:
        sys.path.insert(0, str(workspace_root))
    from pipeline.scan_dipstick import run_scan


def _iter_images(path: Path) -> Iterable[Path]:
    if path.is_file():
        yield path
        return
    for suffix in ("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"):
        yield from sorted(path.rglob(suffix))


def _draw_overlay(image_path: Path, result: dict, output_path: Path) -> None:
    image = cv2.imread(str(image_path))
    if image is None:
        raise ValueError(f"Could not read image: {image_path}")

    strip_bbox = result.get("strip_bbox") or []
    if len(strip_bbox) == 4:
        x, y, w, h = [int(v) for v in strip_bbox]
        cv2.rectangle(image, (x, y), (x + w, y + h), (0, 255, 255), 8)

    pad_rois = result.get("pad_rois") or {}
    for index, (name, roi) in enumerate(pad_rois.items(), start=1):
        if len(roi) != 4:
            continue
        x, y, w, h = [int(v) for v in roi]
        cv2.rectangle(image, (x, y), (x + w, y + h), (0, 255, 0), 6)
        label = f"{index} {name}"
        cv2.putText(
            image,
            label,
            (x, max(35, y - 12)),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.2,
            (0, 0, 0),
            8,
            cv2.LINE_AA,
        )
        cv2.putText(
            image,
            label,
            (x, max(35, y - 12)),
            cv2.FONT_HERSHEY_SIMPLEX,
            1.2,
            (255, 255, 255),
            3,
            cv2.LINE_AA,
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_path), image)


def _draw_rejection(image_path: Path, reason: str, output_path: Path) -> bool:
    image = cv2.imread(str(image_path))
    if image is None:
        return False
    banner_height = max(80, image.shape[0] // 12)
    cv2.rectangle(image, (0, 0), (image.shape[1], banner_height), (0, 0, 180), -1)
    message = f"REJECTED: {reason[:110]}"
    cv2.putText(
        image,
        message,
        (24, max(50, banner_height // 2 + 12)),
        cv2.FONT_HERSHEY_SIMPLEX,
        max(0.8, min(1.6, image.shape[1] / 1300.0)),
        (255, 255, 255),
        3,
        cv2.LINE_AA,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_path), image)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Image file or directory")
    parser.add_argument("--output-dir", default=Path("pipeline/output/roi_overlays"), type=Path)
    parser.add_argument("--models-dir", default=Path("pipeline/output/semiquant_models"), type=Path)
    parser.add_argument("--max-images", type=int, default=0, help="Maximum images to inspect; 0 means all.")
    parser.add_argument(
        "--name-contains",
        default="",
        help="Optional case-insensitive substring filter for full image paths, e.g. Warm or Cabatuan.",
    )
    parser.add_argument(
        "--include-rejections",
        action="store_true",
        help="Write red-banner overlays for rejected or failed images.",
    )
    args = parser.parse_args()

    created = 0
    inspected = 0
    rejected = 0
    name_filter = args.name_contains.strip().lower()
    for image_path in _iter_images(args.input):
        if name_filter and name_filter not in str(image_path).lower():
            continue
        if args.max_images and inspected >= args.max_images:
            break
        inspected += 1
        try:
            result = run_scan(image_path, models_dir=args.models_dir)
            if result.get("pads_detected") != 10:
                print(f"SKIP {image_path}: pads_detected={result.get('pads_detected')}")
                if args.include_rejections and _draw_rejection(
                    image_path,
                    f"pads_detected={result.get('pads_detected')}",
                    args.output_dir / f"{image_path.stem}_roi_rejected.jpg",
                ):
                    rejected += 1
                continue
            output_path = args.output_dir / f"{image_path.stem}_roi_overlay.jpg"
            _draw_overlay(image_path, result, output_path)
            print(f"WROTE {output_path}")
            created += 1
        except Exception as exc:
            print(f"ERROR {image_path}: {exc}")
            if args.include_rejections and _draw_rejection(
                image_path,
                str(exc),
                args.output_dir / f"{image_path.stem}_roi_rejected.jpg",
            ):
                rejected += 1
    print(f"Inspected images: {inspected}")
    print(f"Created accepted overlays: {created}")
    print(f"Created rejected overlays: {rejected}")
    return 0 if created else 1


if __name__ == "__main__":
    raise SystemExit(main())
