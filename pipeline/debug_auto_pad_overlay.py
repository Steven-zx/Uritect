#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np

from vision_pipeline import BurstFeaturePipeline, VisionPipelineConfig


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate overlay with per-pad auto-localization markers")
    parser.add_argument("--image", required=True, help="Input image path")
    parser.add_argument("--output-dir", required=True, help="Directory to write overlays and summary")
    parser.add_argument("--tag", default="overlay_x", help="Filename tag")
    return parser.parse_args()


def draw_x(image: np.ndarray, cx: int, cy: int, color: tuple[int, int, int], size: int = 8, thickness: int = 2) -> None:
    cv2.line(image, (cx - size, cy - size), (cx + size, cy + size), color, thickness, cv2.LINE_AA)
    cv2.line(image, (cx - size, cy + size), (cx + size, cy - size), color, thickness, cv2.LINE_AA)


def main() -> None:
    args = parse_args()
    image_path = Path(args.image).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    if image is None:
        raise SystemExit(f"Failed to read image: {image_path}")

    config = VisionPipelineConfig()
    pipeline = BurstFeaturePipeline(config)

    rectified = pipeline.rectifier.rectify(image)
    awb = pipeline.awb.apply(rectified.rectified_bgr, rectified.marker_corners_dst)
    _ = pipeline.slicer.slice_pads(awb.awb_bgr)

    overlay = awb.awb_bgr.copy()
    summary: dict[str, object] = {
        "image": str(image_path),
        "global_x_shift_px": int(pipeline.slicer.last_global_x_shift_px),
        "pads": {},
    }

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
        draw_x(overlay, cx, cy, color=(255, 255, 0), size=8, thickness=2)

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

        summary["pads"][analyte] = {
            "base_x": int(info.base_x),
            "base_y": int(info.base_y),
            "final_x": int(info.final_x),
            "final_y": int(info.final_y),
            "width": int(info.width),
            "height": int(info.height),
            "local_dx": int(info.local_dx),
            "local_dy": int(info.local_dy),
            "local_score": float(info.local_score),
        }

    out_overlay = output_dir / f"{args.tag}_auto_pad_overlay.png"
    out_rectified = output_dir / f"{args.tag}_rectified.png"
    out_awb = output_dir / f"{args.tag}_awb.png"
    out_summary = output_dir / f"{args.tag}_summary.json"

    cv2.imwrite(str(out_rectified), rectified.rectified_bgr)
    cv2.imwrite(str(out_awb), awb.awb_bgr)
    cv2.imwrite(str(out_overlay), overlay)
    out_summary.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"WROTE {out_rectified}")
    print(f"WROTE {out_awb}")
    print(f"WROTE {out_overlay}")
    print(f"WROTE {out_summary}")


if __name__ == "__main__":
    main()
