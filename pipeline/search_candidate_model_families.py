#!/usr/bin/env python3
"""Search mixed semiquant model families for Cabatuan day-to-day validation."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
import warnings
from typing import Callable

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


DEFAULT_FEATURES = pathlib.Path(__file__).parent / "dataset" / "cabatuan_holdout_features_normalized_hsv.csv"
DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "output" / "cabatuan_only_model_family_search.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Search candidate Cabatuan semiquant model families.")
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--objective",
        choices=["pooled", "min_direction"],
        default="pooled",
        help="Optimize pooled accuracy or the weaker of the two date holdout directions.",
    )
    return parser.parse_args()


def _model_factories() -> list[tuple[str, Callable[[int], object]]]:
    return [
        ("dummy", lambda n: DummyClassifier(strategy="most_frequent")),
        ("knn1", lambda n: KNeighborsClassifier(n_neighbors=min(1, n), weights="distance")),
        ("knn3s", lambda n: make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=min(3, n), weights="distance"))),
        ("knn5s", lambda n: make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=min(5, n), weights="distance"))),
        ("knn7s", lambda n: make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=min(7, n), weights="distance"))),
        (
            "knn15c",
            lambda n: make_pipeline(
                FunctionTransformer(hsv_to_circular_features, validate=False),
                StandardScaler(),
                KNeighborsClassifier(n_neighbors=min(15, n), metric="manhattan", weights="distance"),
            ),
        ),
        (
            "knn21c",
            lambda n: make_pipeline(
                FunctionTransformer(hsv_to_circular_features, validate=False),
                StandardScaler(),
                KNeighborsClassifier(n_neighbors=min(21, n), metric="chebyshev", weights="distance"),
            ),
        ),
        ("svc", lambda n: make_pipeline(StandardScaler(), SVC(C=3, class_weight="balanced", probability=True))),
        ("rf", lambda n: RandomForestClassifier(n_estimators=300, max_depth=8, class_weight="balanced", random_state=4)),
        ("rfdeep", lambda n: RandomForestClassifier(n_estimators=500, class_weight="balanced", random_state=8)),
        ("extra", lambda n: ExtraTreesClassifier(n_estimators=500, class_weight="balanced", random_state=4)),
        ("gnb", lambda n: GaussianNB()),
    ]


def _split(
    rows: list[dict[str, str]],
    analyte: str,
    columns: list[str],
    train_source: str,
    test_source: str,
) -> tuple[list[list[float]], list[str], list[list[float]], list[str]]:
    train_x: list[list[float]] = []
    train_y: list[str] = []
    test_x: list[list[float]] = []
    test_y: list[str] = []
    for row in rows:
        if row.get("analyte", "").strip() != analyte:
            continue
        level = canonicalize_level(analyte, row.get("level", ""))
        if level is None:
            continue
        try:
            features = [float(row[column]) for column in columns]
        except (KeyError, TypeError, ValueError):
            continue
        source = row.get("source_zip", "")
        if train_source in source:
            train_x.append(features)
            train_y.append(level)
        elif test_source in source:
            test_x.append(features)
            test_y.append(level)
    return train_x, train_y, test_x, test_y


def _score_model(
    rows: list[dict[str, str]],
    analyte: str,
    columns: list[str],
    model_name: str,
    factory: Callable[[int], object],
    train_source: str,
    test_source: str,
) -> tuple[int, int, float]:
    train_x, train_y, test_x, test_y = _split(rows, analyte, columns, train_source, test_source)
    if not train_x or not test_x:
        return 0, 0, 0.0
    if len(set(train_y)) < 2 and model_name not in {"dummy", "knn1", "knn3s", "knn5s", "knn7s", "knn15c", "knn21c", "gnb"}:
        return 0, len(test_y), 0.0
    try:
        model = factory(len(train_x))
        model.fit(train_x, train_y)
        predictions = model.predict(test_x)
    except Exception:
        return 0, len(test_y), 0.0
    correct = int(sum(predicted == expected for predicted, expected in zip(predictions, test_y)))
    return correct, len(test_y), correct / len(test_y)


def main() -> None:
    args = parse_args()
    warnings.filterwarnings("ignore")
    with open(args.features, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    directions = [
        ("uritect_2026-7-15_Cabatuan", "uritect_2026-7-17_Cabatuan"),
        ("uritect_2026-7-17_Cabatuan", "uritect_2026-7-15_Cabatuan"),
    ]
    model_factories = _model_factories()
    all30_columns = all_feature_columns(ANALYTE_ORDER, feature_space="normalized_hsv")

    report: dict[str, object] = {
        "features": str(args.features),
        "objective": args.objective,
        "directions": directions,
        "per_analyte": {},
    }

    print(f"Candidate model-family search ({args.objective})")
    for analyte in ANALYTE_ORDER:
        best: tuple[tuple[float, ...], str, str, list[tuple[int, int, float]]] | None = None
        feature_sets = [
            ("local", list(feature_columns_for_analyte(analyte, feature_space="normalized_hsv"))),
            ("all30", all30_columns),
        ]
        for feature_set, columns in feature_sets:
            for model_name, factory in model_factories:
                values = [
                    _score_model(rows, analyte, columns, model_name, factory, train_source, test_source)
                    for train_source, test_source in directions
                ]
                total_correct = sum(value[0] for value in values)
                total = sum(value[1] for value in values)
                pooled = total_correct / total if total else 0.0
                min_direction = min(value[2] for value in values)
                mean_direction = sum(value[2] for value in values) / len(values)
                key = (pooled, mean_direction) if args.objective == "pooled" else (min_direction, pooled, mean_direction)
                if best is None or key > best[0]:
                    best = (key, feature_set, model_name, values)

        if best is None:
            continue
        _key, feature_set, model_name, values = best
        report["per_analyte"][analyte] = {
            "feature_set": feature_set,
            "model": model_name,
            "directions": [
                {
                    "train": directions[index][0],
                    "test": directions[index][1],
                    "correct": value[0],
                    "total": value[1],
                    "accuracy": value[2],
                }
                for index, value in enumerate(values)
            ],
        }
        print(
            f"{analyte:<18} {feature_set:<6} {model_name:<7} "
            f"dirs={values[0][2] * 100:.2f}/{values[1][2] * 100:.2f}"
        )

    report["direction_totals"] = []
    for index, (train_source, test_source) in enumerate(directions):
        correct = sum(item["directions"][index]["correct"] for item in report["per_analyte"].values())
        total = sum(item["directions"][index]["total"] for item in report["per_analyte"].values())
        report["direction_totals"].append(
            {
                "train": train_source,
                "test": test_source,
                "correct": correct,
                "total": total,
                "accuracy": correct / total if total else 0.0,
            }
        )
        print(f"Total {train_source} -> {test_source}: {correct}/{total} ({correct / total * 100:.2f}%)")

    pooled_correct = sum(item["correct"] for item in report["direction_totals"])
    pooled_total = sum(item["total"] for item in report["direction_totals"])
    report["pooled"] = {
        "correct": pooled_correct,
        "total": pooled_total,
        "accuracy": pooled_correct / pooled_total if pooled_total else 0.0,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump(report["per_analyte"], file, indent=2)
    report_path = args.output.with_suffix(".report.json")
    with open(report_path, "w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)
    print(f"Model spec: {args.output}")
    print(f"Full report: {report_path}")


if __name__ == "__main__":
    main()
