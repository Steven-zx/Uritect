#!/usr/bin/env python3
"""Reproduce the frozen grouped split and report all thesis classifier metrics.

This script evaluates the frozen model configuration without rewriting the
production model artifacts. Related lighting captures remain grouped by
specimen, matching the production freeze protocol.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from datetime import datetime, timezone
from statistics import mean
from typing import Any

from sklearn.metrics import accuracy_score, cohen_kappa_score, confusion_matrix, f1_score
from sklearn.model_selection import GroupShuffleSplit

try:
    from freeze_production_semiquant import (
        DEFAULT_DEDUPED,
        DEFAULT_OPT,
        MODEL_VERSION,
        _load_rows,
        _make_model,
        _rows_for_analyte,
    )
    from semiquant_schema import ANALYTE_ORDER
except ImportError:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from freeze_production_semiquant import (
        DEFAULT_DEDUPED,
        DEFAULT_OPT,
        MODEL_VERSION,
        _load_rows,
        _make_model,
        _rows_for_analyte,
    )
    from semiquant_schema import ANALYTE_ORDER


DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "output" / "production_grouped_metrics_complete.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_DEDUPED)
    parser.add_argument("--optimization-results", type=pathlib.Path, default=DEFAULT_OPT)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--test-size", type=float, default=0.20)
    parser.add_argument("--random-state", type=int, default=42)
    return parser.parse_args()


def one_vs_rest_metrics(y_true: list[str], y_pred: list[str], labels: list[str]) -> dict[str, Any]:
    per_class: dict[str, Any] = {}
    sensitivity_values: list[float] = []
    specificity_values: list[float] = []
    for label in labels:
        tp = sum(a == label and p == label for a, p in zip(y_true, y_pred))
        fn = sum(a == label and p != label for a, p in zip(y_true, y_pred))
        fp = sum(a != label and p == label for a, p in zip(y_true, y_pred))
        tn = sum(a != label and p != label for a, p in zip(y_true, y_pred))
        sensitivity = tp / (tp + fn) if tp + fn else 0.0
        specificity = tn / (tn + fp) if tn + fp else 0.0
        sensitivity_values.append(sensitivity)
        specificity_values.append(specificity)
        per_class[label] = {
            "support": tp + fn,
            "sensitivity": sensitivity,
            "specificity": specificity,
            "tp": tp,
            "fn": fn,
            "fp": fp,
            "tn": tn,
        }
    return {
        "macro_sensitivity": mean(sensitivity_values),
        "macro_specificity": mean(specificity_values),
        "per_class": per_class,
    }


def main() -> None:
    args = parse_args()
    rows = _load_rows(args.features)
    with args.optimization_results.open(encoding="utf-8") as stream:
        optimization = json.load(stream)

    per_analyte: dict[str, Any] = {}
    all_true: list[str] = []
    all_pred: list[str] = []
    event_correct: dict[str, list[bool]] = {}

    for analyte in ANALYTE_ORDER:
        x_values, y_values, groups, events = _rows_for_analyte(rows, analyte)
        split = GroupShuffleSplit(
            n_splits=1,
            test_size=args.test_size,
            random_state=args.random_state,
        )
        train_index, test_index = next(split.split(x_values, y_values, groups))
        parameters = optimization.get(analyte, {})
        k = min(int(parameters.get("best_k", parameters.get("k", 5))), len(train_index))
        metric = str(parameters.get("best_metric", parameters.get("metric", "euclidean")))
        transform = str(parameters.get("feature_transform", "raw"))
        model = _make_model(k, metric, transform)
        y_test = [y_values[index] for index in test_index]
        y_pred = model.fit(
            [x_values[index] for index in train_index],
            [y_values[index] for index in train_index],
        ).predict([x_values[index] for index in test_index]).tolist()
        labels = sorted(set(y_test) | set(y_pred))
        ovsr = one_vs_rest_metrics(y_test, y_pred, labels)
        matrix = confusion_matrix(y_test, y_pred, labels=labels)
        per_analyte[analyte] = {
            "accuracy": float(accuracy_score(y_test, y_pred)),
            "macro_f1": float(f1_score(y_test, y_pred, average="macro", zero_division=0)),
            "macro_sensitivity": ovsr["macro_sensitivity"],
            "macro_specificity": ovsr["macro_specificity"],
            "cohen_kappa": float(cohen_kappa_score(y_test, y_pred, labels=labels)),
            "test_predictions": len(y_test),
            "train_specimen_groups": len({groups[index] for index in train_index}),
            "test_specimen_groups": len({groups[index] for index in test_index}),
            "model": {"k": k, "metric": metric, "feature_transform": transform},
            "class_metrics": ovsr["per_class"],
            "confusion_matrix": {"labels": labels, "matrix": matrix.tolist()},
        }
        all_true.extend(y_test)
        all_pred.extend(y_pred)
        for index, prediction in zip(test_index, y_pred):
            event_correct.setdefault(events[index], []).append(prediction == y_values[index])

    complete_events = [values for values in event_correct.values() if len(values) == len(ANALYTE_ORDER)]
    whole_correct = sum(all(values) for values in complete_events)
    output = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model_version": MODEL_VERSION,
        "features": str(args.features),
        "evaluation_design": {
            "split": "GroupShuffleSplit",
            "group": "specimen_group",
            "test_size": args.test_size,
            "random_state": args.random_state,
            "note": "Lighting variants from one specimen remain on the same split side.",
        },
        "summary": {
            "individual_analyte_accuracy": float(accuracy_score(all_true, all_pred)),
            "individual_analyte_correct": sum(a == p for a, p in zip(all_true, all_pred)),
            "individual_analyte_total": len(all_true),
            "whole_scan_all_10_correct_accuracy": whole_correct / len(complete_events),
            "whole_scan_all_10_correct": whole_correct,
            "whole_scan_total": len(complete_events),
            "macro_across_analytes": {
                key: mean(values[key] for values in per_analyte.values())
                for key in (
                    "accuracy",
                    "macro_f1",
                    "macro_sensitivity",
                    "macro_specificity",
                    "cohen_kappa",
                )
            },
        },
        "per_analyte": per_analyte,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as stream:
        json.dump(output, stream, indent=2)
    print(json.dumps(output["summary"], indent=2))
    print(f"Report: {args.output}")


if __name__ == "__main__":
    main()
