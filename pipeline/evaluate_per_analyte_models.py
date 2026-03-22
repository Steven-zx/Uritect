#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
from collections import defaultdict
from datetime import datetime, timezone
from statistics import mean
from typing import Any

from sklearn.metrics import accuracy_score, cohen_kappa_score, confusion_matrix, f1_score
from sklearn.model_selection import StratifiedKFold
from sklearn.neighbors import KNeighborsClassifier

from semiquant_schema import ANALYTE_ORDER


DEFAULT_TRAIN = pathlib.Path(__file__).parent / "output" / "features_gold_dev.csv"
DEFAULT_TEST = pathlib.Path(__file__).parent / "output" / "features_gold_holdout.csv"
DEFAULT_OUTPUT = pathlib.Path(__file__).parent / "output" / "per_analyte_model_eval.json"
DEFAULT_BASELINE = pathlib.Path(__file__).parent / "output" / "semiquant_gold_holdout_eval.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate per-analyte KNN models on frozen holdout")
    parser.add_argument("--train-features", type=pathlib.Path, default=DEFAULT_TRAIN)
    parser.add_argument("--test-features", type=pathlib.Path, default=DEFAULT_TEST)
    parser.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--baseline-report", type=pathlib.Path, default=DEFAULT_BASELINE)
    parser.add_argument("--max-k", type=int, default=15)
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


def _feature_cols(analyte: str) -> tuple[str, str, str]:
    key = analyte.lower().replace(" ", "_")
    return f"{key}_h", f"{key}_s", f"{key}_v"


def _vector_from_row(row: dict[str, str], analyte: str) -> list[float] | None:
    col_h, col_s, col_v = _feature_cols(analyte)
    raw_h = row.get(col_h, "").strip()
    raw_s = row.get(col_s, "").strip()
    raw_v = row.get(col_v, "").strip()
    if not raw_h or not raw_s or not raw_v:
        return None

    hue = _safe_float(raw_h)
    sat = _safe_float(raw_s)
    val = _safe_float(raw_v)
    if hue is None or sat is None or val is None:
        return None

    hue = _normalize_hue(hue)
    sat = _clip_01(sat)
    val = _clip_01(val)

    radians = math.radians(hue)
    return [math.sin(radians), math.cos(radians), sat, val]


def load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with open(path, newline="", encoding="utf-8") as file:
        return list(csv.DictReader(file))


def split_by_analyte(rows: list[dict[str, str]]) -> dict[str, list[tuple[list[float], str]]]:
    out: dict[str, list[tuple[list[float], str]]] = defaultdict(list)
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        if analyte not in ANALYTE_ORDER or not level:
            continue
        vector = _vector_from_row(row, analyte)
        if vector is None:
            continue
        out[analyte].append((vector, level))
    return out


def choose_k(x_train: list[list[float]], y_train: list[str], max_k: int) -> int:
    classes = sorted(set(y_train))
    if len(classes) < 2:
        return 1

    min_class_count = min(y_train.count(level) for level in classes)
    if min_class_count < 2:
        return 1

    n_samples = len(y_train)
    if n_samples < 3:
        return 1

    max_valid_k = min(max_k, n_samples)
    candidate_ks = [value for value in range(1, max_valid_k + 1, 2)] or [1]

    n_splits = min(3, min_class_count)
    cv = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)

    best_k = 1
    best_score = -1.0

    for k in candidate_ks:
        fold_scores: list[float] = []
        for train_idx, val_idx in cv.split(x_train, y_train):
            x_fold_train = [x_train[i] for i in train_idx]
            y_fold_train = [y_train[i] for i in train_idx]
            x_fold_val = [x_train[i] for i in val_idx]
            y_fold_val = [y_train[i] for i in val_idx]

            model = KNeighborsClassifier(n_neighbors=min(k, len(x_fold_train)), weights="distance")
            model.fit(x_fold_train, y_fold_train)
            y_pred = model.predict(x_fold_val)
            fold_scores.append(float(f1_score(y_fold_val, y_pred, average="macro", zero_division=0)))

        avg_score = float(mean(fold_scores)) if fold_scores else -1.0
        if avg_score > best_score:
            best_score = avg_score
            best_k = k

    return best_k


def evaluate_analyte(
    analyte: str,
    train_items: list[tuple[list[float], str]],
    test_items: list[tuple[list[float], str]],
    max_k: int,
) -> dict[str, Any]:
    if not train_items or not test_items:
        return {"ok": False, "reason": "missing_train_or_test_rows"}

    x_train = [item[0] for item in train_items]
    y_train = [item[1] for item in train_items]
    x_test = [item[0] for item in test_items]
    y_test = [item[1] for item in test_items]

    best_k = choose_k(x_train, y_train, max_k=max_k)
    model = KNeighborsClassifier(n_neighbors=min(best_k, len(x_train)), weights="distance")
    model.fit(x_train, y_train)
    y_pred = list(model.predict(x_test))

    labels = sorted(set(y_test) | set(y_pred))
    if len(labels) > 1:
        kappa = float(cohen_kappa_score(y_test, y_pred, labels=labels))
    else:
        kappa = 1.0

    return {
        "ok": True,
        "k_selected": int(best_k),
        "train_samples": len(y_train),
        "test_samples": len(y_test),
        "accuracy": float(accuracy_score(y_test, y_pred)),
        "f1_macro": float(f1_score(y_test, y_pred, average="macro", zero_division=0)),
        "f1_weighted": float(f1_score(y_test, y_pred, average="weighted", zero_division=0)),
        "cohen_kappa": kappa,
        "support_per_level": {level: int(y_test.count(level)) for level in sorted(set(y_test))},
        "confusion_matrix": {
            "labels": labels,
            "matrix": confusion_matrix(y_test, y_pred, labels=labels).tolist(),
        },
        "overall_true": [f"{analyte}:{level}" for level in y_test],
        "overall_pred": [f"{analyte}:{level}" for level in y_pred],
    }


def main() -> None:
    args = parse_args()

    train_rows = load_rows(args.train_features.resolve())
    test_rows = load_rows(args.test_features.resolve())
    train_by_analyte = split_by_analyte(train_rows)
    test_by_analyte = split_by_analyte(test_rows)

    per_analyte: dict[str, Any] = {}
    overall_true: list[str] = []
    overall_pred: list[str] = []

    for analyte in ANALYTE_ORDER:
        report = evaluate_analyte(
            analyte=analyte,
            train_items=train_by_analyte.get(analyte, []),
            test_items=test_by_analyte.get(analyte, []),
            max_k=args.max_k,
        )
        per_analyte[analyte] = report

        if report.get("ok"):
            overall_true.extend(report.pop("overall_true"))
            overall_pred.extend(report.pop("overall_pred"))

    if overall_true:
        labels = sorted(set(overall_true) | set(overall_pred))
        overall = {
            "samples_evaluated": len(overall_true),
            "accuracy": float(accuracy_score(overall_true, overall_pred)),
            "f1_macro": float(f1_score(overall_true, overall_pred, average="macro", zero_division=0)),
            "f1_weighted": float(f1_score(overall_true, overall_pred, average="weighted", zero_division=0)),
            "cohen_kappa": float(cohen_kappa_score(overall_true, overall_pred, labels=labels)) if len(labels) > 1 else 1.0,
        }
    else:
        overall = {
            "samples_evaluated": 0,
            "accuracy": 0.0,
            "f1_macro": 0.0,
            "f1_weighted": 0.0,
            "cohen_kappa": 0.0,
        }

    baseline_summary: dict[str, Any] | None = None
    baseline_path = args.baseline_report.resolve()
    if baseline_path.exists():
        with open(baseline_path, "r", encoding="utf-8") as file:
            baseline_payload = json.load(file)
        baseline_summary = baseline_payload.get("overall")

    report = {
        "artifacts": {
            "train_features": str(args.train_features.resolve()),
            "test_features": str(args.test_features.resolve()),
            "baseline_report": str(baseline_path),
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "model": "Per-analyte KNN(distance), hue sin/cos + S + V",
        },
        "overall": overall,
        "baseline_overall": baseline_summary,
        "delta_vs_baseline": {
            key: (overall[key] - baseline_summary[key])
            for key in ("accuracy", "f1_macro", "f1_weighted", "cohen_kappa")
        } if baseline_summary else None,
        "per_analyte": per_analyte,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output.resolve(), "w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)

    print(f"Saved report -> {args.output.resolve()}")
    print(
        "Overall: "
        f"Acc={overall['accuracy']:.4f}, "
        f"F1-macro={overall['f1_macro']:.4f}, "
        f"Kappa={overall['cohen_kappa']:.4f}"
    )
    if baseline_summary:
        print(
            "Delta vs baseline: "
            f"Acc={overall['accuracy'] - baseline_summary['accuracy']:+.4f}, "
            f"F1-macro={overall['f1_macro'] - baseline_summary['f1_macro']:+.4f}, "
            f"Kappa={overall['cohen_kappa'] - baseline_summary['cohen_kappa']:+.4f}"
        )


if __name__ == "__main__":
    main()
