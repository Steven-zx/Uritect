#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import cv2

from vision_pipeline import BurstFeaturePipeline, VisionPipelineConfig


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate grid-lock overlays for a random batch of images")
    parser.add_argument("--roots", nargs="+", required=True, help="Image roots")
    parser.add_argument("--output-dir", required=True, help="Output directory")
    parser.add_argument("--count", type=int, default=20, help="Number of random images")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    return parser.parse_args()


def draw_x(image, cx: int, cy: int, color=(255, 255, 0), size: int = 7, thickness: int = 2) -> None:
    cv2.line(image, (cx - size, cy - size), (cx + size, cy + size), color, thickness, cv2.LINE_AA)
    cv2.line(image, (cx - size, cy + size), (cx + size, cy - size), color, thickness, cv2.LINE_AA)


def collect_images(roots: list[Path]) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png"}
    out: list[Path] = []
    for root in roots:
        out.extend([p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in exts])
    return sorted(out)


def main() -> None:
    args = parse_args()
    roots = [Path(item).resolve() for item in args.roots]
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    images = collect_images(roots)
    if not images:
        raise SystemExit("No images found.")

    random.seed(args.seed)
    sample_count = min(args.count, len(images))
    selected = random.sample(images, sample_count)

    config = VisionPipelineConfig()
    pipeline = BurstFeaturePipeline(config)

    records: list[dict[str, object]] = []

    for index, image_path in enumerate(selected, start=1):
        image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image is None:
            records.append({"image": str(image_path), "ok": False, "error": "failed_to_read"})
            continue

        try:
            rectified = pipeline.rectifier.rectify(image)
            awb = pipeline.awb.apply(rectified.rectified_bgr, rectified.marker_corners_dst)
            _ = pipeline.slicer.slice_pads(awb.awb_bgr)

            overlay = awb.awb_bgr.copy()
            pads_json: dict[str, object] = {}

            for analyte in config.analyte_order:
                info = pipeline.slicer.last_pad_localization.get(analyte)
                if info is None:
                    continue

                bx, by = info.base_x, info.base_y
                fx, fy = info.final_x, info.final_y
                w, h = info.width, info.height

                cv2.rectangle(overlay, (bx, by), (bx + w, by + h), (0, 255, 0), 1)
                cv2.rectangle(overlay, (fx, fy), (fx + w, fy + h), (0, 0, 255), 2)

                cx = fx + (w // 2)
                cy = fy + (h // 2)
                draw_x(overlay, cx, cy)

                cv2.putText(
                    overlay,
                    analyte,
                    (fx + w + 4, fy + (h // 2)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.35,
                    (255, 255, 255),
                    1,
                    cv2.LINE_AA,
                )

                pads_json[analyte] = {
                    "base_x": int(info.base_x),
                    "base_y": int(info.base_y),
                    "final_x": int(info.final_x),
                    "final_y": int(info.final_y),
                    "local_dx": int(info.local_dx),
                    "local_dy": int(info.local_dy),
                    "local_score": float(info.local_score),
                }

            stem = f"{index:02d}_{image_path.stem}"
            out_overlay = output_dir / f"{stem}_overlay.png"
            out_awb = output_dir / f"{stem}_awb.png"
            out_rect = output_dir / f"{stem}_rectified.png"

            cv2.imwrite(str(out_rect), rectified.rectified_bgr)
            cv2.imwrite(str(out_awb), awb.awb_bgr)
            cv2.imwrite(str(out_overlay), overlay)

            records.append(
                {
                    "image": str(image_path),
                    "ok": True,
                    "global_x_shift_px": int(pipeline.slicer.last_global_x_shift_px),
                    "global_y_shift_px": int(pipeline.slicer.last_global_y_shift_px),
                    "overlay": str(out_overlay),
                    "pads": pads_json,
                }
            )
        except Exception as error:  # noqa: BLE001
            records.append({"image": str(image_path), "ok": False, "error": str(error)})

    summary = {
        "total_selected": sample_count,
        "ok_count": sum(1 for record in records if record.get("ok")),
        "failed_count": sum(1 for record in records if not record.get("ok")),
        "records": records,
    }

    summary_path = output_dir / "batch_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"WROTE {summary_path}")
    print(f"OK={summary['ok_count']} FAILED={summary['failed_count']}")


if __name__ == "__main__":
    main()
