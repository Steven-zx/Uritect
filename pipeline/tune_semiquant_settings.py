#!/usr/bin/env python3
"""Sweep semiquant evaluation settings and report the best combinations.

This script is a lightweight tuning harness for the current reference-map based
evaluation path. It compares event centering on/off and distance-weight profiles
against the existing features.csv + knn_reference_map.json artifacts.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
from dataclasses import dataclass
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
    semiquant_rows,
    _load_distance_weights,
)


DEFAULT_FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
DEFAULT_OUTPUT_JSON = pathlib.Path(__file__).parent / "output" / "semiquant_tuning_report.json"
DEFAULT_OUTPUT_CSV = pathlib.Path(__file__).parent / "output" / "semiquant_tuning_results.csv"


@dataclass(frozen=True)
class Candidate:
    event_center_hsv: str
    distance_weight_profile: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Tune semiquant evaluation settings")
    parser.add_argument("--features", type=pathlib.Path, default=DEFAULT_FEATURES_PATH)
    parser.add_argument("--map", type=pathlib.Path, default=None)
    parser.add_argument("--output-json", type=pathlib.Path, default=DEFAULT_OUTPUT_JSON)
    parser.add_argument("--output-csv", type=pathlib.Path, default=DEFAULT_OUTPUT_CSV)
    parser.add_argument("--latency-runs", type=int, default=1)
    parser.add_argument("--distance-weights-json", type=pathlib.Path, default=None)
    return parser.parse_args()


def resolve_map_path(explicit: pathlib.Path | None) -> pathlib.Path:
    if explicit is not None:
        return explicit
    return CURRENT_MAP_PATH if CURRENT_MAP_PATH.exists() else LEGACY_MAP_PATH


def evaluate_candidate(
    rows: list[dict[str, str]],
    refs: dict[str, list[Any]],
    map_centering: EventCenteringConfig,
    candidate: Candidate,
    distance_weights_json: pathlib.Path | None,
    latency_runs: int,
) -> dict[str, Any]:
    use_centering = map_centering.enabled if candidate.event_center_hsv == "auto" else candidate.event_center_hsv == "on"
    centering_config = EventCenteringConfig(
        enabled=use_centering,
        target_h=map_centering.target_h,
        target_s=map_centering.target_s,
        target_v=map_centering.target_v,
        mode=map_centering.mode,
        target_by_light=map_centering.target_by_light,
    )
    event_anchors = None
    if use_centering:
        from evaluate_semiquant import build_event_anchors

        event_anchors = build_event_anchors(rows)

    distance_weights = _load_distance_weights(candidate.distance_weight_profile, distance_weights_json)
    abstain_config = AbstainConfig(enabled=False, min_confidence=0.0, min_margin=0.0, max_distance=999.0)

    report = evaluate(rows, refs, event_anchors, centering_config, distance_weights, abstain_config)
    report["latency_benchmark_ms"] = benchmark_latency(
        rows,
        refs,
        runs=latency_runs,
        event_anchors=event_anchors,
        centering_config=centering_config,
        distance_weights=distance_weights,
        abstain_config=abstain_config,
    )
    report["candidate"] = {
        "event_center_hsv": candidate.event_center_hsv,
        "distance_weight_profile": candidate.distance_weight_profile,
        "use_centering": use_centering,
        "target_mode": centering_config.mode,
    }
    return report


def main() -> None:
    args = parse_args()
    map_path = resolve_map_path(args.map)
    rows = semiquant_rows(load_features(args.features))
    if not rows:
        raise SystemExit("No semiquant rows found in features.csv")

    refs, map_centering = load_reference_map(map_path)

    candidates = [
        Candidate(event_center_hsv=center, distance_weight_profile=profile)
        for center in ("off", "on")
        for profile in ("legacy", "analyte-v1")
    ]

    results: list[dict[str, Any]] = []
    best_overall: dict[str, Any] | None = None
    best_score = -1.0

    for candidate in candidates:
        report = evaluate_candidate(
            rows=rows,
            refs=refs,
            map_centering=map_centering,
            candidate=candidate,
            distance_weights_json=args.distance_weights_json,
            latency_runs=args.latency_runs,
        )
        score = float(report["overall"]["f1_macro"])
        results.append(
            {
                "event_center_hsv": candidate.event_center_hsv,
                "distance_weight_profile": candidate.distance_weight_profile,
                "accuracy": report["overall"]["accuracy"],
                "f1_macro": report["overall"]["f1_macro"],
                "f1_weighted": report["overall"]["f1_weighted"],
                "cohen_kappa": report["overall"]["cohen_kappa"],
                "latency_ms_per_run": report["latency_benchmark_ms"]["avg_elapsed_ms_per_run"],
                "latency_ms_per_prediction": report["latency_benchmark_ms"]["avg_elapsed_ms_per_prediction"],
            }
        )
        if score > best_score:
            best_score = score
            best_overall = report

    per_analyte_best: dict[str, dict[str, Any]] = {}
    if best_overall is not None:
        for analyte, metrics in best_overall["per_analyte"].items():
            per_analyte_best[analyte] = {
                "accuracy": metrics.get("accuracy", 0.0),
                "f1_macro": metrics.get("f1_macro", 0.0),
                "cohen_kappa": metrics.get("cohen_kappa", 0.0),
            }

    results_sorted = sorted(results, key=lambda item: (item["f1_macro"], item["accuracy"], item["cohen_kappa"]), reverse=True)
    best = results_sorted[0] if results_sorted else {}
    payload = {
        "features_path": str(args.features.resolve()),
        "reference_map_path": str(map_path.resolve()),
        "candidate_count": len(candidates),
        "results": results_sorted,
        "best_overall": best_overall["overall"] if best_overall else {},
        "best_candidate": {
            "event_center_hsv": best.get("event_center_hsv"),
            "distance_weight_profile": best.get("distance_weight_profile"),
        },
        "best_per_analyte": per_analyte_best,
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    with args.output_json.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)

    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open("w", newline="", encoding="utf-8") as file:
        fieldnames = [
            "event_center_hsv",
            "distance_weight_profile",
            "accuracy",
            "f1_macro",
            "f1_weighted",
            "cohen_kappa",
            "latency_ms_per_run",
            "latency_ms_per_prediction",
        ]
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results_sorted)

    print(f"Saved tuning report -> {args.output_json.resolve()}")
    print(f"Saved tuning table -> {args.output_csv.resolve()}")
    print(
        "Best candidate: "
        f"center={best.get('event_center_hsv')}, "
        f"weights={best.get('distance_weight_profile')}, "
        f"Acc={best.get('accuracy', 0.0):.4f}, "
        f"F1-macro={best.get('f1_macro', 0.0):.4f}, "
        f"Kappa={best.get('cohen_kappa', 0.0):.4f}"
    )


if __name__ == "__main__":
    main()
