#!/usr/bin/env python3
"""Export frozen semiquant KNN models to a Dart-readable JSON asset."""

from __future__ import annotations

import argparse
import json
import pathlib
import pickle
import sys
from typing import Any

import numpy as np
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

try:
    from semiquant_schema import ANALYTE_ORDER
except ImportError:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from semiquant_schema import ANALYTE_ORDER


DEFAULT_MODELS = pathlib.Path(__file__).parent / "output" / "semiquant_models"
DEFAULT_OUTPUT = (
    pathlib.Path(__file__).parents[1]
    / "uritect_app"
    / "assets"
    / "production_semiquant_model.json"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models-dir", type=pathlib.Path, default=DEFAULT_MODELS)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--abstain-threshold",
        type=float,
        default=0.55,
        help="Global minimum confidence required for each analyte prediction.",
    )
    return parser.parse_args()


def _knn_from_model(model: Any) -> KNeighborsClassifier:
    if isinstance(model, Pipeline):
        estimator = model.steps[-1][1]
    else:
        estimator = model
    if not isinstance(estimator, KNeighborsClassifier):
        raise TypeError(f"Only KNeighborsClassifier export is supported, got {type(estimator)!r}")
    return estimator


def _scaler_from_model(model: Any) -> StandardScaler | None:
    if not isinstance(model, Pipeline):
        return None
    for _name, step in model.steps:
        if isinstance(step, StandardScaler):
            return step
    return None


def _labels_from_knn(knn: KNeighborsClassifier) -> list[str]:
    classes = [str(item) for item in knn.classes_.tolist()]
    encoded = np.asarray(knn._y)
    return [classes[int(index)] for index in encoded.tolist()]


def _round_matrix(values: np.ndarray) -> list[list[float]]:
    return [[round(float(item), 8) for item in row] for row in values.tolist()]


def main() -> None:
    args = parse_args()
    metadata_path = args.models_dir / "semiquant_models_metadata.json"
    with metadata_path.open(encoding="utf-8") as file:
        metadata = json.load(file)

    analytes: dict[str, dict[str, Any]] = {}
    versions = set()
    for analyte in ANALYTE_ORDER:
        info = metadata[analyte]
        versions.add(str(info.get("model_version", "unknown")))
        with (args.models_dir / info["model_file"]).open("rb") as file:
            model = pickle.load(file)

        knn = _knn_from_model(model)
        scaler = _scaler_from_model(model)
        train_vectors = np.asarray(knn._fit_X, dtype=float)
        labels = _labels_from_knn(knn)

        transform = str(info.get("feature_transform", "raw"))
        feature_set = str(info.get("feature_set", "local"))
        if scaler is not None:
            if transform == "circular_scaled":
                transform = "circular_scaled"
            elif transform == "scaled":
                transform = "scaled"
            scaler_payload = {
                "mean": [round(float(item), 10) for item in scaler.mean_.tolist()],
                "scale": [round(float(item), 10) for item in scaler.scale_.tolist()],
            }
        else:
            scaler_payload = None

        analytes[analyte] = {
            "k": int(getattr(knn, "n_neighbors", info.get("k", 1))),
            "metric": str(getattr(knn, "metric", info.get("metric", "euclidean"))),
            "weights": str(getattr(knn, "weights", "distance")),
            "feature_space": str(info.get("feature_space", "normalized_hsv")),
            "feature_set": feature_set,
            "feature_transform": transform,
            "scaler": scaler_payload,
            "train_vectors": _round_matrix(train_vectors),
            "train_labels": labels,
            "source_metadata": info,
        }

    payload = {
        "schema_version": 1,
        "model_version": "+".join(sorted(versions)),
        "localization": "markerless_strip_v1",
        "feature_space": "normalized_hsv",
        "claim": "ten_analyte_semiquant_only",
        "abstain_policy": {
            "enabled": True,
            "type": "global_min_analyte_confidence",
            "threshold": round(float(args.abstain_threshold), 6),
            "message": "Low-confidence analyte predictions require retake before results are accepted.",
        },
        "analyte_order": list(ANALYTE_ORDER),
        "analytes": analytes,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as file:
        json.dump(payload, file, separators=(",", ":"))
    print(f"Exported production model JSON: {args.output}")


if __name__ == "__main__":
    main()
