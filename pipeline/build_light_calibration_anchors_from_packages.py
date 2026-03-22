#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import io
import json
import math
import pathlib
import zipfile
from collections import defaultdict
from statistics import mean

from vision_pipeline import ANALYTE_ORDER, BurstFeaturePipeline, decode_image_bytes


DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "output" / "light_calibration_anchors_from_packages.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build per-light calibration anchors from training package ZIPs")
    parser.add_argument(
        "--packages-dir",
        type=pathlib.Path,
        required=True,
        help="Directory containing package ZIP files",
    )
    parser.add_argument(
        "--include-glob",
        default="*.zip",
        help="Glob pattern for ZIPs to include (default: *.zip)",
    )
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def _safe_float(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _circular_mean_deg(values: list[float]) -> float:
    if not values:
        return 0.0
    sin_sum = sum(math.sin(math.radians(value)) for value in values)
    cos_sum = sum(math.cos(math.radians(value)) for value in values)
    if abs(sin_sum) < 1e-12 and abs(cos_sum) < 1e-12:
        return _normalize_hue(values[0])
    return _normalize_hue(math.degrees(math.atan2(sin_sum, cos_sum)))


def main() -> None:
    args = parse_args()
    zip_paths = sorted(args.packages_dir.glob(args.include_glob))
    if not zip_paths:
        raise SystemExit(f"No ZIP files found in {args.packages_dir} with glob '{args.include_glob}'")

    pipeline = BurstFeaturePipeline()
    hues_by_light: dict[str, list[float]] = defaultdict(list)
    sats_by_light: dict[str, list[float]] = defaultdict(list)
    vals_by_light: dict[str, list[float]] = defaultdict(list)

    for zip_path in zip_paths:
        with zipfile.ZipFile(zip_path, "r") as archive:
            if "training_index.csv" not in archive.namelist():
                continue

            with archive.open("training_index.csv") as file:
                rows = list(csv.DictReader(io.TextIOWrapper(file, encoding="utf-8")))

            grouped: dict[tuple[str, str], list[str]] = defaultdict(list)
            for idx, row in enumerate(rows, start=1):
                event_id = (row.get("event_id") or "").strip() or f"{zip_path.stem}_{idx:04d}"
                light = (row.get("light_kelvin") or "").strip()
                rel_path = (row.get("relative_image_path") or "").strip()
                image_name = "images/" + pathlib.Path(rel_path).name
                if not light or image_name not in archive.namelist():
                    continue
                grouped[(event_id, light)].append(image_name)

            for (_event_id, light), image_names in grouped.items():
                frames = []
                for image_name in image_names:
                    with archive.open(image_name) as image_file:
                        frames.append(decode_image_bytes(image_file.read()))

                try:
                    burst_result = pipeline.process_burst(frames)
                except Exception:
                    continue

                event_hues: list[float] = []
                event_sats: list[float] = []
                event_vals: list[float] = []
                for analyte in ANALYTE_ORDER:
                    h, s, v = burst_result.features_by_pad[analyte]
                    event_hues.append(_normalize_hue(_safe_float(str(h))))
                    event_sats.append(_clip_01(_safe_float(str(s))))
                    event_vals.append(_clip_01(_safe_float(str(v))))

                if not event_hues:
                    continue

                hues_by_light[light].append(_circular_mean_deg(event_hues))
                sats_by_light[light].append(float(mean(event_sats)))
                vals_by_light[light].append(float(mean(event_vals)))

    anchors = {
        light: {
            "h": _circular_mean_deg(hues_by_light[light]),
            "s": float(mean(sats_by_light[light])),
            "v": float(mean(vals_by_light[light])),
            "samples": len(hues_by_light[light]),
        }
        for light in sorted(hues_by_light.keys())
        if hues_by_light[light]
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output.resolve(), "w", encoding="utf-8") as file:
        json.dump(anchors, file, indent=2)

    print(f"Saved calibration anchors -> {args.output.resolve()}")
    for light, anchor in anchors.items():
        print(
            f"  {light}: h={anchor['h']:.4f}, s={anchor['s']:.4f}, "
            f"v={anchor['v']:.4f}, samples={anchor['samples']}"
        )


if __name__ == "__main__":
    main()
