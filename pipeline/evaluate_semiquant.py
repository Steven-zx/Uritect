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
    from .semiquant_schema import ANALYTE_LEVEL_SCHEMA, ANALYTE_ORDER, canonicalize_level
    from .vision_pipeline import feature_columns_for_analyte
except ImportError as error:
    print(f"Failed to import pipeline modules: {error}")
    print("Run from repository root: python pipeline/evaluate_semiquant.py")
    sys.exit(1)

FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
CURRENT_MAP_PATH = pathlib.Path(__file__).parent / "output" / "knn_reference_map.json"
LEGACY_MAP_PATH = pathlib.Path(__file__).parent / "output" / "knn_reference_map_20260323_baseline_restored.json"
OUTPUT_PATH = pathlib.Path(__file__).parent / "output" / "semiquant_evaluation_metrics.json"

DEFAULT_ANALYTE_DISTANCE_WEIGHTS: dict[str, dict[str, float]] = {
    "Leukocytes": {"h": 1.35, "s": 0.95, "v": 0.70},
    "Nitrite": {"h": 1.45, "s": 0.90, "v": 0.65},
    "Urobilinogen": {"h": 1.15, "s": 1.00, "v": 0.85},
    "Protein": {"h": 0.95, "s": 1.15, "v": 1.00},
    "pH": {"h": 1.25, "s": 0.95, "v": 0.80},
    "Blood": {"h": 1.10, "s": 1.00, "v": 1.00},
    "Specific Gravity": {"h": 0.80, "s": 1.10, "v": 1.25},
    "Ketone": {"h": 1.00, "s": 1.05, "v": 1.00},
    "Bilirubin": {"h": 1.10, "s": 1.00, "v": 0.95},
    "Glucose": {"h": 0.90, "s": 1.15, "v": 1.10},
}


class LevelRef:
    def __init__(self, level: str, h: float, s: float, v: float):
        self.level = level
        self.h = h
        self.s = s
        self.v = v


class EventCenteringConfig:
    def __init__(
        self,
        enabled: bool,
        target_h: float,
        target_s: float,
        target_v: float,
        mode: str = "global",
        target_by_light: dict[str, tuple[float, float, float]] | None = None,
    ):
        self.enabled = enabled
        self.target_h = target_h
        self.target_s = target_s
        self.target_v = target_v
        self.mode = mode
        self.target_by_light = target_by_light or {}


class AbstainConfig:
    def __init__(
        self,
        enabled: bool,
        min_confidence: float,
        min_margin: float,
        max_distance: float,
    ):
        self.enabled = enabled
        self.min_confidence = min(max(min_confidence, 0.0), 1.0)
        self.min_margin = max(min_margin, 0.0)
        self.max_distance = max(max_distance, 0.0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate semiquant performance metrics")
    parser.add_argument("--features", type=pathlib.Path, default=FEATURES_PATH, help="Path to features.csv")
    parser.add_argument(
        "--map",
        type=pathlib.Path,
        default=None,
        help="Path to knn_reference_map.json (defaults to the current training map if present).",
    )
    parser.add_argument("--output", type=pathlib.Path, default=OUTPUT_PATH, help="Path for output JSON report")
    parser.add_argument(
        "--latency-runs",
        type=int,
        default=1,
        help="Repeat full prediction pass N times to average latency (default: 1)",
    )
    parser.add_argument(
        "--event-center-hsv",
        choices=["auto", "on", "off"],
        default="auto",
        help=(
            "Apply event-level HSV centering before prediction: "
            "'auto' follows map metadata, 'on' forces it, 'off' disables it."
        ),
    )
    parser.add_argument(
        "--distance-weight-profile",
        choices=["legacy", "analyte-v1"],
        default="legacy",
        help="Distance weighting profile for HSV channels.",
    )
    parser.add_argument(
        "--distance-weights-json",
        type=pathlib.Path,
        default=None,
        help=(
            "Optional JSON overrides for per-analyte HSV weights. "
            "Format: {\"Analyte\": {\"h\": 1.2, \"s\": 1.0, \"v\": 0.8}}"
        ),
    )
    parser.add_argument(
        "--abstain-band",
        choices=["off", "on"],
        default="off",
        help="Enable confidence/distance abstain band.",
    )
    parser.add_argument(
        "--abstain-min-confidence",
        type=float,
        default=0.0,
        help="Abstain if top class confidence is below this threshold.",
    )
    parser.add_argument(
        "--abstain-min-margin",
        type=float,
        default=0.0,
        help="Abstain if (top1_confidence - top2_confidence) is below this threshold.",
    )
    parser.add_argument(
        "--abstain-max-distance",
        type=float,
        default=999.0,
        help="Abstain if nearest distance exceeds this threshold.",
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


def _hsv_distance(
    a_h: float,
    a_s: float,
    a_v: float,
    b_h: float,
    b_s: float,
    b_v: float,
    w_h: float,
    w_s: float,
    w_v: float,
) -> float:
    raw_hue_delta = abs(a_h - b_h)
    hue_delta = min(raw_hue_delta, 360.0 - raw_hue_delta) / 180.0
    saturation_delta = a_s - b_s
    value_delta = a_v - b_v
    return math.sqrt(
        (w_h * hue_delta * hue_delta)
        + (w_s * saturation_delta * saturation_delta)
        + (w_v * value_delta * value_delta)
    )


def _load_distance_weights(
    profile: str,
    overrides_path: pathlib.Path | None,
) -> dict[str, tuple[float, float, float]]:
    if profile == "legacy":
        weights: dict[str, tuple[float, float, float]] = {
            analyte: (1.0, 1.0, 1.0) for analyte in ANALYTE_ORDER
        }
    else:
        weights = {
            analyte: (
                float(DEFAULT_ANALYTE_DISTANCE_WEIGHTS.get(analyte, {}).get("h", 1.0)),
                float(DEFAULT_ANALYTE_DISTANCE_WEIGHTS.get(analyte, {}).get("s", 1.0)),
                float(DEFAULT_ANALYTE_DISTANCE_WEIGHTS.get(analyte, {}).get("v", 1.0)),
            )
            for analyte in ANALYTE_ORDER
        }

    if overrides_path is None:
        return weights

    if not overrides_path.exists():
        raise FileNotFoundError(f"Distance weights override file not found: {overrides_path}")

    with open(overrides_path, "r", encoding="utf-8") as file:
        payload = json.load(file)

    if not isinstance(payload, dict):
        raise ValueError("distance-weights-json must contain a JSON object")

    for analyte, item in payload.items():
        if analyte not in ANALYTE_ORDER or not isinstance(item, dict):
            continue
        current = weights.get(analyte, (1.0, 1.0, 1.0))
        h = float(item.get("h", current[0]))
        s = float(item.get("s", current[1]))
        v = float(item.get("v", current[2]))
        weights[analyte] = (max(h, 0.0), max(s, 0.0), max(v, 0.0))

    return weights


def _circular_mean_deg(values: list[float]) -> float:
    if not values:
        return 0.0
    sin_sum = sum(math.sin(math.radians(value)) for value in values)
    cos_sum = sum(math.cos(math.radians(value)) for value in values)
    if abs(sin_sum) < 1e-12 and abs(cos_sum) < 1e-12:
        return _normalize_hue(float(values[0]))
    angle = math.degrees(math.atan2(sin_sum, cos_sum))
    return _normalize_hue(angle)


def load_features(path: pathlib.Path) -> list[dict[str, str]]:
    if not path.exists():
        raise FileNotFoundError(f"features.csv not found: {path}")

    with open(path, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    return rows


def load_reference_map(path: pathlib.Path) -> tuple[dict[str, list[LevelRef]], EventCenteringConfig]:
    if not path.exists():
        raise FileNotFoundError(f"knn_reference_map.json not found: {path}")

    with open(path, "r", encoding="utf-8") as file:
        payload = json.load(file)

    analytes_payload = payload.get("analytes", {})
    center_payload = payload.get("event_hsv_centering", {}) if isinstance(payload, dict) else {}
    center_target = center_payload.get("target_anchor", {}) if isinstance(center_payload, dict) else {}
    center_by_light_payload = center_payload.get("target_anchor_by_light", {}) if isinstance(center_payload, dict) else {}
    target_by_light: dict[str, tuple[float, float, float]] = {}
    if isinstance(center_by_light_payload, dict):
        for light, anchor in center_by_light_payload.items():
            if not isinstance(anchor, dict):
                continue
            target_by_light[str(light)] = (
                _normalize_hue(_safe_float(anchor.get("h", 0.0))),
                _clip_01(_safe_float(anchor.get("s", 0.0))),
                _clip_01(_safe_float(anchor.get("v", 0.0))),
            )

    centering = EventCenteringConfig(
        enabled=bool(center_payload.get("enabled", False)),
        target_h=_normalize_hue(_safe_float(center_target.get("h", 0.0))),
        target_s=_clip_01(_safe_float(center_target.get("s", 0.0))),
        target_v=_clip_01(_safe_float(center_target.get("v", 0.0))),
        mode=str(center_payload.get("mode", "global") or "global"),
        target_by_light=target_by_light,
    )
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

    return refs, centering


def semiquant_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level_raw = row.get("level", "").strip()
        if analyte in ANALYTE_ORDER and level_raw:
            canonical = canonicalize_level(analyte, level_raw)
            if canonical is not None:
                copied = dict(row)
                copied["level"] = canonical
                out.append(copied)
    return out


def build_event_anchors(rows: list[dict[str, str]]) -> dict[str, tuple[float, float, float]]:
    anchors: dict[str, tuple[float, float, float]] = {}

    for row in rows:
        event_id = row.get("event_id", "").strip()
        if not event_id or event_id in anchors:
            continue

        hues: list[float] = []
        sats: list[float] = []
        vals: list[float] = []
        for analyte_name in ANALYTE_ORDER:
            col_h, col_s, col_v = feature_columns_for_analyte(analyte_name)
            raw_h = row.get(col_h, "").strip()
            raw_s = row.get(col_s, "").strip()
            raw_v = row.get(col_v, "").strip()
            if not raw_h or not raw_s or not raw_v:
                continue
            hues.append(_normalize_hue(_safe_float(raw_h)))
            sats.append(_clip_01(_safe_float(raw_s)))
            vals.append(_clip_01(_safe_float(raw_v)))

        if not hues or not sats or not vals:
            continue

        anchors[event_id] = (
            _circular_mean_deg(hues),
            float(mean(sats)),
            float(mean(vals)),
        )

    return anchors


def apply_event_centering(
    h: float,
    s: float,
    v: float,
    event_id: str,
    light_kelvin: str,
    event_anchors: dict[str, tuple[float, float, float]] | None,
    config: EventCenteringConfig,
) -> tuple[float, float, float]:
    h0 = _normalize_hue(h)
    s0 = _clip_01(s)
    v0 = _clip_01(v)

    if not config.enabled or not event_anchors:
        return h0, s0, v0

    event_anchor = event_anchors.get(event_id)
    if event_anchor is None:
        return h0, s0, v0

    event_h, event_s, event_v = event_anchor
    target_h = config.target_h
    target_s = config.target_s
    target_v = config.target_v
    if config.mode == "per-light" and config.target_by_light:
        target_tuple = config.target_by_light.get(light_kelvin)
        if target_tuple is not None:
            target_h, target_s, target_v = target_tuple

    return (
        _normalize_hue(h0 - event_h + target_h),
        _clip_01(s0 - event_s + target_s),
        _clip_01(v0 - event_v + target_v),
    )


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
    distance_weights: dict[str, tuple[float, float, float]],
    abstain_config: AbstainConfig,
) -> tuple[str | None, float, float, float, bool]:
    candidates = refs.get(analyte, [])
    if not candidates:
        return None, 0.0, 0.0, 0.0, True

    w_h, w_s, w_v = distance_weights.get(analyte, (1.0, 1.0, 1.0))

    distances: list[tuple[str, float]] = []
    for ref in candidates:
        d = _hsv_distance(observed_h, observed_s, observed_v, ref.h, ref.s, ref.v, w_h, w_s, w_v)
        distances.append((ref.level, d))

    distances.sort(key=lambda item: item[1])
    best_level, best_distance = distances[0]

    inv_scores = [1.0 / (distance + 1e-9) for _, distance in distances]
    inv_score_sum = sum(inv_scores)
    if inv_score_sum <= 0:
        return None, 0.0, float(best_distance), 0.0, True

    probabilities = [score / inv_score_sum for score in inv_scores]
    confidence = float(probabilities[0])
    second_confidence = float(probabilities[1]) if len(probabilities) > 1 else 0.0
    confidence_margin = confidence - second_confidence

    should_abstain = False
    if abstain_config.enabled:
        if confidence < abstain_config.min_confidence:
            should_abstain = True
        if confidence_margin < abstain_config.min_margin:
            should_abstain = True
        if best_distance > abstain_config.max_distance:
            should_abstain = True

    if should_abstain:
        return None, confidence, float(best_distance), float(confidence_margin), True

    return best_level, confidence, float(best_distance), float(confidence_margin), False


def evaluate(
    rows: list[dict[str, str]],
    refs: dict[str, list[LevelRef]],
    event_anchors: dict[str, tuple[float, float, float]] | None,
    centering_config: EventCenteringConfig,
    distance_weights: dict[str, tuple[float, float, float]],
    abstain_config: AbstainConfig,
) -> dict[str, Any]:
    per_analyte_true: dict[str, list[str]] = defaultdict(list)
    per_analyte_pred: dict[str, list[str]] = defaultdict(list)

    confidence_by_analyte: dict[str, list[float]] = defaultdict(list)
    distance_by_analyte: dict[str, list[float]] = defaultdict(list)
    margin_by_analyte: dict[str, list[float]] = defaultdict(list)
    abstained_by_analyte: Counter[str] = Counter()

    dropped = 0
    abstained = 0

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

        h, s, v = apply_event_centering(
            _safe_float(raw_h),
            _safe_float(raw_s),
            _safe_float(raw_v),
            row.get("event_id", "").strip(),
            row.get("light_kelvin", "").strip(),
            event_anchors,
            centering_config,
        )

        pred, confidence, distance, margin, was_abstained = predict_one(
            analyte,
            h,
            s,
            v,
            refs,
            distance_weights,
            abstain_config,
        )
        if was_abstained:
            abstained += 1
            abstained_by_analyte[analyte] += 1
            continue

        if pred is None:
            dropped += 1
            continue

        per_analyte_true[analyte].append(level_true)
        per_analyte_pred[analyte].append(pred)
        confidence_by_analyte[analyte].append(confidence)
        distance_by_analyte[analyte].append(distance)
        margin_by_analyte[analyte].append(margin)

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
            "confidence_margin": {
                "mean": float(mean(margin_by_analyte.get(analyte, []))) if margin_by_analyte.get(analyte) else 0.0,
                "median": float(median(margin_by_analyte.get(analyte, []))) if margin_by_analyte.get(analyte) else 0.0,
                "min": float(min(margin_by_analyte.get(analyte, []))) if margin_by_analyte.get(analyte) else 0.0,
                "max": float(max(margin_by_analyte.get(analyte, []))) if margin_by_analyte.get(analyte) else 0.0,
            },
            "nearest_distance": {
                "mean": float(mean(dist_values)) if dist_values else 0.0,
                "median": float(median(dist_values)) if dist_values else 0.0,
                "min": float(min(dist_values)) if dist_values else 0.0,
                "max": float(max(dist_values)) if dist_values else 0.0,
            },
            "abstained_samples": int(abstained_by_analyte.get(analyte, 0)),
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
        "samples_abstained": abstained,
        "coverage": float(len(overall_true) / len(rows)) if rows else 0.0,
        "overall": {
            "accuracy": overall_accuracy,
            "f1_macro": overall_f1_macro,
            "f1_weighted": overall_f1_weighted,
            "cohen_kappa": overall_kappa,
        },
        "per_analyte": analyte_reports,
    }


def benchmark_latency(
    rows: list[dict[str, str]],
    refs: dict[str, list[LevelRef]],
    runs: int,
    event_anchors: dict[str, tuple[float, float, float]] | None,
    centering_config: EventCenteringConfig,
    distance_weights: dict[str, tuple[float, float, float]],
    abstain_config: AbstainConfig,
) -> dict[str, Any]:
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
        h, s, v = apply_event_centering(
            _safe_float(raw_h),
            _safe_float(raw_s),
            _safe_float(raw_v),
            row.get("event_id", "").strip(),
            row.get("light_kelvin", "").strip(),
            event_anchors,
            centering_config,
        )
        observed_samples.append((analyte, h, s, v))

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
            predict_one(analyte, h, s, v, refs, distance_weights, abstain_config)
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
    map_path = args.map
    if map_path is None:
        map_path = CURRENT_MAP_PATH if CURRENT_MAP_PATH.exists() else LEGACY_MAP_PATH
    refs, map_centering = load_reference_map(map_path)

    rows = semiquant_rows(features)
    if not rows:
        print("No semiquant rows found in features. Run ingest pipeline first.")
        sys.exit(1)

    use_centering = map_centering.enabled if args.event_center_hsv == "auto" else args.event_center_hsv == "on"
    centering_config = EventCenteringConfig(
        enabled=use_centering,
        target_h=map_centering.target_h,
        target_s=map_centering.target_s,
        target_v=map_centering.target_v,
        mode=map_centering.mode,
        target_by_light=map_centering.target_by_light,
    )
    event_anchors = build_event_anchors(rows) if use_centering else {}
    distance_weights = _load_distance_weights(args.distance_weight_profile, args.distance_weights_json)
    abstain_config = AbstainConfig(
        enabled=args.abstain_band == "on",
        min_confidence=args.abstain_min_confidence,
        min_margin=args.abstain_min_margin,
        max_distance=args.abstain_max_distance,
    )

    report = evaluate(
        rows,
        refs,
        event_anchors,
        centering_config,
        distance_weights,
        abstain_config,
    )
    report["latency_benchmark_ms"] = benchmark_latency(
        rows,
        refs,
        runs=args.latency_runs,
        event_anchors=event_anchors,
        centering_config=centering_config,
        distance_weights=distance_weights,
        abstain_config=abstain_config,
    )
    report["artifacts"] = {
        "features_path": str(args.features.resolve()),
        "reference_map_path": str(map_path.resolve()),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "event_hsv_centering": {
            "mode": args.event_center_hsv,
            "enabled": use_centering,
            "target_mode": centering_config.mode,
            "target_anchor": {
                "h": centering_config.target_h,
                "s": centering_config.target_s,
                "v": centering_config.target_v,
            },
            "target_anchor_by_light": {
                light: {
                    "h": values[0],
                    "s": values[1],
                    "v": values[2],
                }
                for light, values in sorted(centering_config.target_by_light.items())
            },
            "events_with_anchor": len(event_anchors),
        },
        "distance_weighting": {
            "profile": args.distance_weight_profile,
            "overrides_path": str(args.distance_weights_json.resolve()) if args.distance_weights_json else None,
            "weights": {
                analyte: {"h": weights[0], "s": weights[1], "v": weights[2]}
                for analyte, weights in sorted(distance_weights.items())
            },
        },
        "abstain_band": {
            "enabled": abstain_config.enabled,
            "min_confidence": abstain_config.min_confidence,
            "min_margin": abstain_config.min_margin,
            "max_distance": abstain_config.max_distance,
        },
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
