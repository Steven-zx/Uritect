#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
from collections import defaultdict
from statistics import mean

from vision_pipeline import ANALYTE_ORDER, feature_columns_for_analyte


DEFAULT_FEATURES = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "output" / "light_calibration_anchors.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build per-light HSV calibration anchors from features.csv")
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
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
    with open(args.features.resolve(), newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    hues_by_light: dict[str, list[float]] = defaultdict(list)
    sats_by_light: dict[str, list[float]] = defaultdict(list)
    vals_by_light: dict[str, list[float]] = defaultdict(list)

    for row in rows:
        light = (row.get("light_kelvin") or "").strip()
        if not light:
            continue

        row_hues: list[float] = []
        row_sats: list[float] = []
        row_vals: list[float] = []
        for analyte in ANALYTE_ORDER:
            col_h, col_s, col_v = feature_columns_for_analyte(analyte)
            raw_h = (row.get(col_h) or "").strip()
            raw_s = (row.get(col_s) or "").strip()
            raw_v = (row.get(col_v) or "").strip()
            if not raw_h or not raw_s or not raw_v:
                continue
            row_hues.append(_normalize_hue(_safe_float(raw_h)))
            row_sats.append(_clip_01(_safe_float(raw_s)))
            row_vals.append(_clip_01(_safe_float(raw_v)))

        if not row_hues:
            continue

        hues_by_light[light].append(_circular_mean_deg(row_hues))
        sats_by_light[light].append(float(mean(row_sats)))
        vals_by_light[light].append(float(mean(row_vals)))

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
