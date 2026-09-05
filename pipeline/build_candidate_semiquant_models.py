#!/usr/bin/env python3
"""Build candidate semiquant models from selected feature rows.

This builder is intended for validation experiments such as Cabatuan local
adaptation. It supports mixed per-analyte model families and either local
3-channel features or all 30 strip features, then writes app-compatible model
metadata without overwriting production models by default.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import pickle
import sys
from collections import Counter
from datetime import datetime, timezone
from typing import Any

from sklearn.dummy import DummyClassifier
from sklearn.ensemble import ExtraTreesClassifier, RandomForestClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import FunctionTransformer, StandardScaler
from sklearn.svm import SVC

try:
    from model_features import hsv_to_circular_features
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import all_feature_columns, feature_columns_for_analyte
except ImportError:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from model_features import hsv_to_circular_features
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import all_feature_columns, feature_columns_for_analyte


DEFAULT_FEATURES = (
    pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv.csv",
    pathlib.Path(__file__).parent / "dataset" / "cabatuan_holdout_features_normalized_hsv.csv",
)
DEFAULT_SPEC = pathlib.Path(__file__).parent / "output" / "cabatuan_only_model_family_search.json"
DEFAULT_OUTPUT_DIR = pathlib.Path(__file__).parent / "output" / "semiquant_models_cabatuan_candidate"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build candidate app-compatible semiquant models.")
    parser.add_argument("--features", type=pathlib.Path, nargs="+", default=list(DEFAULT_FEATURES))
    parser.add_argument("--model-spec", type=pathlib.Path, default=DEFAULT_SPEC)
    parser.add_argument("--output-dir", type=pathlib.Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--train-source-contains",
        action="append",
        required=True,
        help="Substring for source_zip rows included in training. Repeatable.",
    )
    parser.add_argument(
        "--model-version",
        default="candidate_semiquant_mixed_cabatuan_adapted_20260905",
    )
    return parser.parse_args()


def _matches_any(value: str, needles: list[str]) -> bool:
    lowered = value.lower()
    return any(needle.lower() in lowered for needle in needles)


def _load_rows(paths: list[pathlib.Path]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for path in paths:
        with open(path, newline="", encoding="utf-8") as file:
            rows.extend(csv.DictReader(file))
    return rows


def _feature_columns(analyte: str, feature_set: str) -> list[str]:
    if feature_set == "all30":
        return all_feature_columns(ANALYTE_ORDER, feature_space="normalized_hsv")
    return list(feature_columns_for_analyte(analyte, feature_space="normalized_hsv"))


def _make_model(name: str, n_samples: int):
    if name == "dummy":
        return DummyClassifier(strategy="most_frequent")
    if name == "knn1":
        return KNeighborsClassifier(n_neighbors=min(1, n_samples), weights="distance")
    if name == "knn5s":
        return make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=min(5, n_samples), weights="distance"))
    if name == "knn7s":
        return make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=min(7, n_samples), weights="distance"))
    if name == "knn15c":
        return make_pipeline(
            FunctionTransformer(hsv_to_circular_features, validate=False),
            StandardScaler(),
            KNeighborsClassifier(n_neighbors=min(15, n_samples), metric="manhattan", weights="distance"),
        )
    if name == "svc":
        return make_pipeline(StandardScaler(), SVC(C=3, class_weight="balanced", probability=True))
    if name == "rf":
        return RandomForestClassifier(n_estimators=300, max_depth=8, class_weight="balanced", random_state=4)
    if name == "rfdeep":
        return RandomForestClassifier(n_estimators=500, class_weight="balanced", random_state=8)
    if name == "extra":
        return ExtraTreesClassifier(n_estimators=400, class_weight="balanced", random_state=4)
    if name == "gnb":
        return GaussianNB()
    raise ValueError(f"Unsupported model family: {name}")


def main() -> None:
    args = parse_args()
    rows = _load_rows(args.features)
    with open(args.model_spec, encoding="utf-8") as file:
        spec: dict[str, dict[str, Any]] = json.load(file)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    metadata: dict[str, dict[str, Any]] = {}

    print("Building candidate semiquant models")
    print(f"Train filters: {', '.join(args.train_source_contains)}")
    print(f"Output: {args.output_dir}")
    print()
    print(f"{'Analyte':<20} {'Model':<8} {'Features':<8} {'Rows':>6} {'Levels':>6}")
    print("-" * 54)

    for analyte in ANALYTE_ORDER:
        analyte_spec = spec.get(analyte, {})
        model_name = str(analyte_spec.get("model", "knn5s"))
        feature_set = str(analyte_spec.get("feature_set", "local"))
        columns = _feature_columns(analyte, feature_set)

        x_values: list[list[float]] = []
        y_values: list[str] = []
        for row in rows:
            if row.get("analyte", "").strip() != analyte:
                continue
            if not _matches_any(row.get("source_zip", ""), args.train_source_contains):
                continue
            level = canonicalize_level(analyte, row.get("level", ""))
            if level is None:
                continue
            try:
                x_values.append([float(row.get(column, 0) or 0) for column in columns])
            except (TypeError, ValueError):
                continue
            y_values.append(level)

        if not x_values:
            raise SystemExit(f"No training rows for {analyte}")

        model = _make_model(model_name, len(x_values))
        model.fit(x_values, y_values)

        model_file = f"{analyte.lower().replace(' ', '_')}_knn_model.pkl"
        with (args.output_dir / model_file).open("wb") as file:
            pickle.dump(model, file)

        metadata[analyte] = {
            "model_version": args.model_version,
            "model_family": model_name,
            "feature_space": "normalized_hsv",
            "feature_set": feature_set,
            "feature_columns": columns,
            "n_samples": len(x_values),
            "n_levels": len(set(y_values)),
            "levels": dict(Counter(y_values)),
            "model_file": model_file,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "training_source_contains": args.train_source_contains,
        }
        print(f"{analyte:<20} {model_name:<8} {feature_set:<8} {len(x_values):>6} {len(set(y_values)):>6}")

    with (args.output_dir / "semiquant_models_metadata.json").open("w", encoding="utf-8") as file:
        json.dump(metadata, file, indent=2)

    print()
    print(f"Saved {len(metadata)} candidate models -> {args.output_dir}")


if __name__ == "__main__":
    main()
