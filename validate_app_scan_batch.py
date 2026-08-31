#!/usr/bin/env python3
"""Validate app-facing semiquant scan results against a labeled image batch.

This script uses pipeline.scan_dipstick.run_scan, so it measures the same Python
path used by the app scan server/direct desktop fallback. It is intended for the
upcoming Cabatuan holdout dataset, but it also works with Laua-an for smoke
testing.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from statistics import mean
from typing import Any

sys.path.insert(0, str(pathlib.Path(__file__).parent / "pipeline"))

from scan_dipstick import run_scan
from semiquant_schema import ANALYTE_ORDER, canonicalize_level


DEFAULT_LABELS = pathlib.Path(
    "new_uritect_dataset/uritect_2026-7-30_Laua-an/"
    "uritect_2026-7-30_Laua-an_Labels_cleaned.csv"
)
DEFAULT_IMAGES = pathlib.Path(
    "new_uritect_dataset/uritect_2026-7-30_Laua-an/_extracted/"
    "uritect_2026-7-30_Laua-an_RHU"
)
DEFAULT_REPORT = pathlib.Path("pipeline/output/app_scan_batch_validation.json")
DEFAULT_DETAILS = pathlib.Path("pipeline/output/app_scan_batch_predictions.csv")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate app semiquant scans against labeled images.")
    parser.add_argument("--labels", type=pathlib.Path, default=DEFAULT_LABELS)
    parser.add_argument("--images-root", type=pathlib.Path, default=DEFAULT_IMAGES)
    parser.add_argument("--output-json", type=pathlib.Path, default=DEFAULT_REPORT)
    parser.add_argument("--output-csv", type=pathlib.Path, default=DEFAULT_DETAILS)
    parser.add_argument(
        "--light",
        choices=["Daylight", "Warm", "Cool"],
        default="Daylight",
        help="Preferred image lighting per event.",
    )
    parser.add_argument(
        "--max-events",
        type=int,
        default=0,
        help="Limit scanned events for a quick smoke test. 0 scans all matched events.",
    )
    return parser.parse_args()


def _event_id_from_row(row: dict[str, str]) -> str:
    return (row.get("ID") or row.get("id") or row.get("event_id") or "").strip()


def _label_for_analyte(row: dict[str, str], analyte: str) -> str | None:
    raw = (row.get(analyte) or row.get(analyte.lower()) or "").strip()
    return canonicalize_level(analyte, raw)


def load_expected(labels_path: pathlib.Path) -> list[dict[str, Any]]:
    with labels_path.open(newline="", encoding="utf-8-sig") as file:
        rows = list(csv.DictReader(file))

    expected: list[dict[str, Any]] = []
    for row in rows:
        event_id = _event_id_from_row(row)
        if not event_id:
            continue
        labels = {
            analyte: label
            for analyte in ANALYTE_ORDER
            if (label := _label_for_analyte(row, analyte)) is not None
        }
        if labels:
            expected.append({"event_id": event_id, "labels": labels})
    return expected


def find_image(images_root: pathlib.Path, event_id: str, light: str) -> pathlib.Path | None:
    candidates = [
        images_root / event_id / f"{event_id}-{light}.jpg",
        images_root / event_id / f"{event_id}-{light}.jpeg",
        images_root / event_id / f"{event_id}-{light}.png",
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate

    matches = sorted((images_root / event_id).glob(f"*-{light}.*")) if (images_root / event_id).exists() else []
    if matches:
        return matches[0]

    recursive_matches = sorted(images_root.glob(f"**/{event_id}-{light}.*"))
    return recursive_matches[0] if recursive_matches else None


def predictions_by_analyte(payload: dict[str, Any]) -> dict[str, str]:
    predictions: dict[str, str] = {}
    for item in payload.get("analytes", []):
        if not isinstance(item, dict):
            continue
        analyte = str(item.get("name", "")).strip()
        level = str(item.get("predicted_level") or item.get("display_value") or "").strip()
        if analyte not in ANALYTE_ORDER:
            continue
        canonical = canonicalize_level(analyte, level)
        predictions[analyte] = canonical or level
    return predictions


def main() -> None:
    args = parse_args()
    if not args.labels.exists():
        raise SystemExit(f"Labels CSV not found: {args.labels}")
    if not args.images_root.exists():
        raise SystemExit(f"Images root not found: {args.images_root}")

    expected_rows = load_expected(args.labels)
    if args.max_events > 0:
        expected_rows = expected_rows[: args.max_events]

    per_analyte = defaultdict(lambda: {"correct": 0, "total": 0})
    details: list[dict[str, Any]] = []
    errors: list[dict[str, str]] = []

    for index, item in enumerate(expected_rows, start=1):
        event_id = item["event_id"]
        image_path = find_image(args.images_root, event_id, args.light)
        if image_path is None:
            errors.append({"event_id": event_id, "error": f"No {args.light} image found"})
            continue

        print(f"[{index}/{len(expected_rows)}] Scanning event {event_id}: {image_path.name}")
        try:
            payload = run_scan(image_path)
        except Exception as error:
            errors.append({"event_id": event_id, "error": str(error)})
            continue

        predictions = predictions_by_analyte(payload)
        for analyte, expected_level in item["labels"].items():
            predicted_level = predictions.get(analyte, "Unavailable")
            is_correct = predicted_level == expected_level
            per_analyte[analyte]["total"] += 1
            if is_correct:
                per_analyte[analyte]["correct"] += 1
            details.append(
                {
                    "event_id": event_id,
                    "image_path": str(image_path),
                    "analyte": analyte,
                    "expected": expected_level,
                    "predicted": predicted_level,
                    "correct": int(is_correct),
                    "model_version": payload.get("model_version", ""),
                    "pipeline_version": payload.get("pipeline_version", ""),
                    "feature_space": payload.get("feature_space", ""),
                }
            )

    total_correct = sum(values["correct"] for values in per_analyte.values())
    total = sum(values["total"] for values in per_analyte.values())
    per_analyte_summary = {
        analyte: {
            "correct": values["correct"],
            "total": values["total"],
            "accuracy": values["correct"] / values["total"] if values["total"] else 0.0,
        }
        for analyte, values in sorted(per_analyte.items())
    }
    macro_accuracy = mean([item["accuracy"] for item in per_analyte_summary.values()]) if per_analyte_summary else 0.0
    overall_accuracy = total_correct / total if total else 0.0

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "labels": str(args.labels),
        "images_root": str(args.images_root),
        "light": args.light,
        "events_requested": len(expected_rows),
        "scan_errors": errors,
        "overall": {
            "correct": total_correct,
            "total": total,
            "accuracy": overall_accuracy,
        },
        "macro_accuracy": macro_accuracy,
        "per_analyte": per_analyte_summary,
        "error_counts": dict(Counter(error["error"] for error in errors)),
    }

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    with args.output_json.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open("w", newline="", encoding="utf-8") as file:
        fieldnames = [
            "event_id",
            "image_path",
            "analyte",
            "expected",
            "predicted",
            "correct",
            "model_version",
            "pipeline_version",
            "feature_space",
        ]
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(details)

    print("\nSummary")
    print(f"Overall accuracy: {overall_accuracy:.4f} ({overall_accuracy*100:.2f}%)")
    print(f"Macro accuracy: {macro_accuracy:.4f} ({macro_accuracy*100:.2f}%)")
    print(f"Compared predictions: {total}")
    print(f"Scan errors: {len(errors)}")
    print(f"Report: {args.output_json}")
    print(f"Details: {args.output_csv}")


if __name__ == "__main__":
    main()
