#!/usr/bin/env python3
"""Summarize the final 10-medtech URITECT app evaluation data."""

from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
from collections import Counter
from datetime import datetime, timezone
from statistics import mean, stdev
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "output" / "forms" / "URITECT_ISO25010_MedTech_App_Evaluation_Data_Template.csv"
DEFAULT_JSON = ROOT / "output" / "evaluation" / "URITECT_ISO25010_MedTech_App_Evaluation_Results.json"
DEFAULT_MD = ROOT / "output" / "evaluation" / "URITECT_ISO25010_MedTech_App_Evaluation_Results.md"

TASKS = [f"T{i}" for i in range(1, 11)]
SECTIONS = {
    "Functional suitability": [f"F{i}" for i in range(1, 6)],
    "Interaction capability and usability": [f"U{i}" for i in range(1, 7)],
    "Reliability and safety behavior": [f"R{i}" for i in range(1, 6)],
    "Performance efficiency": [f"P{i}" for i in range(1, 4)],
    "Compatibility, offline operation, and privacy controls": [f"C{i}" for i in range(1, 6)],
}
RATINGS = [item for items in SECTIONS.values() for item in items]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=pathlib.Path, default=DEFAULT_INPUT)
    parser.add_argument("--json-output", type=pathlib.Path, default=DEFAULT_JSON)
    parser.add_argument("--markdown-output", type=pathlib.Path, default=DEFAULT_MD)
    return parser.parse_args()


def numeric(values: list[str], minimum: float, maximum: float) -> list[float]:
    parsed = []
    for value in values:
        value = value.strip()
        if not value or value.lower() in {"n/o", "na", "n/a", "not observed"}:
            continue
        number = float(value)
        if not minimum <= number <= maximum:
            raise ValueError(f"Value {number} is outside {minimum}..{maximum}")
        parsed.append(number)
    return parsed


def summary(values: list[float]) -> dict[str, Any]:
    return {
        "n": len(values),
        "mean": mean(values) if values else None,
        "standard_deviation": stdev(values) if len(values) > 1 else (0.0 if values else None),
        "minimum": min(values) if values else None,
        "maximum": max(values) if values else None,
    }


def fmt(value: float | None, digits: int = 2) -> str:
    return "N/A" if value is None or math.isnan(value) else f"{value:.{digits}f}"


def main() -> None:
    args = parse_args()
    with args.input.open(newline="", encoding="utf-8-sig") as stream:
        rows = list(csv.DictReader(stream))
    completed = [row for row in rows if any(row.get(item, "").strip() for item in TASKS + RATINGS)]
    if not completed:
        raise SystemExit("No completed evaluator rows were found. Fill the template before analysis.")

    item_results = {
        item: summary(numeric([row.get(item, "") for row in completed], 1, 4))
        for item in RATINGS
    }
    section_results = {}
    for section, items in SECTIONS.items():
        section_values = numeric(
            [row.get(item, "") for row in completed for item in items], 1, 4
        )
        section_results[section] = summary(section_values)

    task_results = {}
    for task in TASKS:
        values = [row.get(task, "").strip().lower() for row in completed]
        passes = sum(value == "pass" for value in values)
        failures = sum(value == "fail" for value in values)
        attempted = passes + failures
        task_results[task] = {
            "passes": passes,
            "failures": failures,
            "not_tested_or_blank": len(values) - attempted,
            "attempted": attempted,
            "success_rate": passes / attempted if attempted else None,
        }

    times = numeric([row.get("scan_seconds", "") for row in completed], 0, 3600)
    decisions = Counter(
        row.get("overall_decision", "").strip()
        for row in completed
        if row.get("overall_decision", "").strip()
    )
    result = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "instrument": "URITECT_ISO25010_MedTech_App_Evaluation_v1.0",
        "completed_evaluators": len(completed),
        "interpretation_boundary": "Descriptive ISO/IEC 25010-guided user evaluation; not ISO certification or clinical model validation.",
        "rating_items": item_results,
        "quality_sections": section_results,
        "task_results": task_results,
        "scan_time_seconds": summary(times),
        "overall_decisions": dict(decisions),
    }
    args.json_output.parent.mkdir(parents=True, exist_ok=True)
    args.json_output.write_text(json.dumps(result, indent=2), encoding="utf-8")

    lines = [
        "# URITECT Final App Evaluation Results",
        "",
        f"Completed evaluators: **{len(completed)}**",
        "",
        "> ISO/IEC 25010-guided user evaluation; not ISO certification or clinical model validation.",
        "",
        "## Quality Sections",
        "",
        "| Section | Valid ratings | Mean | SD |",
        "| --- | ---: | ---: | ---: |",
    ]
    for section, values in section_results.items():
        lines.append(
            f"| {section} | {values['n']} | {fmt(values['mean'])} | {fmt(values['standard_deviation'])} |"
        )
    lines.extend(["", "## Task Success", "", "| Task | Pass | Fail | Not tested/blank | Success rate |", "| --- | ---: | ---: | ---: | ---: |"])
    for task, values in task_results.items():
        rate = "N/A" if values["success_rate"] is None else f"{values['success_rate'] * 100:.1f}%"
        lines.append(
            f"| {task} | {values['passes']} | {values['failures']} | {values['not_tested_or_blank']} | {rate} |"
        )
    lines.extend([
        "",
        "## Timing and Decisions",
        "",
        f"Mean scan time: **{fmt(result['scan_time_seconds']['mean'])} seconds** (n={result['scan_time_seconds']['n']}).",
        "",
        "Overall decisions: " + (", ".join(f"{key}: {value}" for key, value in decisions.items()) or "No decisions entered."),
        "",
        "Full item-level statistics are stored in the JSON output.",
    ])
    args.markdown_output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Completed evaluators: {len(completed)}")
    print(f"JSON: {args.json_output}")
    print(f"Markdown: {args.markdown_output}")


if __name__ == "__main__":
    main()
