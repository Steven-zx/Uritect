#!/usr/bin/env python3
"""
Evaluate semiquant performance from features.csv against knn_reference_map.json.

Outputs agreement and technical metrics suitable for thesis reporting:
- Overall and per-analyte accuracy
- Macro/weighted F1
- Cohen's kappa
- Per-analyte confusion matrices
- One-vs-rest sensitivity/specificity summaries
- Soft visual confidence summary
- Latency benchmark (ms)
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timezone
from statistics import mean, median
from typing import Any

try:
    from sklearn.metrics import accuracy_score, cohen_kappa_score, confusion_matrix, f1_score
except ImportError:
    print("Missing dependencies. Run: pip install -r pipeline/requirements.txt")
    sys.exit(1)

try:
    from semiquant_schema import ANALYTE_LEVEL_SCHEMA, ANALYTE_ORDER, canonicalize_level
    from vision_pipeline import feature_columns_for_analyte
except ImportError as error:
    print(f"Failed to import pipeline modules: {error}")
    print("Run from repository root: python pipeline/evaluate_semiquant.py")
    sys.exit(1)

FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
MAP_PATH = pathlib.Path(__file__).parent / "output" / "knn_reference_map.json"
OUTPUT_PATH = pathlib.Path(__file__).parent / "output" / "semiquant_evaluation_metrics.json"


class LevelRef:
    def __init__(self, level: str, h: float, s: float, v: float):
        self.level = level
        self.h = h
        self.s = s
        self.v = v


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate semiquant performance metrics")
    parser.add_argument("--features", type=pathlib.Path, default=FEATURES_PATH, help="Path to features.csv")
    parser.add_argument("--map", type=pathlib.Path, default=MAP_PATH, help="Path to knn_reference_map.json")
    parser.add_argument("--output", type=pathlib.Path, default=OUTPUT_PATH, help="Path for output JSON report")
    parser.add_argument(
        "--latency-runs",
        type=int,
        default=1,
        help="Repeat full prediction pass N times to average latency (default: 1)",
    )
    return parser.parse_args()


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _hsv_distance(a_h: float, a_s: float, a_v: float, b_h: float, b_s: float, b_v: float) -> float:
    raw_hue_delta = abs(a_h - b_h)
    hue_delta = min(raw_hue_delta, 360.0 - raw_hue_delta) / 180.0
    saturation_delta = a_s - b_s
    value_delta = a_v - b_v
    return math.sqrt((hue_delta * hue_delta) + (saturation_delta * saturation_delta) + (value_delta * value_delta))


def load_features(path: pathlib.Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"features.csv not found: {path}")

    with open(path, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    return rows


def load_reference_map(path: pathlib.Path) -> dict[str, list[LevelRef]]:
    if not path.exists():
        raise FileNotFoundError(f"knn_reference_map.json not found: {path}")

    with open(path, "r", encoding="utf-8") as file:
        payload = json.load(file)

    analytes_payload = payload.get("analytes", {})
    refs: dict[str, list[LevelRef]] = {}

    for analyte_name in ANALYTE_ORDER:
        items = analytes_payload.get(analyte_name, [])
        level_refs: list[LevelRef] = []

        for item in items:
            if not isinstance(item, dict):
                continue

            level_raw = str(item.get("level", "")).strip()
            level = canonicalize_level(analyte_name, level_raw)
            if level is None:
                continue

            if "h" not in item or "s" not in item or "v" not in item:
                continue

            level_refs.append(
                LevelRef(
                    level=level,
                    h=_normalize_hue(_safe_float(item.get("h"))),
                    s=_clip_01(_safe_float(item.get("s"))),
                    v=_clip_01(_safe_float(item.get("v"))),
                )
            )

        if level_refs:
            refs[analyte_name] = level_refs

    return refs


def semiquant_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for row in rows:
        mode = row.get("label_mode", "").strip().lower()
        analyte = row.get("analyte", "").strip()
        level_raw = row.get("level", "").strip()
        if mode == "semiquant" and analyte in ANALYTE_ORDER and level_raw:
            canonical = canonicalize_level(analyte, level_raw)
            if canonical is not None:
                copied = dict(row)
                copied["level"] = canonical
                out.append(copied)
    return out


def _sensitivity_specificity_one_vs_rest(y_true: list[str], y_pred: list[str], labels: list[str]) -> dict[str, Any]:
    per_label: dict[str, dict[str, float | int]] = {}
    sensitivities: list[float] = []
    specificities: list[float] = []

    for label in labels:
        tp = fp = fn = tn = 0
        for t, p in zip(y_true, y_pred):
            is_pos_true = t == label
            is_pos_pred = p == label
            if is_pos_true and is_pos_pred:
                tp += 1
            elif not is_pos_true and is_pos_pred:
                fp += 1
            elif is_pos_true and not is_pos_pred:
                fn += 1
            else:
                tn += 1

        sensitivity = (tp / (tp + fn)) if (tp + fn) > 0 else 0.0
        specificity = (tn / (tn + fp)) if (tn + fp) > 0 else 0.0
        sensitivities.append(float(sensitivity))
        specificities.append(float(specificity))
        per_label[label] = {
            "tp": tp,
            "fp": fp,
            "fn": fn,
            "tn": tn,
            "sensitivity": float(sensitivity),
            "specificity": float(specificity),
        }

    return {
        "macro_sensitivity": float(mean(sensitivities)) if sensitivities else 0.0,
        "macro_specificity": float(mean(specificities)) if specificities else 0.0,
        "per_level": per_label,
    }


def predict_one(
    analyte: str,
    observed_h: float,
    observed_s: float,
    observed_v: float,
    refs: dict[str, list[LevelRef]],
) -> tuple[str | None, float, float]:
    candidates = refs.get(analyte, [])
    if not candidates:
        return None, 0.0, 0.0

    distances: list[tuple[str, float]] = []
    for ref in candidates:
        d = _hsv_distance(observed_h, observed_s, observed_v, ref.h, ref.s, ref.v)
        distances.append((ref.level, d))

    distances.sort(key=lambda item: item[1])
    best_level, best_distance = distances[0]

    inv_scores = [1.0 / (distance + 1e-9) for _, distance in distances]
    confidence = inv_scores[0] / sum(inv_scores)
    return best_level, float(confidence), float(best_distance)


def evaluate(rows: list[dict[str, str]], refs: dict[str, list[LevelRef]]) -> dict[str, Any]:
    per_analyte_true: dict[str, list[str]] = defaultdict(list)
    per_analyte_pred: dict[str, list[str]] = defaultdict(list)

    confidence_by_analyte: dict[str, list[float]] = defaultdict(list)
    distance_by_analyte: dict[str, list[float]] = defaultdict(list)

    dropped = 0

    for row in rows:
        analyte = row["analyte"].strip()
        level_true = row["level"].strip()
        if analyte not in ANALYTE_ORDER:
            continue

        col_h, col_s, col_v = feature_columns_for_analyte(analyte)
        raw_h = row.get(col_h, "").strip()
        raw_s = row.get(col_s, "").strip()
        raw_v = row.get(col_v, "").strip()
        if not raw_h or not raw_s or not raw_v:
            dropped += 1
            continue

        h = _normalize_hue(_safe_float(raw_h))
        s = _clip_01(_safe_float(raw_s))
        v = _clip_01(_safe_float(raw_v))

        pred, confidence, distance = predict_one(analyte, h, s, v, refs)
        if pred is None:
            dropped += 1
            continue

        per_analyte_true[analyte].append(level_true)
        per_analyte_pred[analyte].append(pred)
        confidence_by_analyte[analyte].append(confidence)
        distance_by_analyte[analyte].append(distance)

    overall_true: list[str] = []
    overall_pred: list[str] = []

    analyte_reports: dict[str, Any] = {}

    for analyte in ANALYTE_ORDER:
        y_true = per_analyte_true.get(analyte, [])
        y_pred = per_analyte_pred.get(analyte, [])
        if not y_true:
            continue

        labels = [level for level in ANALYTE_LEVEL_SCHEMA[analyte] if level in set(y_true) | set(y_pred)]
        if not labels:
            labels = sorted(set(y_true) | set(y_pred))

        accuracy = float(accuracy_score(y_true, y_pred))
        f1_macro = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
        f1_weighted = float(f1_score(y_true, y_pred, average="weighted", zero_division=0))
        kappa = float(cohen_kappa_score(y_true, y_pred, labels=labels)) if len(labels) > 1 else 1.0

        cm = confusion_matrix(y_true, y_pred, labels=labels)
        ss = _sensitivity_specificity_one_vs_rest(y_true, y_pred, labels)

        conf_values = confidence_by_analyte.get(analyte, [])
        dist_values = distance_by_analyte.get(analyte, [])

        analyte_reports[analyte] = {
            "samples": len(y_true),
            "accuracy": accuracy,
            "f1_macro": f1_macro,
            "f1_weighted": f1_weighted,
            "cohen_kappa": kappa,
            "agreement": {
                "macro_sensitivity": ss["macro_sensitivity"],
                "macro_specificity": ss["macro_specificity"],
                "per_level": ss["per_level"],
            },
            "confusion_matrix": {
                "labels": labels,
                "matrix": cm.tolist(),
            },
            "support_per_level": dict(sorted(Counter(y_true).items())),
            "soft_visual_probability": {
                "mean": float(mean(conf_values)) if conf_values else 0.0,
                "median": float(median(conf_values)) if conf_values else 0.0,
                "min": float(min(conf_values)) if conf_values else 0.0,
                "max": float(max(conf_values)) if conf_values else 0.0,
            },
            "nearest_distance": {
                "mean": float(mean(dist_values)) if dist_values else 0.0,
                "median": float(median(dist_values)) if dist_values else 0.0,
                "min": float(min(dist_values)) if dist_values else 0.0,
                "max": float(max(dist_values)) if dist_values else 0.0,
            },
        }

        overall_true.extend([f"{analyte}:{item}" for item in y_true])
        overall_pred.extend([f"{analyte}:{item}" for item in y_pred])

    overall_accuracy = float(accuracy_score(overall_true, overall_pred)) if overall_true else 0.0
    overall_f1_macro = float(f1_score(overall_true, overall_pred, average="macro", zero_division=0)) if overall_true else 0.0
    overall_f1_weighted = float(f1_score(overall_true, overall_pred, average="weighted", zero_division=0)) if overall_true else 0.0
    overall_kappa = float(cohen_kappa_score(overall_true, overall_pred)) if len(set(overall_true) | set(overall_pred)) > 1 else 1.0

    return {
        "samples_total": len(rows),
        "samples_evaluated": len(overall_true),
        "samples_dropped": dropped,
        "overall": {
            "accuracy": overall_accuracy,
            "f1_macro": overall_f1_macro,
            "f1_weighted": overall_f1_weighted,
            "cohen_kappa": overall_kappa,
        },
        "per_analyte": analyte_reports,
    }


def benchmark_latency(rows: list[dict[str, str]], refs: dict[str, list[LevelRef]], runs: int) -> dict[str, Any]:
    if runs < 1:
        runs = 1

    observed_samples: list[tuple[str, float, float, float]] = []
    for row in rows:
        analyte = row["analyte"].strip()
        if analyte not in ANALYTE_ORDER:
            continue
        col_h, col_s, col_v = feature_columns_for_analyte(analyte)
        raw_h = row.get(col_h, "").strip()
        raw_s = row.get(col_s, "").strip()
        raw_v = row.get(col_v, "").strip()
        if not raw_h or not raw_s or not raw_v:
            continue
        observed_samples.append((
            analyte,
            _normalize_hue(_safe_float(raw_h)),
            _clip_01(_safe_float(raw_s)),
            _clip_01(_safe_float(raw_v)),
        ))

    if not observed_samples:
        return {
            "runs": runs,
            "samples_per_run": 0,
            "total_predictions": 0,
            "total_elapsed_ms": 0.0,
            "avg_elapsed_ms_per_run": 0.0,
            "avg_elapsed_ms_per_prediction": 0.0,
        }

    start = time.perf_counter()
    total_predictions = 0
    for _ in range(runs):
        for analyte, h, s, v in observed_samples:
            predict_one(analyte, h, s, v, refs)
            total_predictions += 1
    elapsed_ms = (time.perf_counter() - start) * 1000.0

    return {
        "runs": runs,
        "samples_per_run": len(observed_samples),
        "total_predictions": total_predictions,
        "total_elapsed_ms": float(elapsed_ms),
        "avg_elapsed_ms_per_run": float(elapsed_ms / runs),
        "avg_elapsed_ms_per_prediction": float(elapsed_ms / total_predictions),
    }


def main() -> None:
    args = parse_args()

    features = load_features(args.features)
    refs = load_reference_map(args.map)

    rows = semiquant_rows(features)
    if not rows:
        print("No semiquant rows found in features. Run ingest pipeline first.")
        sys.exit(1)

    report = evaluate(rows, refs)
    report["latency_benchmark_ms"] = benchmark_latency(rows, refs, runs=args.latency_runs)
    report["artifacts"] = {
        "features_path": str(args.features.resolve()),
        "reference_map_path": str(args.map.resolve()),
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Saved semiquant evaluation report -> {args.output.resolve()}")
    print(f"Samples evaluated: {report['samples_evaluated']} / {report['samples_total']}")
    print(
        "Overall: "
        f"Acc={report['overall']['accuracy']:.4f}, "
        f"F1-macro={report['overall']['f1_macro']:.4f}, "
        f"Kappa={report['overall']['cohen_kappa']:.4f}"
    )
    latency = report["latency_benchmark_ms"]
    print(
        "Latency: "
        f"avg/run={latency['avg_elapsed_ms_per_run']:.3f} ms, "
        f"avg/pred={latency['avg_elapsed_ms_per_prediction']:.5f} ms"
    )


if __name__ == "__main__":
    main()
