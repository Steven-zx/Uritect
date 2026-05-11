#!/usr/bin/env python3
"""Generate a concise Phase 1 checkpoint summary from frozen pipeline artifacts.

The goal is to turn the current validation, baseline, tuning, and feature-space
outputs into a single report-ready summary for the 50% progress checkpoint.
"""

from __future__ import annotations

import argparse
import json
import pathlib
from datetime import datetime, timezone
from typing import Any


BASE_DIR = pathlib.Path(__file__).parent
OUTPUT_DIR = BASE_DIR / "output"

DEFAULT_OUTPUT_JSON = OUTPUT_DIR / "phase1_checkpoint_summary.json"
DEFAULT_OUTPUT_MD = OUTPUT_DIR / "phase1_checkpoint_summary.md"

DATASET_VALIDATION_JSON = OUTPUT_DIR / "uritect_dataset_validation_report.json"
LOCKED_VALIDATION_JSON = OUTPUT_DIR / "uritect_dataset_locked_v1_validation.json"
LABEL_VALIDATION_JSON = OUTPUT_DIR / "semiquant_label_validation_standalone.json"
FEATURE_SPACE_JSON = OUTPUT_DIR / "feature_space_diagnostics.json"
BASELINE_JSON = OUTPUT_DIR / "semiquant_gold_holdout_eval_restored_prior.json"
SCORECARD_MD = OUTPUT_DIR / "phase1_metric_scorecard.md"
TUNING_JSON = OUTPUT_DIR / "semiquant_tuning_report.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a Phase 1 checkpoint summary")
    parser.add_argument("--output-json", type=pathlib.Path, default=DEFAULT_OUTPUT_JSON)
    parser.add_argument("--output-md", type=pathlib.Path, default=DEFAULT_OUTPUT_MD)
    parser.add_argument("--dataset-validation-json", type=pathlib.Path, default=DATASET_VALIDATION_JSON)
    parser.add_argument("--locked-validation-json", type=pathlib.Path, default=LOCKED_VALIDATION_JSON)
    parser.add_argument("--label-validation-json", type=pathlib.Path, default=LABEL_VALIDATION_JSON)
    parser.add_argument("--feature-space-json", type=pathlib.Path, default=FEATURE_SPACE_JSON)
    parser.add_argument("--baseline-json", type=pathlib.Path, default=BASELINE_JSON)
    parser.add_argument("--scorecard-md", type=pathlib.Path, default=SCORECARD_MD)
    parser.add_argument("--tuning-json", type=pathlib.Path, default=TUNING_JSON)
    return parser.parse_args()


def load_json(path: pathlib.Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def parse_scorecard(path: pathlib.Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}

    metrics: dict[str, dict[str, Any]] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue

        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) != 4:
            continue
        if cells[0] == "Metric" or set(cells[0]) == {"-"}:
            continue

        metric, value, objective, passed = cells
        try:
            value_f = float(value)
            objective_f = float(objective)
        except ValueError:
            continue

        metrics[metric] = {
            "value": value_f,
            "objective": objective_f,
            "pass": passed.upper() == "YES",
        }

    return metrics


def build_hotspots(feature_space: dict[str, Any], limit: int = 8) -> list[dict[str, Any]]:
    hotspots: list[dict[str, Any]] = []
    pairs_by_analyte = feature_space.get("per_analyte_nearest_centroids", {})

    for analyte, pairs in pairs_by_analyte.items():
        if not pairs:
            continue
        top_pair = pairs[0]
        hotspots.append(
            {
                "analyte": analyte,
                "level_a": top_pair.get("level_a", ""),
                "level_b": top_pair.get("level_b", ""),
                "distance": float(top_pair.get("distance", 0.0)),
            }
        )

    hotspots.sort(key=lambda item: item["distance"])
    return hotspots[:limit]


def format_metric_line(metric: str, value: float, objective: float, passed: bool) -> str:
    return f"| {metric} | {value:.6f} | {objective:.6f} | {'YES' if passed else 'NO'} |"


def write_markdown(path: pathlib.Path, report: dict[str, Any]) -> None:
    lines: list[str] = []
    lines.append("# Phase 1 Checkpoint Summary")
    lines.append("")
    lines.append(f"Generated at: {report['generated_at']}")
    lines.append("")
    lines.append("## Scope")
    scope = report["scope"]
    lines.append(f"- Official Phase 1 dataset: {scope['official_ids']} IDs")
    lines.append(f"- Validated unique IDs: {scope['validated_unique_ids']}")
    lines.append(f"- Extra IDs beyond 170: {', '.join(scope['extra_ids_gt_170']) if scope['extra_ids_gt_170'] else 'none'}")
    lines.append(f"- Canonicalization issues: {report['dataset_validation'].get('issue_counts', {}).get('canonicalized', 0)}")
    lines.append(f"- Invalid values: {report['dataset_validation'].get('issue_counts', {}).get('invalid_value', 0)}")
    lines.append("")

    lines.append("## Baseline")
    baseline = report["baseline"]
    lines.append(
        f"- Strict accuracy: {baseline['overall']['accuracy']:.4f}"
        f" | F1-macro: {baseline['overall']['f1_macro']:.4f}"
        f" | Kappa: {baseline['overall']['cohen_kappa']:.4f}"
    )
    lines.append(f"- Coverage: {baseline.get('coverage', 0.0):.4f} on {baseline.get('samples_total', 0)} evaluated samples")
    lines.append("")

    lines.append("## Scorecard")
    lines.append("| Metric | Value | Objective | Pass |")
    lines.append("|---|---:|---:|:---:|")
    for metric_name in (
        "overall_accuracy_strict_multiclass",
        "overall_adjacent_accuracy",
        "overall_coarse_normal_abnormal_accuracy",
        "Nitrite_adjacent_accuracy",
        "Protein_coarse_normal_abnormal_accuracy",
        "pH_coarse_normal_abnormal_accuracy",
        "Ketone_coarse_normal_abnormal_accuracy",
        "Glucose_coarse_normal_abnormal_accuracy",
    ):
        metric = report["scorecard"].get(metric_name)
        if metric is None:
            continue
        lines.append(format_metric_line(metric_name, metric["value"], metric["objective"], metric["pass"]))
    lines.append("")

    lines.append("## Tuning")
    tuning = report["tuning"]
    best = tuning.get("best_candidate", {})
    best_overall = tuning.get("best_overall", {})
    lines.append(
        f"- Best candidate: event_center_hsv={best.get('event_center_hsv', 'n/a')}, "
        f"distance_weight_profile={best.get('distance_weight_profile', 'n/a')}"
    )
    lines.append(
        f"- Best overall: Acc={best_overall.get('accuracy', 0.0):.4f}, "
        f"F1-macro={best_overall.get('f1_macro', 0.0):.4f}, "
        f"Kappa={best_overall.get('cohen_kappa', 0.0):.4f}"
    )
    lines.append(
        f"- F1-macro improvement over baseline: {report['improvement_vs_baseline']['f1_macro']:+.4f}"
    )
    lines.append("")

    lines.append("## Feature-Space Hotspots")
    hotspots = report["feature_space_hotspots"]
    if hotspots:
        lines.append("| Analyte | Level A | Level B | Distance |")
        lines.append("|---|---|---|---:|")
        for hotspot in hotspots:
            lines.append(
                f"| {hotspot['analyte']} | {hotspot['level_a']} | {hotspot['level_b']} | {hotspot['distance']:.6f} |"
            )
    else:
        lines.append("- No feature-space hotspots available.")
    lines.append("")

    lines.append("## Checkpoint Decision")
    if report["checkpoint_ready"]:
        lines.append("- Ready for the 50% progress report as a frozen Phase 1 baseline.")
    else:
        lines.append("- Not yet ready: fix the blocking items before reporting.")
    lines.append("")
    lines.append("## Next Objectives")
    for item in report["next_objectives"]:
        lines.append(f"- {item}")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()

    dataset_validation = load_json(args.dataset_validation_json)
    locked_validation = load_json(args.locked_validation_json)
    label_validation = load_json(args.label_validation_json)
    feature_space = load_json(args.feature_space_json)
    baseline = load_json(args.baseline_json)
    scorecard = parse_scorecard(args.scorecard_md)
    tuning = load_json(args.tuning_json)

    scope = {
        "official_ids": 175,
        "validated_unique_ids": int(dataset_validation.get("unique_ids", locked_validation.get("unique_ids", 0)) or 0),
        "extra_ids_gt_170": dataset_validation.get("extra_ids_gt_170", []),
    }

    improvement_vs_baseline = {
        "accuracy": float(tuning.get("best_overall", {}).get("accuracy", 0.0)) - float(baseline.get("overall", {}).get("accuracy", 0.0)),
        "f1_macro": float(tuning.get("best_overall", {}).get("f1_macro", 0.0)) - float(baseline.get("overall", {}).get("f1_macro", 0.0)),
        "cohen_kappa": float(tuning.get("best_overall", {}).get("cohen_kappa", 0.0)) - float(baseline.get("overall", {}).get("cohen_kappa", 0.0)),
    }

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "scope": scope,
        "dataset_validation": dataset_validation,
        "locked_validation": locked_validation,
        "label_validation": label_validation,
        "feature_space": feature_space,
        "baseline": baseline,
        "scorecard": scorecard,
        "tuning": tuning,
        "feature_space_hotspots": build_hotspots(feature_space),
        "improvement_vs_baseline": improvement_vs_baseline,
        "checkpoint_ready": bool(
            dataset_validation
            and locked_validation
            and label_validation.get("invalid_rows", 1) == 0
            and baseline.get("overall")
            and tuning.get("best_overall")
        ),
        "next_objectives": [
            "Treat more sample collection as Phase 2, not a blocker for the current checkpoint.",
            "Mine the hotspot analytes and closest centroid pairs for targeted hard-case retraining.",
            "Keep the frozen protocol fixed while the report is being prepared.",
        ],
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    with args.output_json.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    write_markdown(args.output_md, report)

    print(f"Saved checkpoint summary JSON -> {args.output_json.resolve()}")
    print(f"Saved checkpoint summary MD   -> {args.output_md.resolve()}")
    print(
        f"Baseline Acc={baseline.get('overall', {}).get('accuracy', 0.0):.4f} | "
        f"Best Acc={tuning.get('best_overall', {}).get('accuracy', 0.0):.4f} | "
        f"Best F1={tuning.get('best_overall', {}).get('f1_macro', 0.0):.4f}"
    )


if __name__ == "__main__":
    main()