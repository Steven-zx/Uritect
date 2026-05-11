#!/usr/bin/env python3
"""Derive a normalized-HSV feature CSV from the current features.csv.

This is a fast post-processing variant of the ingest pipeline. It keeps the same
schema but normalizes each row around its own burst-wide HSV anchors so the model
can be retrained without a full re-ingest.
"""

from __future__ import annotations

import argparse
import csv
import pathlib
from typing import Any

import numpy as np

from vision_pipeline import ANALYTE_ORDER, feature_columns_for_analyte


DEFAULT_INPUT = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv.csv"


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build normalized-HSV feature CSV")
    parser.add_argument("--input", type=pathlib.Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def normalize_row(row: dict[str, str]) -> dict[str, str]:
    feature_triplets: list[tuple[str, str, str, float, float, float]] = []
    hues: list[float] = []
    sats: list[float] = []
    vals: list[float] = []

    for analyte in ANALYTE_ORDER:
        col_h, col_s, col_v = feature_columns_for_analyte(analyte)
        h = _safe_float(row.get(col_h, ""))
        s = _safe_float(row.get(col_s, ""))
        v = _safe_float(row.get(col_v, ""))
        feature_triplets.append((col_h, col_s, col_v, h, s, v))
        hues.append(h)
        sats.append(s)
        vals.append(v)

    if not feature_triplets:
        return dict(row)

    hue_anchor = float(np.mean(np.sin(np.radians(hues))))
    hue_anchor = 0.0 if np.isnan(hue_anchor) else None
    # Use a circular mean to keep hue wrapping stable.
    sin_sum = float(np.sum(np.sin(np.radians(np.asarray(hues, dtype=np.float32)))))
    cos_sum = float(np.sum(np.cos(np.radians(np.asarray(hues, dtype=np.float32)))))
    if abs(sin_sum) < 1e-12 and abs(cos_sum) < 1e-12:
        hue_center = hues[0] if hues else 0.0
    else:
        hue_center = float(np.degrees(np.arctan2(sin_sum, cos_sum)))

    sat_center = float(np.mean(np.asarray(sats, dtype=np.float32))) if sats else 0.0
    val_center = float(np.mean(np.asarray(vals, dtype=np.float32))) if vals else 0.0

    normalized = dict(row)
    for col_h, col_s, col_v, h, s, v in feature_triplets:
        normalized[col_h] = f"{_normalize_hue(h - hue_center):.6f}"
        normalized[col_s] = f"{_clip_01(0.5 + (s - sat_center)):.6f}"
        normalized[col_v] = f"{_clip_01(0.5 + (v - val_center)):.6f}"
    return normalized


def main() -> None:
    args = parse_args()
    if not args.input.exists():
        raise SystemExit(f"Input features file not found: {args.input}")

    with args.input.open(newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))
        fieldnames = file.readline()  # no-op to keep linter happy

    if not rows:
        raise SystemExit("No rows found in input features file")

    normalized_rows = [normalize_row(row) for row in rows]

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(normalized_rows[0].keys()))
        writer.writeheader()
        writer.writerows(normalized_rows)

    print(f"Saved normalized-HSV features -> {args.output.resolve()}")
    print(f"Rows: {len(normalized_rows)}")


if __name__ == "__main__":
    main()
