#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

import cv2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Rotate colorwheel dataset images with backup")
    parser.add_argument(
        "--roots",
        nargs="+",
        required=True,
        help="One or more root folders containing images",
    )
    parser.add_argument(
        "--backup-root",
        default="",
        help="Backup destination root. If empty, creates timestamped backup in dataset parent.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print files that would be rotated",
    )
    return parser.parse_args()


def list_images(root: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    return [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts]


def main() -> None:
    args = parse_args()
    roots = [Path(item).resolve() for item in args.roots]
    missing = [str(root) for root in roots if not root.exists()]
    if missing:
        raise SystemExit(f"Missing roots: {missing}")

    all_images: list[tuple[Path, Path]] = []
    for root in roots:
        images = list_images(root)
        all_images.extend((root, image) for image in images)

    if not all_images:
        print("No images found. Nothing to do.")
        return

    if args.backup_root:
        backup_root = Path(args.backup_root).resolve()
    else:
        dataset_parent = roots[0].parent
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_root = dataset_parent / f"colorwheel_backup_before_rotate_{stamp}"

    print(f"Images found: {len(all_images)}")
    print(f"Backup root: {backup_root}")

    if args.dry_run:
        for _, image in all_images[:20]:
            print(f"DRY RUN -> {image}")
        if len(all_images) > 20:
            print(f"... and {len(all_images) - 20} more")
        return

    for root, image in all_images:
        relative = image.relative_to(root)
        backup_path = backup_root / root.name / relative
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(image, backup_path)

        loaded = cv2.imread(str(image), cv2.IMREAD_COLOR)
        if loaded is None:
            raise RuntimeError(f"Failed to read image: {image}")

        rotated = cv2.rotate(loaded, cv2.ROTATE_90_CLOCKWISE)
        ok = cv2.imwrite(str(image), rotated)
        if not ok:
            raise RuntimeError(f"Failed to write rotated image: {image}")

    print("Rotation complete.")
    print(f"Backups saved under: {backup_root}")


if __name__ == "__main__":
    main()
