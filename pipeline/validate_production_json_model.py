#!/usr/bin/env python3
"""Verify exported Android JSON model predictions match frozen pickle models."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import pickle
import sys
from typing import Any

import numpy as np

try:
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte
except ImportError:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte


DEFAULT_FEATURES = pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv_deduped_production.csv"
DEFAULT_MODELS = pathlib.Path(__file__).parent / "output" / "semiquant_models"
DEFAULT_JSON = pathlib.Path(__file__).parents[1] / "uritect_app" / "assets" / "production_semiquant_model.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
    parser.add_argument("--models-dir", type=pathlib.Path, default=DEFAULT_MODELS)
    parser.add_argument("--json-model", type=pathlib.Path, default=DEFAULT_JSON)
    parser.add_argument("--max-rows-per-analyte", type=int, default=200)
    return parser.parse_args()


def _load_models(models_dir: pathlib.Path) -> tuple[dict[str, Any], dict[str, Any]]:
    with (models_dir / "semiquant_models_metadata.json").open(encoding="utf-8") as file:
        metadata = json.load(file)
    models = {}
    for analyte, info in metadata.items():
        with (models_dir / info["model_file"]).open("rb") as file:
            models[analyte] = pickle.load(file)
    return models, metadata


def _distance(a: list[float], b: list[float], metric: str) -> float:
    if metric == "manhattan":
        return float(sum(abs(x - y) for x, y in zip(a, b)))
    if metric == "chebyshev":
        return float(max(abs(x - y) for x, y in zip(a, b)))
    return float(np.sqrt(sum((x - y) ** 2 for x, y in zip(a, b))))


def _transform(values: list[float], model: dict[str, Any]) -> list[float]:
    transform = model.get("feature_transform", "raw")
    if transform == "circular_scaled":
        h = np.radians(values[0])
        values = [float(np.cos(h)), float(np.sin(h)), values[1], values[2]]
    if transform in {"scaled", "circular_scaled"} and model.get("scaler"):
        mean = model["scaler"]["mean"]
        scale = model["scaler"]["scale"]
        values = [(v - m) / (s if s else 1.0) for v, m, s in zip(values, mean, scale)]
    return values


def _json_predict(model: dict[str, Any], values: list[float]) -> str:
    values = _transform(values, model)
    neighbors = [
        (label, _distance(values, vector, model.get("metric", "euclidean")))
        for label, vector in zip(model["train_labels"], model["train_vectors"])
    ]
    neighbors.sort(key=lambda item: item[1])
    votes: dict[str, float] = {}
    for label, distance in neighbors[: int(model.get("k", 1))]:
        votes[label] = votes.get(label, 0.0) + 1.0 / (distance + 1e-9)
    return max(votes.items(), key=lambda item: item[1])[0]


def main() -> None:
    args = parse_args()
    models, _metadata = _load_models(args.models_dir)
    with args.json_model.open(encoding="utf-8") as file:
        json_model = json.load(file)["analytes"]
    with args.features.open(newline="", encoding="utf-8-sig") as file:
        rows = list(csv.DictReader(file))

    mismatches: list[dict[str, str]] = []
    checked = 0
    for analyte in ANALYTE_ORDER:
        columns = feature_columns_for_analyte(analyte, "normalized_hsv")
        count = 0
        for row in rows:
            if row.get("analyte") != analyte:
                continue
            expected = canonicalize_level(analyte, row.get("level", ""))
            if expected is None:
                continue
            values = [float(row[column]) for column in columns]
            pickle_pred = str(models[analyte].predict([values])[0])
            json_pred = _json_predict(json_model[analyte], values)
            checked += 1
            count += 1
            if pickle_pred != json_pred:
                mismatches.append(
                    {
                        "analyte": analyte,
                        "event_id": row.get("event_id", ""),
                        "pickle": pickle_pred,
                        "json": json_pred,
                    }
                )
                if len(mismatches) >= 10:
                    break
            if count >= args.max_rows_per_analyte:
                break
        if len(mismatches) >= 10:
            break

    print(f"Checked predictions: {checked}")
    print(f"Mismatches: {len(mismatches)}")
    if mismatches:
        print(json.dumps(mismatches, indent=2))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
