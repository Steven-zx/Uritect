#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import shutil
from datetime import datetime
from pathlib import Path

import cv2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Rotate colorwheel dataset images by arbitrary angle with backup")
    parser.add_argument("--roots", nargs="+", required=True, help="Root folders containing images")
    parser.add_argument(
        "--angle",
        type=float,
        required=True,
        help="Rotation angle in degrees. Positive = CCW (left), negative = CW (right).",
    )
    parser.add_argument(
        "--backup-root",
        default="",
        help="Backup destination root. If empty, creates timestamped backup in dataset parent.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Only print what would be rotated")
    return parser.parse_args()


def list_images(root: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts]


def rotate_bound(image, angle_degrees: float):
    h, w = image.shape[:2]
    cx, cy = w / 2.0, h / 2.0

    matrix = cv2.getRotationMatrix2D((cx, cy), angle_degrees, 1.0)
    cos = abs(matrix[0, 0])
    sin = abs(matrix[0, 1])

    new_w = int((h * sin) + (w * cos))
    new_h = int((h * cos) + (w * sin))

    matrix[0, 2] += (new_w / 2.0) - cx
    matrix[1, 2] += (new_h / 2.0) - cy

    return cv2.warpAffine(
        image,
        matrix,
        (new_w, new_h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REPLICATE,
    )


def main() -> None:
    args = parse_args()

    roots = [Path(item).resolve() for item in args.roots]
    missing = [str(root) for root in roots if not root.exists()]
    if missing:
        raise SystemExit(f"Missing roots: {missing}")

    pairs: list[tuple[Path, Path]] = []
    for root in roots:
        for image in list_images(root):
            pairs.append((root, image))

    if not pairs:
        print("No images found. Nothing to do.")
        return

    if args.backup_root:
        backup_root = Path(args.backup_root).resolve()
    else:
        dataset_parent = roots[0].parent
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        signed = "plus" if args.angle >= 0 else "minus"
        angle_tag = f"{signed}{int(round(abs(args.angle)))}deg"
        backup_root = dataset_parent / f"colorwheel_backup_before_rotate_{angle_tag}_{stamp}"

    print(f"Images found: {len(pairs)}")
    print(f"Angle: {args.angle} degrees (CCW positive)")
    print(f"Backup root: {backup_root}")

    if args.dry_run:
        for _, image in pairs[:20]:
            print(f"DRY RUN -> {image}")
        if len(pairs) > 20:
            print(f"... and {len(pairs) - 20} more")
        return

    for root, image in pairs:
        relative = image.relative_to(root)
        backup_path = backup_root / root.name / relative
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image, backup_path)

        loaded = cv2.imread(str(image), cv2.IMREAD_COLOR)
        if loaded is None:
            raise RuntimeError(f"Failed to read image: {image}")

        rotated = rotate_bound(loaded, args.angle)
        ok = cv2.imwrite(str(image), rotated)
        if not ok:
            raise RuntimeError(f"Failed to write rotated image: {image}")

    print("Rotation complete.")
    print(f"Backups saved under: {backup_root}")


if __name__ == "__main__":
    main()
