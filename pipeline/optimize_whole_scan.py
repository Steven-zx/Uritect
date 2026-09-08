#!/usr/bin/env python3
"""Optimize ten-analyte whole-scan accuracy with specialist models and abstain.

This script is intentionally an experiment harness, not a production freezer.
It evaluates per-analyte model families on a specimen-grouped split, then tests
scan-level confidence thresholds where any low-confidence analyte rejects the
whole scan for retake.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from statistics import mean
from typing import Any

import numpy as np
from sklearn.base import clone
from sklearn.calibration import CalibratedClassifierCV
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import ExtraTreesClassifier, RandomForestClassifier, VotingClassifier
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.naive_bayes import GaussianNB
from sklearn.neighbors import KNeighborsClassifier, NearestCentroid
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import FunctionTransformer, StandardScaler
from sklearn.svm import SVC

try:
    from freeze_production_semiquant import _dedupe_rows, _specimen_group
    from model_features import hsv_to_circular_features
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte
except ImportError:
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from freeze_production_semiquant import _dedupe_rows, _specimen_group
    from model_features import hsv_to_circular_features
    from semiquant_schema import ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte


DEFAULT_FEATURES = pathlib.Path(__file__).parent / "dataset" / "features_normalized_hsv.csv"
DEFAULT_KNN_OPT = pathlib.Path(__file__).parent / "output" / "semiquant_optimization_results.json"
DEFAULT_REPORT = pathlib.Path(__file__).parent / "output" / "whole_scan_optimization.json"
DEFAULT_MODEL_PLAN = pathlib.Path(__file__).parent / "output" / "whole_scan_model_plan.json"


@dataclass(frozen=True)
class Sample:
    analyte: str
    level: str
    event_key: str
    specimen_group: str
    light_key: str
    split: str
    features_local: tuple[float, float, float]
    features_all30: tuple[float, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES)
    parser.add_argument("--knn-optimization", type=pathlib.Path, default=DEFAULT_KNN_OPT)
    parser.add_argument("--report", type=pathlib.Path, default=DEFAULT_REPORT)
    parser.add_argument("--model-plan", type=pathlib.Path, default=DEFAULT_MODEL_PLAN)
    parser.add_argument("--split-mode", choices=["grouped", "csv"], default="grouped")
    parser.add_argument(
        "--profile",
        choices=["full", "fast"],
        default="full",
        help="Use fast to skip slow calibrated SVM and ensemble candidates.",
    )
    parser.add_argument(
        "--selection",
        choices=["best", "knn_current"],
        default="best",
        help="Use best to select specialist winners, or knn_current to evaluate the frozen KNN family only.",
    )
    parser.add_argument("--test-size", type=float, default=0.20)
    parser.add_argument("--random-state", type=int, default=42)
    parser.add_argument("--min-light-train", type=int, default=20)
    return parser.parse_args()


def _load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as file:
        return list(csv.DictReader(file))


def _light_key(value: str) -> str:
    normalized = " ".join(str(value or "").strip().lower().split())
    if normalized in {"2700", "2700k", "warm"}:
        return "warm"
    if normalized in {"4000", "4000k", "cool"}:
        return "cool"
    if normalized in {"5500", "5500k", "daylight"}:
        return "daylight"
    return normalized or "unknown"


def _event_key(row: dict[str, str]) -> str:
    source = row.get("source_zip", "").strip()
    event = row.get("event_id", "").strip() or row.get("batch_id", "").strip()
    light = _light_key(row.get("light_kelvin", ""))
    return f"{source}|{event}|{light}"


def _samples_from_rows(rows: list[dict[str, str]]) -> list[Sample]:
    samples: list[Sample] = []
    all_columns = [
        column
        for analyte in ANALYTE_ORDER
        for column in feature_columns_for_analyte(analyte, feature_space="normalized_hsv")
    ]
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = canonicalize_level(analyte, row.get("level", ""))
        if analyte not in ANALYTE_ORDER or level is None:
            continue
        try:
            local = tuple(float(row[column]) for column in feature_columns_for_analyte(analyte, "normalized_hsv"))
            all30 = tuple(float(row[column]) for column in all_columns)
        except (KeyError, TypeError, ValueError):
            continue
        samples.append(
            Sample(
                analyte=analyte,
                level=level,
                event_key=_event_key(row),
                specimen_group=row.get("specimen_group") or _specimen_group(row),
                light_key=_light_key(row.get("light_kelvin", "")),
                split=row.get("split", "").strip().lower(),
                features_local=local,
                features_all30=all30,
            )
        )
    return samples


def _split_events(samples: list[Sample], split_mode: str, test_size: float, random_state: int) -> tuple[set[str], set[str]]:
    by_event: dict[str, Sample] = {}
    for sample in samples:
        by_event.setdefault(sample.event_key, sample)

    if split_mode == "csv":
        train_events = {key for key, sample in by_event.items() if sample.split == "train"}
        test_events = {key for key, sample in by_event.items() if sample.split == "test"}
        if train_events and test_events:
            return train_events, test_events

    events = sorted(by_event)
    groups = [by_event[event].specimen_group for event in events]
    splitter = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=random_state)
    train_idx, test_idx = next(splitter.split(events, groups=groups))
    return {events[i] for i in train_idx}, {events[i] for i in test_idx}


def _circular_transformer():
    return FunctionTransformer(hsv_to_circular_features, validate=False)


def _knn_model(k: int, metric: str, transform: str):
    knn = KNeighborsClassifier(n_neighbors=k, metric=metric, weights="distance")
    if transform == "scaled":
        return make_pipeline(StandardScaler(), knn)
    if transform == "circular_scaled":
        return make_pipeline(_circular_transformer(), StandardScaler(), knn)
    return knn


def _model_candidates(analyte: str, knn_opt: dict[str, Any]) -> dict[str, Any]:
    opt = knn_opt.get(analyte, {})
    k = int(opt.get("best_k", opt.get("k", 9)))
    metric = str(opt.get("best_metric", opt.get("metric", "euclidean")))
    transform = str(opt.get("feature_transform", "raw"))
    return {
        "knn_current": _knn_model(k, metric, transform),
        "knn_11_scaled": make_pipeline(StandardScaler(), KNeighborsClassifier(n_neighbors=11, metric="manhattan", weights="distance")),
        "random_forest": RandomForestClassifier(n_estimators=160, class_weight="balanced", random_state=17, n_jobs=-1),
        "extra_trees": ExtraTreesClassifier(n_estimators=220, class_weight="balanced", random_state=17, n_jobs=-1),
        "svm_rbf": make_pipeline(StandardScaler(), SVC(C=3.0, gamma="scale", class_weight="balanced", probability=True, random_state=17)),
        "calibrated_svm": make_pipeline(
            StandardScaler(),
            CalibratedClassifierCV(
                SVC(C=2.0, gamma="scale", class_weight="balanced", probability=False, random_state=17),
                cv=3,
            ),
        ),
        "centroid": make_pipeline(StandardScaler(), NearestCentroid()),
        "gaussian_nb": GaussianNB(),
    }


def _ensemble_model(analyte: str, knn_opt: dict[str, Any]):
    opt = knn_opt.get(analyte, {})
    return VotingClassifier(
        estimators=[
            (
                "knn",
                _knn_model(
                    int(opt.get("best_k", opt.get("k", 9))),
                    str(opt.get("best_metric", opt.get("metric", "euclidean"))),
                    str(opt.get("feature_transform", "raw")),
                ),
            ),
            ("extra", ExtraTreesClassifier(n_estimators=180, class_weight="balanced", random_state=23, n_jobs=-1)),
            ("svm", make_pipeline(StandardScaler(), SVC(C=3.0, gamma="scale", class_weight="balanced", probability=True, random_state=23))),
        ],
        voting="soft",
    )


def _feature(sample: Sample, feature_set: str) -> tuple[float, ...]:
    return sample.features_all30 if feature_set == "all30" else sample.features_local


def _fit_model(model: Any, x_train: list[tuple[float, ...]], y_train: list[str]) -> Any:
    if len(set(y_train)) < 2:
        return DummyClassifier(strategy="most_frequent").fit(x_train, y_train)
    return clone(model).fit(x_train, y_train)


def _confidence(model: Any, x_values: list[tuple[float, ...]]) -> list[float]:
    if hasattr(model, "predict_proba"):
        proba = model.predict_proba(x_values)
        return [float(max(row)) for row in proba]
    if hasattr(model, "decision_function"):
        scores = np.asarray(model.decision_function(x_values))
        if scores.ndim == 1:
            return [float(1.0 / (1.0 + np.exp(-abs(value)))) for value in scores]
        shifted = scores - scores.max(axis=1, keepdims=True)
        exp = np.exp(shifted)
        probs = exp / exp.sum(axis=1, keepdims=True)
        return [float(max(row)) for row in probs]
    return [1.0 for _ in x_values]


def _predict(model: Any, x_values: list[tuple[float, ...]]) -> tuple[list[str], list[float]]:
    predicted = [str(value) for value in model.predict(x_values).tolist()]
    return predicted, _confidence(model, x_values)


def _safe_candidates(
    analyte: str,
    knn_opt: dict[str, Any],
    train_size: int,
    class_count: int,
    profile: str,
) -> dict[str, Any]:
    candidates = _model_candidates(analyte, knn_opt)
    if profile == "full":
        candidates["soft_ensemble"] = _ensemble_model(analyte, knn_opt)
    if train_size < 45 or class_count < 3:
        candidates.pop("calibrated_svm", None)
    if profile == "fast":
        candidates.pop("calibrated_svm", None)
        candidates.pop("svm_rbf", None)
        candidates.pop("soft_ensemble", None)
    return candidates


def _evaluate_candidate(
    name: str,
    model: Any,
    train: list[Sample],
    test: list[Sample],
    feature_set: str,
) -> dict[str, Any]:
    x_train = [_feature(sample, feature_set) for sample in train]
    y_train = [sample.level for sample in train]
    x_test = [_feature(sample, feature_set) for sample in test]
    y_test = [sample.level for sample in test]
    fitted = _fit_model(model, x_train, y_train)
    y_pred, confidences = _predict(fitted, x_test)
    return {
        "name": name,
        "feature_set": feature_set,
        "accuracy": accuracy_score(y_test, y_pred) if y_test else 0.0,
        "f1_macro": f1_score(y_test, y_pred, average="macro", zero_division=0) if y_test else 0.0,
        "model": fitted,
        "predictions": y_pred,
        "confidences": confidences,
    }


def _evaluate_per_light(
    name: str,
    model: Any,
    train: list[Sample],
    test: list[Sample],
    feature_set: str,
    min_light_train: int,
) -> dict[str, Any] | None:
    global_x = [_feature(sample, feature_set) for sample in train]
    global_y = [sample.level for sample in train]
    global_model = _fit_model(model, global_x, global_y)
    by_light: dict[str, list[Sample]] = defaultdict(list)
    for sample in train:
        by_light[sample.light_key].append(sample)

    light_models: dict[str, Any] = {}
    for light, light_train in by_light.items():
        if len(light_train) >= min_light_train and len({sample.level for sample in light_train}) >= 2:
            light_models[light] = _fit_model(
                model,
                [_feature(sample, feature_set) for sample in light_train],
                [sample.level for sample in light_train],
            )

    if not light_models:
        return None

    y_true: list[str] = []
    y_pred: list[str] = []
    confidences: list[float] = []
    fallback_count = 0
    for sample in test:
        selected = light_models.get(sample.light_key)
        if selected is None:
            selected = global_model
            fallback_count += 1
        pred, conf = _predict(selected, [_feature(sample, feature_set)])
        y_true.append(sample.level)
        y_pred.append(pred[0])
        confidences.append(conf[0])

    return {
        "name": f"{name}_per_light",
        "feature_set": feature_set,
        "accuracy": accuracy_score(y_true, y_pred) if y_true else 0.0,
        "f1_macro": f1_score(y_true, y_pred, average="macro", zero_division=0) if y_true else 0.0,
        "model": {"global": global_model, "by_light": light_models},
        "predictions": y_pred,
        "confidences": confidences,
        "fallback_predictions": fallback_count,
    }


def _threshold_grid(predictions_by_analyte: dict[str, dict[str, Any]], test_samples_by_analyte: dict[str, list[Sample]]) -> list[dict[str, Any]]:
    event_payload: dict[str, dict[str, dict[str, Any]]] = defaultdict(dict)
    for analyte, candidate in predictions_by_analyte.items():
        samples = test_samples_by_analyte[analyte]
        for sample, prediction, confidence in zip(samples, candidate["predictions"], candidate["confidences"]):
            event_payload[sample.event_key][analyte] = {
                "expected": sample.level,
                "predicted": prediction,
                "confidence": float(confidence),
            }

    thresholds = [0.0, 0.35, 0.45, 0.55, 0.65, 0.75, 0.80, 0.85, 0.90, 0.95]
    summaries: list[dict[str, Any]] = []
    for threshold in thresholds:
        accepted_events = []
        rejected_events = []
        failure_analytes = Counter()
        rejection_analytes = Counter()
        analyte_correct = 0
        analyte_total = 0
        whole_correct = 0
        for event_key, analytes in event_payload.items():
            missing = [analyte for analyte in ANALYTE_ORDER if analyte not in analytes]
            low_conf = [
                analyte
                for analyte, item in analytes.items()
                if item["confidence"] < threshold
            ]
            if missing or low_conf:
                rejected_events.append(event_key)
                rejection_analytes.update(missing)
                rejection_analytes.update(low_conf)
                continue
            accepted_events.append(event_key)
            event_all_correct = True
            for analyte in ANALYTE_ORDER:
                item = analytes[analyte]
                is_correct = item["expected"] == item["predicted"]
                analyte_correct += int(is_correct)
                analyte_total += 1
                if not is_correct:
                    event_all_correct = False
                    failure_analytes[analyte] += 1
            whole_correct += int(event_all_correct)
        accepted = len(accepted_events)
        total = len(event_payload)
        summaries.append(
            {
                "threshold": threshold,
                "accepted_scan_rate": accepted / total if total else 0.0,
                "accepted_scans": accepted,
                "total_scans": total,
                "individual_analyte_accuracy": analyte_correct / analyte_total if analyte_total else 0.0,
                "individual_analyte_correct": analyte_correct,
                "individual_analyte_total": analyte_total,
                "whole_scan_all_10_correct_accuracy": whole_correct / accepted if accepted else 0.0,
                "whole_scan_correct": whole_correct,
                "failure_analytes": dict(failure_analytes.most_common()),
                "rejection_analytes": dict(rejection_analytes.most_common()),
            }
        )
    return summaries


def _format_percent(value: float) -> str:
    return f"{value * 100.0:6.2f}%"


def main() -> None:
    args = parse_args()
    raw_rows = _load_rows(args.features)
    rows, duplicate_count = _dedupe_rows(raw_rows)
    samples = _samples_from_rows(rows)
    train_events, test_events = _split_events(samples, args.split_mode, args.test_size, args.random_state)

    with args.knn_optimization.open(encoding="utf-8") as file:
        knn_opt = json.load(file)

    train_by_analyte: dict[str, list[Sample]] = defaultdict(list)
    test_by_analyte: dict[str, list[Sample]] = defaultdict(list)
    for sample in samples:
        if sample.event_key in train_events:
            train_by_analyte[sample.analyte].append(sample)
        elif sample.event_key in test_events:
            test_by_analyte[sample.analyte].append(sample)

    selected: dict[str, dict[str, Any]] = {}
    per_analyte_report: dict[str, Any] = {}
    print(f"Split: {args.split_mode} | profile={args.profile} | train events={len(train_events)} test events={len(test_events)}", flush=True)
    print(f"{'Analyte':<20} {'Selected':<22} {'Feat':<6} {'Acc':>8} {'F1':>8} {'KNN':>8}", flush=True)
    print("-" * 82, flush=True)
    for analyte in ANALYTE_ORDER:
        train = train_by_analyte[analyte]
        test = test_by_analyte[analyte]
        if not train or not test:
            raise SystemExit(f"Missing train/test samples for {analyte}")

        candidates: list[dict[str, Any]] = []
        feature_sets = ("local",) if args.selection == "knn_current" else ("local", "all30")
        for feature_set in feature_sets:
            model_items = _safe_candidates(
                analyte,
                knn_opt,
                len(train),
                len({sample.level for sample in train}),
                args.profile,
            ).items()
            if args.selection == "knn_current":
                model_items = [
                    (name, model)
                    for name, model in model_items
                    if name == "knn_current"
                ]
            for name, model in model_items:
                try:
                    candidates.append(_evaluate_candidate(name, model, train, test, feature_set))
                    if feature_set == "local" and name in {"knn_current", "random_forest", "extra_trees"}:
                        per_light = _evaluate_per_light(name, model, train, test, feature_set, args.min_light_train)
                        if per_light is not None:
                            candidates.append(per_light)
                except Exception as exc:
                    candidates.append(
                        {
                            "name": name,
                            "feature_set": feature_set,
                            "error": str(exc),
                            "accuracy": -1.0,
                            "f1_macro": -1.0,
                        }
                    )

        candidates.sort(key=lambda item: (item["accuracy"], item["f1_macro"], item["name"] == "knn_current"), reverse=True)
        if args.selection == "knn_current":
            best = next(
                item
                for item in candidates
                if item.get("name") == "knn_current" and item.get("feature_set") == "local"
            )
        else:
            best = candidates[0]
        selected[analyte] = best
        knn_baseline = next(
            item
            for item in candidates
            if item.get("name") == "knn_current" and item.get("feature_set") == "local"
        )
        per_analyte_report[analyte] = {
            "selected_model": best["name"],
            "selected_feature_set": best["feature_set"],
            "selected_accuracy": best["accuracy"],
            "selected_f1_macro": best["f1_macro"],
            "knn_current_accuracy": knn_baseline["accuracy"],
            "candidates": [
                {
                    key: value
                    for key, value in item.items()
                    if key not in {"model", "predictions", "confidences"}
                }
                for item in candidates
            ],
        }
        print(
            f"{analyte:<20} {best['name']:<22} {best['feature_set']:<6} "
            f"{_format_percent(best['accuracy']):>8} {_format_percent(best['f1_macro']):>8} "
            f"{_format_percent(knn_baseline['accuracy']):>8}"
        , flush=True)

    threshold_summaries = _threshold_grid(selected, test_by_analyte)
    recommended = max(
        threshold_summaries,
        key=lambda item: (
            item["whole_scan_all_10_correct_accuracy"],
            item["individual_analyte_accuracy"],
            item["accepted_scan_rate"],
        ),
    )
    balanced = max(
        threshold_summaries,
        key=lambda item: (
            item["accepted_scan_rate"] >= 0.50,
            item["whole_scan_all_10_correct_accuracy"],
            item["individual_analyte_accuracy"],
        ),
    )

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "features": str(args.features),
        "split_mode": args.split_mode,
        "profile": args.profile,
        "selection": args.selection,
        "raw_rows": len(raw_rows),
        "deduped_rows": len(rows),
        "duplicates_removed": duplicate_count,
        "train_events": len(train_events),
        "test_events": len(test_events),
        "train_samples": sum(len(values) for values in train_by_analyte.values()),
        "test_samples": sum(len(values) for values in test_by_analyte.values()),
        "per_analyte": per_analyte_report,
        "threshold_summaries": threshold_summaries,
        "recommended_max_accuracy_threshold": recommended,
        "recommended_balanced_threshold": balanced,
        "notes": [
            "Per-light models use dataset light labels for evaluation. Android needs a production light-selection rule before per-light routing is frozen.",
            "Model family selection on the test split is exploratory and should be confirmed on a separate holdout before manuscript claims.",
        ],
    }

    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    model_plan = {
        "generated_at": report["generated_at"],
        "split_mode": args.split_mode,
        "selected_models": {
            analyte: {
                "model": item["name"],
                "feature_set": item["feature_set"],
                "accuracy": round(float(item["accuracy"]), 6),
                "f1_macro": round(float(item["f1_macro"]), 6),
            }
            for analyte, item in selected.items()
        },
        "recommended_balanced_threshold": balanced["threshold"],
        "recommended_max_accuracy_threshold": recommended["threshold"],
    }
    with args.model_plan.open("w", encoding="utf-8") as file:
        json.dump(model_plan, file, indent=2)

    print("-" * 82)
    print("Confidence thresholds:")
    for item in threshold_summaries:
        print(
            f"  t={item['threshold']:<4} accepted={_format_percent(item['accepted_scan_rate'])} "
            f"ind={_format_percent(item['individual_analyte_accuracy'])} "
            f"all10={_format_percent(item['whole_scan_all_10_correct_accuracy'])}"
        )
    print(f"Saved report: {args.report}")
    print(f"Saved model plan: {args.model_plan}")


if __name__ == "__main__":
    main()
