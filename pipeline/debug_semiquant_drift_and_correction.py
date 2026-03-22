#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
from collections import Counter, defaultdict
from datetime import datetime, timezone
from statistics import mean
from typing import Any

from sklearn.metrics import accuracy_score, cohen_kappa_score, f1_score

from semiquant_schema import ANALYTE_ORDER


DEFAULT_DEV = pathlib.Path(__file__).parent / "output" / "features_gold_dev.csv"
DEFAULT_HOLD = pathlib.Path(__file__).parent / "output" / "features_gold_holdout.csv"
DEFAULT_OUT = pathlib.Path(__file__).parent / "output" / "semiquant_drift_debug.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Debug semiquant drift and test event-level normalization")
    parser.add_argument("--dev-features", type=pathlib.Path, default=DEFAULT_DEV)
    parser.add_argument("--holdout-features", type=pathlib.Path, default=DEFAULT_HOLD)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUT)
    return parser.parse_args()


def _safe_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _hsv_distance(a_h: float, a_s: float, a_v: float, b_h: float, b_s: float, b_v: float) -> float:
    raw_hue_delta = abs(a_h - b_h)
    hue_delta = min(raw_hue_delta, 360.0 - raw_hue_delta) / 180.0
    sat_delta = a_s - b_s
    val_delta = a_v - b_v
    return math.sqrt((hue_delta * hue_delta) + (sat_delta * sat_delta) + (val_delta * val_delta))


def _circular_mean_deg(values: list[float]) -> float:
    if not values:
        return 0.0
    sin_sum = sum(math.sin(math.radians(value)) for value in values)
    cos_sum = sum(math.cos(math.radians(value)) for value in values)
    if abs(sin_sum) < 1e-12 and abs(cos_sum) < 1e-12:
        return float(values[0])
    angle = math.degrees(math.atan2(sin_sum, cos_sum))
    return _normalize_hue(angle)


def _analyte_cols(analyte: str) -> tuple[str, str, str]:
    key = analyte.lower().replace(" ", "_")
    return f"{key}_h", f"{key}_s", f"{key}_v"


def load_rows(path: pathlib.Path) -> list[dict[str, Any]]:
    with open(path, newline="", encoding="utf-8") as file:
        source_rows = list(csv.DictReader(file))

    out: list[dict[str, Any]] = []
    for row in source_rows:
        analyte = (row.get("analyte") or "").strip()
        level = (row.get("level") or "").strip()
        event_id = (row.get("event_id") or "").strip()
        if analyte not in ANALYTE_ORDER or not level or not event_id:
            continue

        col_h, col_s, col_v = _analyte_cols(analyte)
        hue = _safe_float((row.get(col_h) or "").strip())
        sat = _safe_float((row.get(col_s) or "").strip())
        val = _safe_float((row.get(col_v) or "").strip())
        if hue is None or sat is None or val is None:
            continue

        out.append(
            {
                "event_id": event_id,
                "analyte": analyte,
                "level": level,
                "h": _normalize_hue(hue),
                "s": _clip_01(sat),
                "v": _clip_01(val),
            }
        )

    return out


def compute_event_anchors(rows: list[dict[str, Any]]) -> tuple[dict[str, tuple[float, float, float]], tuple[float, float, float]]:
    by_event: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        by_event[row["event_id"]].append(row)

    event_anchors: dict[str, tuple[float, float, float]] = {}
    mean_h_values: list[float] = []
    mean_s_values: list[float] = []
    mean_v_values: list[float] = []

    for event_id, items in by_event.items():
        hues = [item["h"] for item in items]
        sats = [item["s"] for item in items]
        vals = [item["v"] for item in items]
        h_mean = _circular_mean_deg(hues)
        s_mean = float(mean(sats))
        v_mean = float(mean(vals))
        event_anchors[event_id] = (h_mean, s_mean, v_mean)
        mean_h_values.append(h_mean)
        mean_s_values.append(s_mean)
        mean_v_values.append(v_mean)

    global_anchor = (
        _circular_mean_deg(mean_h_values),
        float(mean(mean_s_values)) if mean_s_values else 0.0,
        float(mean(mean_v_values)) if mean_v_values else 0.0,
    )

    return event_anchors, global_anchor


def apply_event_centering(
    rows: list[dict[str, Any]],
    event_anchors: dict[str, tuple[float, float, float]],
    target_anchor: tuple[float, float, float],
) -> list[dict[str, Any]]:
    target_h, target_s, target_v = target_anchor
    out: list[dict[str, Any]] = []

    for row in rows:
        event_anchor = event_anchors.get(row["event_id"])
        if event_anchor is None:
            out.append(dict(row))
            continue

        event_h, event_s, event_v = event_anchor
        corrected_h = _normalize_hue(row["h"] - event_h + target_h)
        corrected_s = _clip_01(row["s"] - event_s + target_s)
        corrected_v = _clip_01(row["v"] - event_v + target_v)

        out.append(
            {
                **row,
                "h": corrected_h,
                "s": corrected_s,
                "v": corrected_v,
            }
        )

    return out


def predict_by_nearest_neighbor(train_rows: list[dict[str, Any]], test_rows: list[dict[str, Any]]) -> tuple[list[str], list[str], dict[str, Any]]:
    by_analyte_train: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in train_rows:
        by_analyte_train[row["analyte"]].append(row)

    y_true: list[str] = []
    y_pred: list[str] = []
    confusion_pairs: Counter[tuple[str, str, str]] = Counter()

    for row in test_rows:
        analyte = row["analyte"]
        candidates = by_analyte_train.get(analyte, [])
        if not candidates:
            continue

        best_level: str | None = None
        best_distance = float("inf")
        for item in candidates:
            distance = _hsv_distance(row["h"], row["s"], row["v"], item["h"], item["s"], item["v"])
            if distance < best_distance:
                best_distance = distance
                best_level = item["level"]

        if best_level is None:
            continue

        true_label = f"{analyte}:{row['level']}"
        pred_label = f"{analyte}:{best_level}"
        y_true.append(true_label)
        y_pred.append(pred_label)
        if row["level"] != best_level:
            confusion_pairs[(analyte, row["level"], best_level)] += 1

    return y_true, y_pred, {
        "top_confusions": [
            {
                "analyte": analyte,
                "true_level": true_level,
                "pred_level": pred_level,
                "count": int(count),
            }
            for (analyte, true_level, pred_level), count in confusion_pairs.most_common(15)
        ]
    }


def summarize_metrics(y_true: list[str], y_pred: list[str]) -> dict[str, float | int]:
    if not y_true:
        return {
            "samples": 0,
            "accuracy": 0.0,
            "f1_macro": 0.0,
            "f1_weighted": 0.0,
            "cohen_kappa": 0.0,
        }

    labels = sorted(set(y_true) | set(y_pred))
    kappa = float(cohen_kappa_score(y_true, y_pred, labels=labels)) if len(labels) > 1 else 1.0

    return {
        "samples": len(y_true),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "f1_macro": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
        "f1_weighted": float(f1_score(y_true, y_pred, average="weighted", zero_division=0)),
        "cohen_kappa": kappa,
    }


def per_analyte_shift(dev_rows: list[dict[str, Any]], hold_rows: list[dict[str, Any]]) -> dict[str, Any]:
    report: dict[str, Any] = {}
    for analyte in ANALYTE_ORDER:
        dev_items = [row for row in dev_rows if row["analyte"] == analyte]
        hold_items = [row for row in hold_rows if row["analyte"] == analyte]
        if not dev_items or not hold_items:
            continue

        dev_h = [item["h"] for item in dev_items]
        dev_s = [item["s"] for item in dev_items]
        dev_v = [item["v"] for item in dev_items]
        hold_h = [item["h"] for item in hold_items]
        hold_s = [item["s"] for item in hold_items]
        hold_v = [item["v"] for item in hold_items]

        report[analyte] = {
            "dev_samples": len(dev_items),
            "holdout_samples": len(hold_items),
            "dev_mean": {
                "h": _circular_mean_deg(dev_h),
                "s": float(mean(dev_s)),
                "v": float(mean(dev_v)),
            },
            "holdout_mean": {
                "h": _circular_mean_deg(hold_h),
                "s": float(mean(hold_s)),
                "v": float(mean(hold_v)),
            },
        }

        report[analyte]["delta"] = {
            "h_abs_deg": float(
                min(
                    abs(report[analyte]["holdout_mean"]["h"] - report[analyte]["dev_mean"]["h"]),
                    360.0 - abs(report[analyte]["holdout_mean"]["h"] - report[analyte]["dev_mean"]["h"]),
                )
            ),
            "s": float(report[analyte]["holdout_mean"]["s"] - report[analyte]["dev_mean"]["s"]),
            "v": float(report[analyte]["holdout_mean"]["v"] - report[analyte]["dev_mean"]["v"]),
        }

    return report


def main() -> None:
    args = parse_args()

    dev_rows = load_rows(args.dev_features.resolve())
    hold_rows = load_rows(args.holdout_features.resolve())

    dev_event_anchors, dev_global_anchor = compute_event_anchors(dev_rows)
    hold_event_anchors, _hold_global_anchor = compute_event_anchors(hold_rows)

    baseline_true, baseline_pred, baseline_debug = predict_by_nearest_neighbor(dev_rows, hold_rows)
    baseline_metrics = summarize_metrics(baseline_true, baseline_pred)

    dev_corrected = apply_event_centering(dev_rows, dev_event_anchors, target_anchor=dev_global_anchor)
    hold_corrected = apply_event_centering(hold_rows, hold_event_anchors, target_anchor=dev_global_anchor)

    corrected_true, corrected_pred, corrected_debug = predict_by_nearest_neighbor(dev_corrected, hold_corrected)
    corrected_metrics = summarize_metrics(corrected_true, corrected_pred)

    shift_report = per_analyte_shift(dev_rows, hold_rows)
    largest_shift = sorted(
        (
            {
                "analyte": analyte,
                **values["delta"],
            }
            for analyte, values in shift_report.items()
        ),
        key=lambda item: (item["h_abs_deg"] + abs(item["s"]) * 100.0 + abs(item["v"]) * 100.0),
        reverse=True,
    )[:5]

    output = {
        "artifacts": {
            "dev_features": str(args.dev_features.resolve()),
            "holdout_features": str(args.holdout_features.resolve()),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "method": "Nearest-neighbor in analyte HSV with optional event-centering correction",
        },
        "dev_anchor": {
            "h": dev_global_anchor[0],
            "s": dev_global_anchor[1],
            "v": dev_global_anchor[2],
        },
        "baseline_no_correction": {
            "metrics": baseline_metrics,
            **baseline_debug,
        },
        "event_centering_correction": {
            "metrics": corrected_metrics,
            "delta_vs_baseline": {
                "accuracy": float(corrected_metrics["accuracy"] - baseline_metrics["accuracy"]),
                "f1_macro": float(corrected_metrics["f1_macro"] - baseline_metrics["f1_macro"]),
                "f1_weighted": float(corrected_metrics["f1_weighted"] - baseline_metrics["f1_weighted"]),
                "cohen_kappa": float(corrected_metrics["cohen_kappa"] - baseline_metrics["cohen_kappa"]),
            },
            **corrected_debug,
        },
        "per_analyte_drift": shift_report,
        "largest_shifted_analytes": largest_shift,
        "recommended_next": [
            "If correction improves holdout metrics, integrate event-centered normalization into feature extraction path.",
            "Collect 5500K calibration/gold events into training to reduce domain gap.",
            "Re-check pad grid with overlay output to rule out strip placement variance.",
        ],
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output.resolve(), "w", encoding="utf-8") as file:
        json.dump(output, file, indent=2)

    print(f"Saved drift debug report -> {args.output.resolve()}")
    print(
        "Baseline: "
        f"Acc={baseline_metrics['accuracy']:.4f}, "
        f"F1-macro={baseline_metrics['f1_macro']:.4f}, "
        f"Kappa={baseline_metrics['cohen_kappa']:.4f}"
    )
    print(
        "Event-centered: "
        f"Acc={corrected_metrics['accuracy']:.4f}, "
        f"F1-macro={corrected_metrics['f1_macro']:.4f}, "
        f"Kappa={corrected_metrics['cohen_kappa']:.4f}"
    )


if __name__ == "__main__":
    main()
