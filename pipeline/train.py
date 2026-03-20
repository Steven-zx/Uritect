#!/usr/bin/env python3
"""
Uritect training pipeline — training stage.

Reads:
  pipeline/dataset/features.csv (produced by ingest.py)

Outputs:
  pipeline/output/binary_knn_model.pkl
  pipeline/output/binary_knn_metrics.json
  pipeline/output/knn_reference_map.json

Pipeline alignment:
- Brute-force k-NN (k=5, Euclidean, distance-weighted)
- SMOTE augmentation toward a balanced 4,500-sample training library
- Bayesian fusion with 8-symptom binary vector
- Risk output: Low / Moderate / High
"""

from __future__ import annotations

import argparse
import csv
import importlib
import json
import pathlib
import pickle
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from statistics import median
from typing import Any

try:
    import numpy as np
    from sklearn.metrics import accuracy_score, confusion_matrix, f1_score
    from sklearn.model_selection import train_test_split
    from sklearn.neighbors import KNeighborsClassifier
except ImportError:
    print("Missing dependencies. Run: pip install -r requirements.txt")
    sys.exit(1)

try:
    from bayesian_fusion import BayesianFusionEngine
    from vision_pipeline import ANALYTE_ORDER, all_feature_columns, feature_columns_for_analyte
except ImportError as error:
    print(f"Failed to import pipeline modules: {error}")
    print("Run from repository root: python pipeline/train.py")
    sys.exit(1)

try:
    from check_training_readiness import evaluate_binary
except Exception:
    evaluate_binary = None


def _load_smote() -> Any:
    try:
        module = importlib.import_module("imblearn.over_sampling")
    except ModuleNotFoundError:
        return None
    return getattr(module, "SMOTE", None)


SMOTE = _load_smote()

FEATURES_PATH = pathlib.Path(__file__).parent / "dataset" / "features.csv"
OUTPUT_DIR = pathlib.Path(__file__).parent / "output"

BINARY_LABEL_ALIASES = {
    "normal": "Normal",
    "negative": "Normal",
    "class1": "Normal",
    "class_1": "Normal",
    "class 1": "Normal",
    "1": "Normal",
    "abnormal": "Abnormal",
    "positive": "Abnormal",
    "class2": "Abnormal",
    "class_2": "Abnormal",
    "class 2": "Abnormal",
    "2": "Abnormal",
}

CLASS_TO_ID = {"Normal": 1, "Abnormal": 2}
ID_TO_CLASS = {1: "Normal", 2: "Abnormal"}
DEFAULT_FEATURE_COLUMNS = all_feature_columns(ANALYTE_ORDER)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train Uritect k-NN + Bayesian artifacts from features.csv",
    )
    parser.add_argument(
        "--enforce-readiness",
        action="store_true",
        help="Fail early if binary class balance/readiness requirements are not met.",
    )
    parser.add_argument(
        "--min-total",
        type=int,
        default=12,
        help="Minimum binary sample count for readiness gate (default: 12).",
    )
    parser.add_argument(
        "--min-class",
        type=int,
        default=6,
        help="Minimum samples per binary class for readiness gate (default: 6).",
    )
    parser.add_argument(
        "--require-all-lights",
        action="store_true",
        help="Require 2700K/4000K/5500K presence in each class for readiness gate.",
    )
    parser.add_argument(
        "--require-split-coverage",
        action="store_true",
        help="Require both classes in train and val/test splits for readiness gate.",
    )
    parser.add_argument(
        "--target-augmented-size",
        type=int,
        default=4500,
        help="Target total size after SMOTE for binary training split (default: 4500).",
    )
    return parser.parse_args()


def load_features() -> list[dict[str, str]]:
    if not FEATURES_PATH.exists():
        print(f"features.csv not found at:\n  {FEATURES_PATH}")
        print("Run ingest.py first.")
        sys.exit(1)

    with open(FEATURES_PATH, newline="", encoding="utf-8") as file:
        rows = list(csv.DictReader(file))

    if not rows:
        print("features.csv is empty. Run ingest.py with labelled ZIPs first.")
        sys.exit(1)

    return rows


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _canonical_binary_label(raw: str) -> str | None:
    key = raw.strip().lower()
    if not key:
        return None
    return BINARY_LABEL_ALIASES.get(key)


def _detect_row_mode(row: dict[str, str]) -> str:
    explicit_mode = row.get("label_mode", "").strip().lower()
    if explicit_mode in {"binary", "semiquant"}:
        return explicit_mode

    for candidate in (
        row.get("class_label", ""),
        row.get("level", ""),
        row.get("label_canonical", ""),
        row.get("label_raw", ""),
    ):
        if _canonical_binary_label(candidate) is not None:
            return "binary"

    analyte = row.get("analyte", "").strip()
    level = row.get("level", "").strip()
    if analyte and level:
        return "semiquant"

    return "unknown"


def split_rows_by_mode(rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    binary_rows: list[dict[str, str]] = []
    semiquant_rows: list[dict[str, str]] = []
    unknown_rows: list[dict[str, str]] = []

    for row in rows:
        mode = _detect_row_mode(row)
        if mode == "binary":
            binary_rows.append(row)
        elif mode == "semiquant":
            semiquant_rows.append(row)
        else:
            unknown_rows.append(row)

    return binary_rows, semiquant_rows, unknown_rows


def _binary_label_from_row(row: dict[str, str]) -> str | None:
    for candidate in (
        row.get("class_label", ""),
        row.get("level", ""),
        row.get("label_canonical", ""),
        row.get("label_raw", ""),
    ):
        label = _canonical_binary_label(candidate)
        if label is not None:
            return label
    return None


def _binary_label_id(row: dict[str, str]) -> int | None:
    class_id_raw = row.get("class_id", "").strip()
    if class_id_raw in {"1", "2"}:
        return int(class_id_raw)

    label = _binary_label_from_row(row)
    if label is None:
        return None
    return CLASS_TO_ID[label]


def _has_both_classes(labels: np.ndarray) -> bool:
    return set(labels.tolist()) == {1, 2}


def _row_feature_vector(row: dict[str, str], feature_columns: list[str]) -> list[float] | None:
    vector: list[float] = []
    for column in feature_columns:
        raw = row.get(column, "").strip()
        if raw == "":
            return None
        vector.append(_safe_float(raw))
    return vector


def _extract_symptom_vector(row: dict[str, str]) -> list[int]:
    vector: list[int] = []
    for index in range(1, 9):
        key = f"symptom_{index}"
        value = row.get(key, "").strip()
        if value in {"1", "true", "True", "yes", "Yes"}:
            vector.append(1)
        else:
            vector.append(0)
    return vector


def train_binary_knn(
    rows: list[dict[str, str]],
    feature_columns: list[str],
    target_augmented_size: int,
) -> dict[str, Any] | None:
    vectors: list[list[float]] = []
    labels: list[int] = []
    splits: list[str] = []
    symptoms: list[list[int]] = []

    for row in rows:
        label_id = _binary_label_id(row)
        if label_id is None:
            continue

        vector = _row_feature_vector(row, feature_columns)
        if vector is None:
            continue

        vectors.append(vector)
        labels.append(label_id)
        splits.append(row.get("split", "").strip().lower())
        symptoms.append(_extract_symptom_vector(row))

    if len(vectors) < 4:
        print("[WARN] Not enough binary samples to train k-NN (need at least 4).")
        return None

    X = np.array(vectors, dtype=np.float32)
    y = np.array(labels, dtype=np.int32)
    symptom_matrix = np.array(symptoms, dtype=np.int32)

    if not _has_both_classes(y):
        print("[WARN] Binary dataset must include both Normal (1) and Abnormal (2).")
        return None

    explicit_train_idx = [i for i, split in enumerate(splits) if split == "train"]
    explicit_eval_idx = [i for i, split in enumerate(splits) if split in {"val", "test"}]

    use_explicit_split = (
        len(explicit_train_idx) >= 2
        and len(explicit_eval_idx) >= 2
        and _has_both_classes(y[explicit_train_idx])
        and _has_both_classes(y[explicit_eval_idx])
    )

    if use_explicit_split:
        X_train = X[explicit_train_idx]
        y_train = y[explicit_train_idx]
        symptom_train = symptom_matrix[explicit_train_idx]

        X_eval = X[explicit_eval_idx]
        y_eval = y[explicit_eval_idx]
        symptom_eval = symptom_matrix[explicit_eval_idx]
        split_strategy = "manifest_split(train vs val/test)"
    else:
        test_size = 0.25 if len(y) >= 8 else 0.5
        X_train, X_eval, y_train, y_eval, symptom_train, symptom_eval = train_test_split(
            X,
            y,
            symptom_matrix,
            test_size=test_size,
            random_state=42,
            stratify=y,
        )
        split_strategy = "stratified_random_split"

    X_train_fit = X_train
    y_train_fit = y_train
    smote_applied = False
    smote_note = "not requested"

    if SMOTE is None:
        smote_note = "imbalanced-learn not installed; skipped"
    else:
        class_counts = Counter(y_train.tolist())
        min_class_count = min(class_counts.values())
        if min_class_count >= 2:
            smote_k = min(5, min_class_count - 1)

            target_per_class = max(target_augmented_size // 2, max(class_counts.values()))
            sampling_strategy = {
                class_id: max(target_per_class, class_counts[class_id])
                for class_id in class_counts
            }

            smote = SMOTE(
                random_state=42,
                k_neighbors=smote_k,
                sampling_strategy=sampling_strategy,
            )
            X_train_fit, y_train_fit = smote.fit_resample(X_train, y_train)
            smote_applied = True
            smote_note = f"applied (k_neighbors={smote_k}, strategy={sampling_strategy})"
        else:
            smote_note = "skipped (not enough minority samples in train split)"

    if len(X_train_fit) < 5:
        print("[WARN] Training set too small after preprocessing for k=5.")
        return None

    model = KNeighborsClassifier(
        n_neighbors=5,
        algorithm="brute",
        metric="euclidean",
        weights="distance",
    )
    model.fit(X_train_fit, y_train_fit)

    y_pred = model.predict(X_eval)
    probabilities = model.predict_proba(X_eval)

    abnormal_index = list(model.classes_).index(2)
    knn_prob_abnormal = probabilities[:, abnormal_index]

    tn, fp, fn, tp = confusion_matrix(y_eval, y_pred, labels=[1, 2]).ravel()

    sensitivity = float(tp / (tp + fn)) if (tp + fn) > 0 else 0.0
    specificity = float(tn / (tn + fp)) if (tn + fp) > 0 else 0.0
    accuracy = float(accuracy_score(y_eval, y_pred))
    f1 = float(f1_score(y_eval, y_pred, pos_label=2, zero_division=0))

    fusion_engine = BayesianFusionEngine()
    posteriors: list[float] = []
    risks: list[str] = []
    for index, probability_abnormal in enumerate(knn_prob_abnormal):
        posterior = fusion_engine.posterior_probability(
            knn_prob_abnormal=float(probability_abnormal),
            symptom_vector=symptom_eval[index].tolist(),
        )
        posteriors.append(posterior)
        risks.append(fusion_engine.risk_bucket(posterior))

    posterior_pred = np.where(np.array(posteriors) >= 0.5, 2, 1)
    posterior_accuracy = float(accuracy_score(y_eval, posterior_pred))
    risk_counts = Counter(risks)

    return {
        "model": model,
        "metrics": {
            "accuracy": accuracy,
            "f1_score": f1,
            "sensitivity": sensitivity,
            "specificity": specificity,
            "confusion_matrix": {
                "tn": int(tn),
                "fp": int(fp),
                "fn": int(fn),
                "tp": int(tp),
            },
            "posterior_accuracy": posterior_accuracy,
            "posterior_probability_summary": {
                "min": float(np.min(posteriors)),
                "max": float(np.max(posteriors)),
                "mean": float(np.mean(posteriors)),
            },
            "risk_counts": {
                "Low": int(risk_counts.get("Low", 0)),
                "Moderate": int(risk_counts.get("Moderate", 0)),
                "High": int(risk_counts.get("High", 0)),
            },
            "risk_thresholds": {
                "Low": "P < 0.35",
                "Moderate": "0.35 <= P <= 0.70",
                "High": "P > 0.70",
            },
        },
        "counts": {
            "raw_binary_samples": int(len(y)),
            "train_samples_before_smote": int(len(y_train)),
            "train_samples_after_smote": int(len(y_train_fit)),
            "eval_samples": int(len(y_eval)),
            "class_distribution_raw": {
                "Normal(1)": int(np.sum(y == 1)),
                "Abnormal(2)": int(np.sum(y == 2)),
            },
            "class_distribution_train_before_smote": {
                "Normal(1)": int(np.sum(y_train == 1)),
                "Abnormal(2)": int(np.sum(y_train == 2)),
            },
        },
        "config": {
            "n_neighbors": 5,
            "algorithm": "brute",
            "weights": "distance",
            "metric": "euclidean",
            "feature_columns": feature_columns,
            "split_strategy": split_strategy,
            "smote": {
                "applied": smote_applied,
                "note": smote_note,
                "target_augmented_size": target_augmented_size,
            },
            "class_encoding": {
                "Normal": 1,
                "Abnormal": 2,
            },
        },
    }


def save_binary_artifacts(result: dict[str, Any], feature_columns: list[str]) -> tuple[pathlib.Path, pathlib.Path]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    model_path = OUTPUT_DIR / "binary_knn_model.pkl"
    metrics_path = OUTPUT_DIR / "binary_knn_metrics.json"

    model_payload = {
        "version": "binary_knn_v2",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "class_map": {"1": "Normal", "2": "Abnormal"},
        "feature_columns": feature_columns,
        "model": result["model"],
    }

    with open(model_path, "wb") as file:
        pickle.dump(model_payload, file)

    metrics_payload = {
        "version": "binary_knn_v2",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "metrics": result["metrics"],
        "counts": result["counts"],
        "config": result["config"],
    }

    with open(metrics_path, "w", encoding="utf-8") as file:
        json.dump(metrics_payload, file, indent=2)

    return model_path, metrics_path


def _clip_01(value: float) -> float:
    return min(max(value, 0.0), 1.0)


def _normalize_hue(hue: float) -> float:
    normalized = hue % 360.0
    if normalized < 0:
        normalized += 360.0
    return normalized


def _median_hsv(samples: list[tuple[float, float, float]]) -> tuple[float, float, float]:
    h = float(median(sample[0] for sample in samples))
    s = float(median(sample[1] for sample in samples))
    v = float(median(sample[2] for sample in samples))
    return round(_normalize_hue(h), 6), round(_clip_01(s), 6), round(_clip_01(v), 6)


def build_binary_reference_map(rows: list[dict[str, str]]) -> dict[str, list[dict[str, Any]]]:
    groups: dict[tuple[str, str], list[tuple[float, float, float]]] = defaultdict(list)

    for row in rows:
        label = _binary_label_from_row(row)
        if label is None:
            continue

        for analyte_name in ANALYTE_ORDER:
            column_h, column_s, column_v = feature_columns_for_analyte(analyte_name)
            raw_h = row.get(column_h, "").strip()
            raw_s = row.get(column_s, "").strip()
            raw_v = row.get(column_v, "").strip()
            if not raw_h or not raw_s or not raw_v:
                continue

            h = _safe_float(raw_h)
            s = _safe_float(raw_s)
            v = _safe_float(raw_v)
            groups[(analyte_name, label)].append((h, s, v))

    output: dict[str, list[dict[str, Any]]] = {}
    for analyte_name in ANALYTE_ORDER:
        levels: list[dict[str, Any]] = []
        for label in ("Normal", "Abnormal"):
            samples = groups.get((analyte_name, label), [])
            if not samples:
                continue

            h, s, v = _median_hsv(samples)
            levels.append(
                {
                    "level": label,
                    "h": h,
                    "s": s,
                    "v": v,
                    "weight": 1.0,
                    "sample_count": len(samples),
                }
            )

        if levels:
            output[analyte_name] = levels

    return output


def build_semiquant_reference_map(rows: list[dict[str, str]]) -> dict[str, list[dict[str, Any]]]:
    groups: dict[tuple[str, str], list[tuple[float, float, float]]] = defaultdict(list)

    for row in rows:
        analyte_name = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        if analyte_name not in ANALYTE_ORDER or not level:
            continue

        column_h, column_s, column_v = feature_columns_for_analyte(analyte_name)
        raw_h = row.get(column_h, "").strip()
        raw_s = row.get(column_s, "").strip()
        raw_v = row.get(column_v, "").strip()
        if not raw_h or not raw_s or not raw_v:
            continue

        h = _safe_float(raw_h)
        s = _safe_float(raw_s)
        v = _safe_float(raw_v)
        groups[(analyte_name, level)].append((h, s, v))

    output: dict[str, list[dict[str, Any]]] = {}
    for analyte_name in ANALYTE_ORDER:
        level_entries: list[dict[str, Any]] = []
        level_names = sorted(level for (analyte, level) in groups if analyte == analyte_name)

        for level in level_names:
            samples = groups[(analyte_name, level)]
            if not samples:
                continue

            h, s, v = _median_hsv(samples)
            level_entries.append(
                {
                    "level": level,
                    "h": h,
                    "s": s,
                    "v": v,
                    "weight": 1.0,
                    "sample_count": len(samples),
                }
            )

        if level_entries:
            output[analyte_name] = level_entries

    return output


def merge_reference_maps(
    semiquant_map: dict[str, list[dict[str, Any]]],
    binary_map: dict[str, list[dict[str, Any]]],
) -> dict[str, list[dict[str, Any]]]:
    merged: dict[str, list[dict[str, Any]]] = {}
    for analyte_name in ANALYTE_ORDER:
        if analyte_name in semiquant_map and semiquant_map[analyte_name]:
            merged[analyte_name] = semiquant_map[analyte_name]
        elif analyte_name in binary_map and binary_map[analyte_name]:
            merged[analyte_name] = binary_map[analyte_name]
    return merged


def main() -> None:
    args = parse_args()

    rows = load_features()
    print(f"Loaded {len(rows)} rows from:\n  {FEATURES_PATH}\n")

    binary_rows, semiquant_rows, unknown_rows = split_rows_by_mode(rows)
    print("Label mode breakdown:")
    print(f"  binary:    {len(binary_rows)}")
    print(f"  semiquant: {len(semiquant_rows)}")
    print(f"  unknown:   {len(unknown_rows)}")

    if args.enforce_readiness and binary_rows:
        if evaluate_binary is None:
            print("\n[PRECHECK FAILED] Could not import readiness checker.")
            print("Run: python pipeline/check_training_readiness.py")
            sys.exit(1)

        readiness = evaluate_binary(
            rows=rows,
            min_total=args.min_total,
            min_class=args.min_class,
            require_all_lights=args.require_all_lights,
            require_split_coverage=args.require_split_coverage,
        )
        if not readiness.ready:
            print("\n[PRECHECK FAILED] Dataset is not ready for binary training.")
            for blocker in readiness.blockers:
                print(f"  - {blocker}")
            print("\nRun: python pipeline/check_training_readiness.py")
            print("Tip: add more Normal/Abnormal bursts, then rerun ingest.py and train.py.")
            sys.exit(1)

        print("\n[PRECHECK OK] Dataset passed readiness gate.")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    binary_train_result = None
    if binary_rows:
        print("\n[1/3] Training binary k-NN (k=5, brute-force) + SMOTE ...")
        binary_train_result = train_binary_knn(
            rows=binary_rows,
            feature_columns=DEFAULT_FEATURE_COLUMNS,
            target_augmented_size=args.target_augmented_size,
        )
        if binary_train_result is None:
            print("  [WARN] Binary training skipped due to insufficient/invalid data.")
            print("  Run: python pipeline/check_training_readiness.py")
        else:
            model_path, metrics_path = save_binary_artifacts(
                result=binary_train_result,
                feature_columns=DEFAULT_FEATURE_COLUMNS,
            )
            print(f"  Saved binary model   -> {model_path}")
            print(f"  Saved binary metrics -> {metrics_path}")
            metrics = binary_train_result["metrics"]
            print(
                "  Eval metrics: "
                f"Acc={metrics['accuracy']:.4f}, "
                f"F1={metrics['f1_score']:.4f}, "
                f"Sens={metrics['sensitivity']:.4f}, "
                f"Spec={metrics['specificity']:.4f}"
            )

    print("\n[2/3] Building app reference map ...")
    semiquant_map = build_semiquant_reference_map(semiquant_rows)
    binary_map = build_binary_reference_map(binary_rows)
    merged_map = merge_reference_maps(semiquant_map, binary_map)

    if not merged_map:
        print("No usable rows to build knn_reference_map.json.")
        sys.exit(1)

    payload = {
        "version": "trained_v4_hsv",
        "source": "uritect_training_pipeline",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_samples": len(rows),
        "reference_color_space": "hsv",
        "label_mode_counts": {
            "binary": len(binary_rows),
            "semiquant": len(semiquant_rows),
            "unknown": len(unknown_rows),
        },
        "reference_strategy": "semiquant_preferred_with_binary_fallback",
        "pipeline_sequence": [
            "geometric_rectification",
            "awb_marker_center_10x10",
            "grid_slicing_px_per_mm",
            "burst_temporal_median",
            "mean_hsv_features",
            "smote_augmentation",
            "knn_bruteforce_k5",
            "bayesian_fusion_and_risk",
        ],
        "analytes": merged_map,
    }

    map_path = OUTPUT_DIR / "knn_reference_map.json"
    with open(map_path, "w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)

    print(f"  Saved app map -> {map_path}")

    print("\n[3/3] Reference map summary:")
    total_referenced = 0
    for analyte_name in ANALYTE_ORDER:
        levels = merged_map.get(analyte_name)
        if not levels:
            print(f"  {analyte_name:20s} (no data)")
            continue

        sample_count = sum(int(level.get("sample_count", 0)) for level in levels)
        total_referenced += sample_count
        level_labels = ", ".join(str(level["level"]) for level in levels)
        print(
            f"  {analyte_name:20s} "
            f"{len(levels):2d} levels "
            f"{sample_count:4d} samples "
            f"[{level_labels}]"
        )

    print(f"\n  Total referenced samples: {total_referenced}")
    print("\nDone.")


if __name__ == "__main__":
    main()
