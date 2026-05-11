#!/usr/bin/env python3
"""
Create leakage-safe train/val split manifests from RHU sample master.

Outputs:
  1) participant_split_manifest.csv  (one row per participant)
  2) event_split_manifest.csv        (one row per event_id)

Design goals:
  - Never split a participant across train/val.
  - Keep validation size near target ratio.
  - Balance light condition coverage (2700/4000/5500) as much as possible.
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys
from collections import Counter, defaultdict


DEFAULT_DATASET_DIR = pathlib.Path(__file__).parent / "dataset"
DEFAULT_PARTICIPANT_OUT = DEFAULT_DATASET_DIR / "participant_split_manifest.csv"
DEFAULT_EVENT_OUT = DEFAULT_DATASET_DIR / "event_split_manifest.csv"

LIGHT_BUCKETS = ("2700", "4000", "5500")
TRUTHY = {"1", "true", "yes", "y"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create participant-level train/val split manifests")
    parser.add_argument(
        "--sample-master",
        required=True,
        type=pathlib.Path,
        help="Path to rhu_sample_master CSV",
    )
    parser.add_argument(
        "--participant-out",
        type=pathlib.Path,
        default=DEFAULT_PARTICIPANT_OUT,
        help=f"Output participant split CSV (default: {DEFAULT_PARTICIPANT_OUT})",
    )
    parser.add_argument(
        "--event-out",
        type=pathlib.Path,
        default=DEFAULT_EVENT_OUT,
        help=f"Output event split CSV (default: {DEFAULT_EVENT_OUT})",
    )
    parser.add_argument(
        "--val-ratio",
        type=float,
        default=0.25,
        help="Target validation ratio by events (default: 0.25)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for deterministic tie-breaking (default: 42)",
    )
    parser.add_argument(
        "--include-qc-fail",
        action="store_true",
        help="Include rows with qc_pass != 1 (default excludes them)",
    )
    parser.add_argument(
        "--require-medtech-complete",
        action="store_true",
        help="Require medtech_read_complete == 1",
    )
    return parser.parse_args()


def _is_truthy(raw: str) -> bool:
    return str(raw).strip().lower() in TRUTHY


def _norm_light(raw: str) -> str:
    token = str(raw).strip()
    if token.endswith("K") or token.endswith("k"):
        token = token[:-1].strip()
    return token


def _required_columns_present(fieldnames: list[str], required: list[str]) -> None:
    missing = [column for column in required if column not in fieldnames]
    if missing:
        raise ValueError(f"Missing required columns in sample master: {missing}")


def _load_filtered_rows(sample_master_path: pathlib.Path, include_qc_fail: bool, require_medtech_complete: bool) -> list[dict[str, str]]:
    with open(sample_master_path, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    if not rows:
        raise ValueError("Sample master is empty.")

    fieldnames = list(rows[0].keys())
    _required_columns_present(fieldnames, ["participant_id", "event_id", "light_kelvin", "sample_id"])  # noqa: E501

    kept: list[dict[str, str]] = []
    for row in rows:
        participant_id = str(row.get("participant_id", "")).strip()
        event_id = str(row.get("event_id", "")).strip()
        light_kelvin = _norm_light(row.get("light_kelvin", ""))

        if not participant_id or not event_id:
            continue
        if not light_kelvin:
            continue
        if not include_qc_fail and not _is_truthy(row.get("qc_pass", "")):
            continue
        if require_medtech_complete and not _is_truthy(row.get("medtech_read_complete", "")):
            continue

        normalized = dict(row)
        normalized["participant_id"] = participant_id
        normalized["event_id"] = event_id
        normalized["light_kelvin"] = light_kelvin
        kept.append(normalized)

    if not kept:
        raise ValueError("No valid rows after filtering. Check qc_pass/medtech filters and required columns.")

    return kept


def _participant_stats(rows: list[dict[str, str]]) -> dict[str, dict[str, object]]:
    event_ids_by_participant: dict[str, set[str]] = defaultdict(set)
    sample_ids_by_participant: dict[str, set[str]] = defaultdict(set)
    lights_by_participant: dict[str, Counter[str]] = defaultdict(Counter)

    for row in rows:
        participant = row["participant_id"]
        event_ids_by_participant[participant].add(row["event_id"])
        sample_id = str(row.get("sample_id", "")).strip()
        if sample_id:
            sample_ids_by_participant[participant].add(sample_id)
        lights_by_participant[participant][row["light_kelvin"]] += 1

    stats: dict[str, dict[str, object]] = {}
    for participant, events in event_ids_by_participant.items():
        light_counts = dict(lights_by_participant[participant])
        stats[participant] = {
            "event_count": len(events),
            "sample_count": len(sample_ids_by_participant[participant]),
            "lights": light_counts,
        }
    return stats


def _score_if_assigned_to_val(
    participant: str,
    stats: dict[str, dict[str, object]],
    val_counts: Counter[str],
    val_events: int,
    target_events: int,
    target_light_counts: dict[str, int],
) -> float:
    part = stats[participant]
    part_events = int(part["event_count"])
    part_lights: dict[str, int] = part["lights"]  # type: ignore[assignment]

    projected_events = val_events + part_events
    events_gap = abs(projected_events - target_events)

    light_gap = 0.0
    for light in LIGHT_BUCKETS:
        projected_light = val_counts[light] + int(part_lights.get(light, 0))
        light_gap += abs(projected_light - target_light_counts.get(light, 0))

    # Event count closeness is more important than perfect per-light matching.
    return (events_gap * 3.0) + light_gap


def _choose_participant_splits(
    rows: list[dict[str, str]],
    val_ratio: float,
    seed: int,
) -> dict[str, str]:
    stats = _participant_stats(rows)
    participants = list(stats.keys())
    if len(participants) < 2:
        raise ValueError("Need at least 2 participants to create train/val split.")

    total_events = sum(int(stats[p]["event_count"]) for p in participants)
    target_val_events = max(1, int(round(total_events * val_ratio)))
    total_light_counts = Counter(_norm_light(row["light_kelvin"]) for row in rows)
    target_light_counts = {
        light: int(round(total_light_counts.get(light, 0) * val_ratio)) for light in LIGHT_BUCKETS
    }

    rng = random.Random(seed)
    shuffled = list(participants)
    rng.shuffle(shuffled)
    shuffled.sort(key=lambda participant: int(stats[participant]["event_count"]), reverse=True)

    split_map = {participant: "train" for participant in participants}
    val_counts: Counter[str] = Counter()
    val_events = 0
    val_participants = 0

    for participant in shuffled:
        event_count = int(stats[participant]["event_count"])

        # Guarantee at least one participant remains in train.
        if val_participants >= len(participants) - 1:
            continue

        score_take = _score_if_assigned_to_val(
            participant,
            stats,
            val_counts,
            val_events,
            target_val_events,
            target_light_counts,
        )
        score_skip = abs(val_events - target_val_events) * 3.0 + sum(
            abs(val_counts[light] - target_light_counts.get(light, 0)) for light in LIGHT_BUCKETS
        )

        should_take = score_take < score_skip
        if not should_take and val_events < target_val_events:
            # If we're still below target events, allow assignment when not too costly.
            should_take = score_take <= (score_skip + max(1, event_count))

        if should_take:
            split_map[participant] = "val"
            val_events += event_count
            val_participants += 1
            for light, count in stats[participant]["lights"].items():  # type: ignore[union-attr]
                val_counts[light] += int(count)

    if val_participants == 0:
        # Fallback to guarantee at least one validation participant.
        biggest = max(participants, key=lambda participant: int(stats[participant]["event_count"]))
        split_map[biggest] = "val"

    if all(split == "val" for split in split_map.values()):
        # Guardrail: keep at least one participant in train.
        smallest_val = min(
            (participant for participant in participants if split_map[participant] == "val"),
            key=lambda participant: int(stats[participant]["event_count"]),
        )
        split_map[smallest_val] = "train"

    return split_map


def _write_participant_manifest(
    output_path: pathlib.Path,
    stats: dict[str, dict[str, object]],
    split_map: dict[str, str],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "participant_id",
        "split",
        "event_count",
        "sample_count",
        "light_2700_count",
        "light_4000_count",
        "light_5500_count",
    ]

    with open(output_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        for participant in sorted(stats):
            lights: dict[str, int] = stats[participant]["lights"]  # type: ignore[assignment]
            writer.writerow(
                {
                    "participant_id": participant,
                    "split": split_map[participant],
                    "event_count": int(stats[participant]["event_count"]),
                    "sample_count": int(stats[participant]["sample_count"]),
                    "light_2700_count": int(lights.get("2700", 0)),
                    "light_4000_count": int(lights.get("4000", 0)),
                    "light_5500_count": int(lights.get("5500", 0)),
                }
            )


def _write_event_manifest(output_path: pathlib.Path, rows: list[dict[str, str]], split_map: dict[str, str]) -> int:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["event_id", "participant_id", "sample_id", "light_kelvin", "split"]

    dedup: dict[str, dict[str, str]] = {}
    for row in rows:
        event_id = row["event_id"]
        participant = row["participant_id"]
        dedup[event_id] = {
            "event_id": event_id,
            "participant_id": participant,
            "sample_id": str(row.get("sample_id", "")).strip(),
            "light_kelvin": row["light_kelvin"],
            "split": split_map[participant],
        }

    with open(output_path, "w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        for event_id in sorted(dedup):
            writer.writerow(dedup[event_id])

    return len(dedup)


def _print_summary(rows: list[dict[str, str]], split_map: dict[str, str]) -> None:
    stats = _participant_stats(rows)
    split_event_counts = Counter()
    split_participant_counts = Counter(split_map.values())
    split_light_counts: dict[str, Counter[str]] = {
        "train": Counter(),
        "val": Counter(),
    }

    for participant, split in split_map.items():
        split_event_counts[split] += int(stats[participant]["event_count"])
        lights: dict[str, int] = stats[participant]["lights"]  # type: ignore[assignment]
        for light, count in lights.items():
            split_light_counts[split][light] += int(count)

    print("Split summary")
    print(f"  Participants - train: {split_participant_counts.get('train', 0)}, val: {split_participant_counts.get('val', 0)}")
    print(f"  Events       - train: {split_event_counts.get('train', 0)}, val: {split_event_counts.get('val', 0)}")
    for split_name in ("train", "val"):
        print(
            "  "
            f"{split_name} lights - "
            f"2700: {split_light_counts[split_name].get('2700', 0)}, "
            f"4000: {split_light_counts[split_name].get('4000', 0)}, "
            f"5500: {split_light_counts[split_name].get('5500', 0)}"
        )


def main() -> None:
    args = parse_args()

    if not (0.05 <= args.val_ratio <= 0.5):
        print("--val-ratio must be between 0.05 and 0.5", file=sys.stderr)
        sys.exit(2)

    sample_master_path = args.sample_master.resolve()
    if not sample_master_path.exists():
        print(f"Sample master CSV not found: {sample_master_path}", file=sys.stderr)
        sys.exit(2)

    try:
        rows = _load_filtered_rows(
            sample_master_path,
            include_qc_fail=args.include_qc_fail,
            require_medtech_complete=args.require_medtech_complete,
        )
        stats = _participant_stats(rows)
        split_map = _choose_participant_splits(rows, args.val_ratio, args.seed)
        participant_out = args.participant_out.resolve()
        event_out = args.event_out.resolve()
        _write_participant_manifest(participant_out, stats, split_map)
        event_count = _write_event_manifest(event_out, rows, split_map)
    except ValueError as error:
        print(f"Failed to build split manifests: {error}", file=sys.stderr)
        sys.exit(1)

    _print_summary(rows, split_map)
    print(f"Participant manifest: {participant_out}")
    print(f"Event manifest: {event_out} ({event_count} events)")


if __name__ == "__main__":
    main()
