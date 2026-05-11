#!/usr/bin/env python3
"""Analyze semiquant feature space for overlap and light sensitivity.

This script reads pipeline/dataset/features.csv and writes a compact diagnostic
report to pipeline/output/feature_space_diagnostics.json plus a CSV of per-level
centroids. It is intended to identify which analyte/level pairs overlap most
strongly in the current HSV feature space.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from itertools import combinations
from statistics import mean, pstdev
from typing import Any

try:
    import numpy as np
    from sklearn.decomposition import PCA
except ImportError:
    print("Missing dependencies. Run: pip install -r pipeline/requirements.txt")
    raise SystemExit(1)

try:
    from semiquant_schema import ANALYTE_LEVEL_SCHEMA, ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte
except ImportError as error:
    print(f"Failed to import pipeline modules: {error}")
    print("Run from repository root: python pipeline/analyze_feature_space.py")
    raise SystemExit(1)


DEFAULT_FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_OUTPUT_JSON = pathlib.Path(__file__).parent / "output" / "feature_space_diagnostics.json"
DEFAULT_OUTPUT_CSV = pathlib.Path(__file__).parent / "output" / "feature_space_centroids.csv"


@dataclass
class LevelStats:
    analyte: str
    level: str
    count: int
    h_mean: float
    s_mean: float
    v_mean: float
    h_std: float
    s_std: float
    v_std: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze semiquant feature space")
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES_PATH)
    parser.add_argument("--output-json", type=pathlib.Path, default=DEFAULT_OUTPUT_JSON)
    parser.add_argument("--output-csv", type=pathlib.Path, default=DEFAULT_OUTPUT_CSV)
    parser.add_argument("--pca-components", type=int, default=2)
    return parser.parse_args()


def load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"features.csv not found: {path}")
    with path.open(newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_feature_matrix(rows: list[dict[str, str]]) -> tuple[np.ndarray, list[str]]:
    feature_columns: list[str] = []
    for analyte in ANALYTE_ORDER:
        feature_columns.extend(feature_columns_for_analyte(analyte))

    matrix: list[list[float]] = []
    for row in rows:
        vector = [safe_float(row.get(column, "")) for column in feature_columns]
        matrix.append(vector)

    return np.asarray(matrix, dtype=np.float32), feature_columns


def build_level_stats(rows: list[dict[str, str]]) -> list[LevelStats]:
    grouped: dict[tuple[str, str], list[tuple[float, float, float]]] = defaultdict(list)

    for row in rows:
        analyte = row.get("analyte", "").strip()
        level_raw = row.get("level", "").strip()
        if not analyte or analyte not in ANALYTE_ORDER or not level_raw:
            continue

        canonical = canonicalize_level(analyte, level_raw)
        if canonical is None:
            continue

        col_h, col_s, col_v = feature_columns_for_analyte(analyte)
        grouped[(analyte, canonical)].append(
            (
                safe_float(row.get(col_h, "")),
                safe_float(row.get(col_s, "")),
                safe_float(row.get(col_v, "")),
            )
        )

    stats: list[LevelStats] = []
    for (analyte, level), triples in sorted(grouped.items()):
        hs = [item[0] for item in triples]
        ss = [item[1] for item in triples]
        vs = [item[2] for item in triples]
        stats.append(
            LevelStats(
                analyte=analyte,
                level=level,
                count=len(triples),
                h_mean=float(mean(hs)),
                s_mean=float(mean(ss)),
                v_mean=float(mean(vs)),
                h_std=float(pstdev(hs)) if len(hs) > 1 else 0.0,
                s_std=float(pstdev(ss)) if len(ss) > 1 else 0.0,
                v_std=float(pstdev(vs)) if len(vs) > 1 else 0.0,
            )
        )
    return stats


def centroid_distance(a: LevelStats, b: LevelStats) -> float:
    # Circular hue distance normalized to [0, 1], plus Euclidean S/V distance.
    hue_delta = abs(a.h_mean - b.h_mean)
    hue_delta = min(hue_delta, 360.0 - hue_delta) / 180.0
    sat_delta = a.s_mean - b.s_mean
    val_delta = a.v_mean - b.v_mean
    return math.sqrt((hue_delta * hue_delta) + (sat_delta * sat_delta) + (val_delta * val_delta))


def nearest_neighbors_by_analyte(stats: list[LevelStats]) -> dict[str, list[dict[str, Any]]]:
    by_analyte: dict[str, list[LevelStats]] = defaultdict(list)
    for item in stats:
        by_analyte[item.analyte].append(item)

    out: dict[str, list[dict[str, Any]]] = {}
    for analyte, items in by_analyte.items():
        pairs = []
        for left, right in combinations(items, 2):
            pairs.append(
                {
                    "level_a": left.level,
                    "level_b": right.level,
                    "distance": centroid_distance(left, right),
                }
            )
        out[analyte] = sorted(pairs, key=lambda row: row["distance"])
    return out


def per_light_summary(rows: list[dict[str, str]]) -> dict[str, Any]:
    summary: dict[str, Counter[str]] = defaultdict(Counter)
    for row in rows:
        light = row.get("light_kelvin", "").strip()
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        if not light or not analyte or not level:
            continue
        canonical = canonicalize_level(analyte, level)
        if canonical is None:
            continue
        summary[light][f"{analyte}:{canonical}"] += 1
    return {
        light: {
            "total_rows": int(sum(counter.values())),
            "top_groups": counter.most_common(10),
        }
        for light, counter in sorted(summary.items())
    }


def run_pca(matrix: np.ndarray, n_components: int) -> dict[str, Any]:
    if matrix.size == 0:
        return {"enabled": False, "reason": "empty feature matrix"}
    n_components = max(1, min(n_components, matrix.shape[1], matrix.shape[0]))
    pca = PCA(n_components=n_components)
    coords = pca.fit_transform(matrix)
    return {
        "enabled": True,
        "n_components": n_components,
        "explained_variance_ratio": [float(x) for x in pca.explained_variance_ratio_],
        "total_explained_variance": float(sum(pca.explained_variance_ratio_)),
        "sample_coordinates": coords[: min(20, len(coords))].tolist(),
    }


def write_centroid_csv(stats: list[LevelStats], path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(asdict(stats[0]).keys()) if stats else ["analyte", "level", "count", "h_mean", "s_mean", "v_mean", "h_std", "s_std", "v_std"])
        writer.writeheader()
        for item in stats:
            writer.writerow(asdict(item))


def main() -> None:
    args = parse_args()
    rows = load_rows(args.features)
    feature_matrix, feature_columns = load_feature_matrix(rows)
    stats = build_level_stats(rows)
    nearest = nearest_neighbors_by_analyte(stats)
    light_summary = per_light_summary(rows)

    pca_report = run_pca(feature_matrix, args.pca_components)

    level_counts = Counter((row.get("analyte", "").strip(), row.get("level", "").strip()) for row in rows if row.get("analyte", "").strip() and row.get("level", "").strip())
    sparse_groups = [
        {"analyte": analyte, "level": level, "count": count}
        for (analyte, level), count in sorted(level_counts.items())
        if count < 10
    ]

    report = {
        "features_path": str(args.features.resolve()),
        "rows": len(rows),
        "feature_count": len(feature_columns),
        "analyte_count": len(ANALYTE_ORDER),
        "level_count": len(stats),
        "sparse_groups_below_10": sparse_groups,
        "per_analyte_nearest_centroids": {
            analyte: items[:5] for analyte, items in sorted(nearest.items())
        },
        "per_light_summary": light_summary,
        "pca": pca_report,
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    with args.output_json.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    if stats:
        write_centroid_csv(stats, args.output_csv)

    print(f"Saved diagnostics -> {args.output_json.resolve()}")
    print(f"Saved centroids -> {args.output_csv.resolve() if stats else '(skipped; no stats)'}")
    print(f"Rows: {len(rows)} | groups: {len(stats)} | sparse groups <10: {len(sparse_groups)}")
    if pca_report.get("enabled"):
        print(f"PCA explained variance: {pca_report['total_explained_variance']:.4f}")


if __name__ == "__main__":
    main()
