#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

import cv2
import numpy as np

from vision_pipeline import MacroMarkerRectifier, VisionPipelineConfig


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Rectify and tightly crop colorwheel images to chart + macro marker")
    parser.add_argument("--roots", nargs="+", required=True, help="Root folders containing images")
    parser.add_argument(
        "--backup-root",
        default="",
        help="Backup destination root. If empty, creates timestamped backup in dataset parent.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Only print files that would be processed")
    parser.add_argument("--pad", type=int, default=14, help="Padding around detected content bbox")
    parser.add_argument("--min-area", type=int, default=2500, help="Minimum connected-component area")
    return parser.parse_args()


def list_images(root: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts]


def _content_mask(rectified_bgr: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(rectified_bgr, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(rectified_bgr, cv2.COLOR_BGR2GRAY)

    sat = hsv[:, :, 1]
    val = hsv[:, :, 2]

    color = ((sat >= 20) & (val >= 15)).astype(np.uint8) * 255
    dark = (gray <= 130).astype(np.uint8) * 255

    mask = cv2.bitwise_or(color, dark)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    return mask


def _bbox_from_mask(mask: np.ndarray, min_area: int) -> tuple[int, int, int, int] | None:
    num_labels, _, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)

    x0, y0 = mask.shape[1], mask.shape[0]
    x1, y1 = 0, 0
    kept = 0

    for label in range(1, num_labels):
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < min_area:
            continue
        x = int(stats[label, cv2.CC_STAT_LEFT])
        y = int(stats[label, cv2.CC_STAT_TOP])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        x0 = min(x0, x)
        y0 = min(y0, y)
        x1 = max(x1, x + w)
        y1 = max(y1, y + h)
        kept += 1

    if kept == 0:
        return None
    return x0, y0, x1, y1


def _clamp_bbox(x0: int, y0: int, x1: int, y1: int, w: int, h: int, pad: int) -> tuple[int, int, int, int]:
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(w, x1 + pad)
    y1 = min(h, y1 + pad)
    return x0, y0, x1, y1


def main() -> None:
    args = parse_args()

    roots = [Path(item).resolve() for item in args.roots]
    missing = [str(root) for root in roots if not root.exists()]
    if missing:
        raise SystemExit(f"Missing roots: {missing}")

    pairs: list[tuple[Path, Path]] = []
    for root in roots:
        pairs.extend((root, image) for image in list_images(root))

    if not pairs:
        print("No images found. Nothing to do.")
        return

    if args.backup_root:
        backup_root = Path(args.backup_root).resolve()
    else:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_root = roots[0].parent / f"colorwheel_backup_before_rectified_crop_{stamp}"

    print(f"Images found: {len(pairs)}")
    print(f"Backup root: {backup_root}")

    if args.dry_run:
        for _, image in pairs[:20]:
            print(f"DRY RUN -> {image}")
        if len(pairs) > 20:
            print(f"... and {len(pairs) - 20} more")
        return

    config = VisionPipelineConfig()
    rectifier = MacroMarkerRectifier(config)

    processed = 0
    fallback_fixed = 0
    failed = 0

    for root, image_path in pairs:
        backup_path = backup_root / root.name / image_path.relative_to(root)
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image_path, backup_path)

        img = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if img is None:
            failed += 1
            continue

        try:
            rectified = rectifier.rectify(img).rectified_bgr
        except Exception:
            failed += 1
            continue

        mask = _content_mask(rectified)
        bbox = _bbox_from_mask(mask, min_area=int(args.min_area))

        if bbox is None:
            # fixed fallback ROI in rectified frame: keep marker + chart area
            x0, y0, x1, y1 = 40, 40, rectified.shape[1] - 40, int(rectified.shape[0] * 0.75)
            fallback_fixed += 1
        else:
            x0, y0, x1, y1 = bbox

        x0, y0, x1, y1 = _clamp_bbox(x0, y0, x1, y1, rectified.shape[1], rectified.shape[0], int(args.pad))

        if x1 <= x0 or y1 <= y0:
            failed += 1
            continue

        cropped = rectified[y0:y1, x0:x1]
        ok = cv2.imwrite(str(image_path), cropped)
        if not ok:
            failed += 1
            continue

        processed += 1

    print("Rectified crop complete.")
    print(f"Processed images: {processed}")
    print(f"Fallback fixed ROI used: {fallback_fixed}")
    print(f"Failed images: {failed}")
    print(f"Backups saved under: {backup_root}")


if __name__ == "__main__":
    main()
