#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

import cv2
import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Crop colorwheel dataset images to content area with backup")
    parser.add_argument("--roots", nargs="+", required=True, help="Root folders containing images")
    parser.add_argument(
        "--backup-root",
        default="",
        help="Backup destination root. If empty, creates timestamped backup in dataset parent.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Only print files that would be cropped")
    parser.add_argument("--min-component-area", type=int, default=600, help="Minimum component area to keep")
    parser.add_argument("--pad", type=int, default=12, help="Padding (pixels) around detected content")
    parser.add_argument("--sat-threshold", type=int, default=28, help="Saturation threshold for color content")
    parser.add_argument("--val-min", type=int, default=20, help="Minimum value threshold for valid content")
    return parser.parse_args()


def list_images(root: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts]


def _fallback_mask_from_border(image_bgr: np.ndarray) -> np.ndarray:
    h, w = image_bgr.shape[:2]
    bw = max(4, int(round(min(h, w) * 0.02)))

    border_pixels = np.concatenate(
        [
            image_bgr[:bw, :, :].reshape(-1, 3),
            image_bgr[-bw:, :, :].reshape(-1, 3),
            image_bgr[:, :bw, :].reshape(-1, 3),
            image_bgr[:, -bw:, :].reshape(-1, 3),
        ],
        axis=0,
    )

    bg = np.median(border_pixels.astype(np.float32), axis=0)
    diff = np.linalg.norm(image_bgr.astype(np.float32) - bg.reshape(1, 1, 3), axis=2)
    mask = (diff > 22.0).astype(np.uint8) * 255

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    return mask


def detect_crop_bbox(
    image_bgr: np.ndarray,
    min_component_area: int,
    pad: int,
    sat_threshold: int,
    val_min: int,
) -> tuple[int, int, int, int]:
    h, w = image_bgr.shape[:2]
    hsv = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)

    sat = hsv[:, :, 1]
    val = hsv[:, :, 2]

    border_band = max(4, int(round(min(h, w) * 0.02)))
    border_pixels = np.concatenate(
        [
            gray[:border_band, :].reshape(-1),
            gray[-border_band:, :].reshape(-1),
            gray[:, :border_band].reshape(-1),
            gray[:, -border_band:].reshape(-1),
        ]
    )
    bg_gray = int(np.median(border_pixels))

    color_mask = ((sat >= sat_threshold) & (val >= val_min)).astype(np.uint8) * 255
    dark_print_mask = (gray <= max(25, bg_gray - 14)).astype(np.uint8) * 255
    mask = cv2.bitwise_or(color_mask, dark_print_mask)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)

    num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)

    x0, y0 = w, h
    x1, y1 = 0, 0
    kept = 0

    for label in range(1, num_labels):
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < min_component_area:
            continue
        x = int(stats[label, cv2.CC_STAT_LEFT])
        y = int(stats[label, cv2.CC_STAT_TOP])
        bw = int(stats[label, cv2.CC_STAT_WIDTH])
        bh = int(stats[label, cv2.CC_STAT_HEIGHT])

        x0 = min(x0, x)
        y0 = min(y0, y)
        x1 = max(x1, x + bw)
        y1 = max(y1, y + bh)
        kept += 1

    if kept == 0:
        fallback = _fallback_mask_from_border(image_bgr)
        points = cv2.findNonZero(fallback)
        if points is None:
            return 0, 0, w, h
        x, y, bw, bh = cv2.boundingRect(points)
        x0, y0, x1, y1 = x, y, x + bw, y + bh

    # Secondary tightening pass on the first crop window to remove residual empty beige margins.
    roi = image_bgr[y0:y1, x0:x1]
    roi_hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
    roi_gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    roi_sat = roi_hsv[:, :, 1]
    roi_val = roi_hsv[:, :, 2]

    roi_mask_color = ((roi_sat >= max(18, sat_threshold - 8)) & (roi_val >= max(15, val_min - 5))).astype(np.uint8) * 255
    roi_mask_dark = (roi_gray <= max(18, bg_gray - 10)).astype(np.uint8) * 255
    roi_mask = cv2.bitwise_or(roi_mask_color, roi_mask_dark)
    roi_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    roi_mask = cv2.morphologyEx(roi_mask, cv2.MORPH_CLOSE, roi_kernel, iterations=2)

    roi_points = cv2.findNonZero(roi_mask)
    if roi_points is not None:
        rx, ry, rw, rh = cv2.boundingRect(roi_points)
        x0 += rx
        y0 += ry
        x1 = x0 + rw
        y1 = y0 + rh

    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(w, x1 + pad)
    y1 = min(h, y1 + pad)

    if x1 <= x0 or y1 <= y0:
        return 0, 0, w, h

    return x0, y0, x1, y1


def main() -> None:
    args = parse_args()
    roots = [Path(item).resolve() for item in args.roots]

    missing = [str(root) for root in roots if not root.exists()]
    if missing:
        raise SystemExit(f"Missing roots: {missing}")

    pairs: list[tuple[Path, Path]] = []
    for root in roots:
        images = list_images(root)
        pairs.extend((root, image) for image in images)

    if not pairs:
        print("No images found. Nothing to do.")
        return

    if args.backup_root:
        backup_root = Path(args.backup_root).resolve()
    else:
        dataset_parent = roots[0].parent
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_root = dataset_parent / f"colorwheel_backup_before_crop_{stamp}"

    print(f"Images found: {len(pairs)}")
    print(f"Backup root: {backup_root}")

    if args.dry_run:
        for _, image in pairs[:20]:
            print(f"DRY RUN -> {image}")
        if len(pairs) > 20:
            print(f"... and {len(pairs) - 20} more")
        return

    cropped_count = 0
    unchanged_count = 0

    for root, image in pairs:
        backup_path = backup_root / root.name / image.relative_to(root)
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image, backup_path)

        loaded = cv2.imread(str(image), cv2.IMREAD_COLOR)
        if loaded is None:
            raise RuntimeError(f"Failed to read image: {image}")

        x0, y0, x1, y1 = detect_crop_bbox(
            loaded,
            min_component_area=int(args.min_component_area),
            pad=int(args.pad),
            sat_threshold=int(args.sat_threshold),
            val_min=int(args.val_min),
        )

        if (x0, y0, x1, y1) == (0, 0, loaded.shape[1], loaded.shape[0]):
            unchanged_count += 1
            continue

        cropped = loaded[y0:y1, x0:x1]
        ok = cv2.imwrite(str(image), cropped)
        if not ok:
            raise RuntimeError(f"Failed to write cropped image: {image}")
        cropped_count += 1

    print("Cropping complete.")
    print(f"Cropped images: {cropped_count}")
    print(f"Unchanged images: {unchanged_count}")
    print(f"Backups saved under: {backup_root}")


if __name__ == "__main__":
    main()
