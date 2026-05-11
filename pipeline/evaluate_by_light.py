#!/usr/bin/env python3
"""Evaluate semiquant metrics separately for each lighting condition.

This script reuses the semiquant evaluation logic and subsets rows by
light_kelvin so you can compare model behavior under 2700K, 4000K, and 5500K.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
from typing import Any

from evaluate_semiquant import (
    CURRENT_MAP_PATH,
    LEGACY_MAP_PATH,
    AbstainConfig,
    EventCenteringConfig,
    benchmark_latency,
    evaluate,
    load_features,
    load_reference_map,
    parse_args as _unused_parse_args,
    semiquant_rows,
    _load_distance_weights,
)


DEFAULT_FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_OUTPUT_JSON = pathlib.Path(__file__).parent / "output" / "per_light_ablation.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate semiquant performance by light")
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES_PATH)
    parser.add_argument("--map", type=pathlib.Path, default=None)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT_JSON)
    parser.add_argument(
        "--event-center-hsv",
        choices=["auto", "on", "off"],
        default="auto",
        help="Apply event-level HSV centering before prediction.",
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
        help="Optional JSON overrides for per-analyte HSV weights.",
    )
    parser.add_argument("--latency-runs", type=int, default=1)
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    map_path = args.map
    if map_path is None:
        map_path = CURRENT_MAP_PATH if CURRENT_MAP_PATH.exists() else LEGACY_MAP_PATH

    rows = load_features(args.features)
    refs, map_centering = load_reference_map(map_path)

    semiquant = semiquant_rows(rows)
    if not semiquant:
        raise SystemExit("No semiquant rows found in features.csv")

    use_centering = map_centering.enabled if args.event_center_hsv == "auto" else args.event_center_hsv == "on"
    centering_config = EventCenteringConfig(
        enabled=use_centering,
        target_h=map_centering.target_h,
        target_s=map_centering.target_s,
        target_v=map_centering.target_v,
        mode=map_centering.mode,
        target_by_light=map_centering.target_by_light,
    )
    distance_weights = _load_distance_weights(args.distance_weight_profile, args.distance_weights_json)
    abstain_config = AbstainConfig(enabled=False, min_confidence=0.0, min_margin=0.0, max_distance=999.0)

    by_light: dict[str, list[dict[str, str]]] = {}
    for light in ("2700", "4000", "5500"):
        subset = [row for row in semiquant if row.get("light_kelvin", "").strip() == light]
        by_light[light] = subset

    overall_true = semiquant
    report: dict[str, Any] = {
        "features_path": str(args.features.resolve()),
        "reference_map_path": str(map_path.resolve()),
        "event_center_hsv": {
            "requested": args.event_center_hsv,
            "enabled": use_centering,
            "target_mode": centering_config.mode,
        },
        "distance_weight_profile": args.distance_weight_profile,
        "lights": {},
    }

    overall_metrics = evaluate(
        overall_true,
        refs,
        event_anchors=None,
        centering_config=centering_config,
        distance_weights=distance_weights,
        abstain_config=abstain_config,
    )
    report["overall"] = overall_metrics["overall"]

    for light, subset in by_light.items():
        event_anchors = None
        if use_centering:
            # build_event_anchors is internal to evaluate_semiquant; the evaluation
            # function only needs it if centering is active, so mirror the same
            # behavior with a small local import to avoid a duplicate implementation.
            from evaluate_semiquant import build_event_anchors

            event_anchors = build_event_anchors(subset)

        metrics = evaluate(
            subset,
            refs,
            event_anchors=event_anchors,
            centering_config=centering_config,
            distance_weights=distance_weights,
            abstain_config=abstain_config,
        )
        metrics["latency_benchmark_ms"] = benchmark_latency(
            subset,
            refs,
            runs=args.latency_runs,
            event_anchors=event_anchors,
            centering_config=centering_config,
            distance_weights=distance_weights,
            abstain_config=abstain_config,
        )
        report["lights"][light] = {
            "samples_total": metrics["samples_total"],
            "samples_evaluated": metrics["samples_evaluated"],
            "samples_dropped": metrics["samples_dropped"],
            "samples_abstained": metrics["samples_abstained"],
            "coverage": metrics["coverage"],
            "overall": metrics["overall"],
            "per_analyte": metrics["per_analyte"],
            "latency_benchmark_ms": metrics["latency_benchmark_ms"],
        }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Saved per-light evaluation report -> {args.output.resolve()}")
    for light in ("2700", "4000", "5500"):
        metrics = report["lights"].get(light, {})
        overall = metrics.get("overall", {})
        print(
            f"  {light}: Acc={overall.get('accuracy', 0.0):.4f}, "
            f"F1-macro={overall.get('f1_macro', 0.0):.4f}, "
            f"Kappa={overall.get('cohen_kappa', 0.0):.4f}"
        )


if __name__ == "__main__":
    main()
