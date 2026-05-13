#!/usr/bin/env python3
"""Run a single dipstick image through the vision + KNN pipeline and emit JSON.

This is a runtime bridge for the Flutter app. It reuses the existing pipeline
surface:
1) geometric rectification
2) marker-center AWB
3) pad slicing
4) HSV feature extraction
5) KNN reference-map prediction
6) provisional Bayesian visual fusion

The final checklist-adjusted Bayesian fusion still happens in the app.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import cv2

from .bayesian_fusion_lr import BayesianFusionLREngine
from .evaluate_semiquant import (
    AbstainConfig,
    EventCenteringConfig,
    _load_distance_weights,
    apply_event_centering,
    load_reference_map,
    predict_one,
)
from .semiquant_schema import ANALYTE_LEVEL_SCHEMA, canonicalize_level
from .vision_pipeline import ANALYTE_ORDER, BurstFeaturePipeline, VisionPipelineConfig, analyte_to_key


REFERENCE_RANGES = {
    "Leukocytes": "Negative",
    "Nitrite": "Negative",
    "Urobilinogen": "0.2 - 1.0 mg/dL",
    "Protein": "Negative",
    "pH": "4.5 - 8.0",
    "Blood": "Negative",
    "Specific Gravity": "1.005 - 1.030",
    "Ketone": "Negative",
    "Bilirubin": "Negative",
    "Glucose": "Negative",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Predict dipstick values from an image.")
    parser.add_argument("--image", required=True, type=Path, help="Path to the captured dipstick image.")
    parser.add_argument(
        "--map",
        type=Path,
        default=None,
        help="Path to knn_reference_map.json (defaults to current or legacy reference map).",
    )
    parser.add_argument(
        "--distance-weight-profile",
        choices=["legacy", "analyte-v1"],
        default="legacy",
        help="Distance weighting profile for KNN lookup.",
    )
    parser.add_argument(
        "--distance-weights-json",
        type=Path,
        default=None,
        help="Optional JSON file with per-analyte distance weight overrides.",
    )
    return parser.parse_args()


def _normalize_display_level(level: str | None) -> str:
    if not level:
        return "Unavailable"
    normalized = level.strip()
    if normalized.lower() in {"neg", "negative"}:
        return "Negative"
    return normalized


def _screening_probability(level: str | None, confidence: float) -> float:
    normalized = (level or "").strip().lower()
    confidence = max(0.0, min(confidence, 1.0))

    if normalized in {"", "unavailable"}:
        return 0.5
    if normalized in {"neg", "negative"}:
        return max(0.05, min(0.30, 0.18 - (confidence * 0.10)))
    if "trace" in normalized:
        return max(0.20, min(0.45, 0.30 + (confidence * 0.12)))
    if "moderate" in normalized or "125" in normalized:
        return max(0.45, min(0.75, 0.58 + (confidence * 0.16)))
    if "large" in normalized or "500" in normalized or normalized == "high" or normalized == "positive":
        return max(0.70, min(0.95, 0.82 + (confidence * 0.10)))
    return max(0.0, min(1.0, confidence))


def _reference_map_path(root: Path) -> Path:
    current = root / "pipeline" / "output" / "knn_reference_map.json"
    if current.exists():
        return current
    legacy = root / "pipeline" / "output" / "knn_reference_map_20260323_baseline_restored.json"
    if legacy.exists():
        return legacy
    raise FileNotFoundError("No KNN reference map found in pipeline/output.")


def main() -> None:
    args = parse_args()
    payload = run_scan(args.image.resolve(), map_path=args.map, distance_weight_profile=args.distance_weight_profile)
    print(json.dumps(payload, indent=2))


def run_scan(
    image_path: Path,
    map_path: Path | None = None,
    distance_weight_profile: str = "legacy",
    progress_callback: callable | None = None,
) -> dict[str, Any]:
    root = Path(__file__).resolve().parent.parent
    image_path = Path(image_path)
    if not image_path.exists():
        raise FileNotFoundError(f"Image not found: {image_path}")

    if progress_callback:
        try:
            progress_callback("start", 5)
        except Exception:
            pass

    map_path = Path(map_path).resolve() if map_path is not None else _reference_map_path(root)
    if progress_callback:
        try:
            progress_callback("map_loaded", 10)
        except Exception:
            pass

    refs, map_centering = load_reference_map(map_path)

    config = VisionPipelineConfig(feature_space="hsv")
    pipeline = BurstFeaturePipeline(config)
    image_bgr = cv2.imread(str(image_path))
    if image_bgr is None:
        raise ValueError(f"Failed to decode image: {image_path}")

    if progress_callback:
        try:
            progress_callback("image_decoded", 20)
        except Exception:
            pass

    burst = pipeline.process_burst([image_bgr])
    if progress_callback:
        try:
            progress_callback("features_extracted", 50)
        except Exception:
            pass
    feature_rows: list[dict[str, Any]] = []

    distance_weights = _load_distance_weights(distance_weight_profile, None)
    abstain_config = AbstainConfig(enabled=False, min_confidence=0.0, min_margin=0.0, max_distance=999.0)
    centering_config = EventCenteringConfig(
        enabled=False,
        target_h=map_centering.target_h,
        target_s=map_centering.target_s,
        target_v=map_centering.target_v,
        mode=map_centering.mode,
        target_by_light=map_centering.target_by_light,
    )

    screening_probabilities: dict[str, float] = {}

    for analyte in ANALYTE_ORDER:
        col = burst.features_by_pad.get(analyte)
        if col is None:
            # Pad not detected in any frame
            level = "Unavailable"
            confidence = 0.0
            distance = 0.0
            margin = 0.0
            predicted_level = None
            h, s, v = 0.0, 0.0, 0.0
        else:
            h, s, v = col
            h, s, v = apply_event_centering(
                h,
                s,
                v,
                event_id="",
                light_kelvin="",
                event_anchors={},
                config=centering_config,
            )
            predicted_level, confidence, distance, margin, was_abstained = predict_one(
                analyte,
                h,
                s,
                v,
                refs,
                distance_weights,
                abstain_config,
            )

            if predicted_level is None or was_abstained:
                level = "Unavailable"
                confidence = 0.0
                distance = 0.0
                margin = 0.0
            else:
                level = _normalize_display_level(predicted_level)

        analyte_status = "moderate" if level.lower() != "negative" else "normal"
        abnormal_probability = _screening_probability(level, confidence)
        code = analyte_to_key(analyte).upper()
        
        row_data = {
            "code": code,
            "name": analyte,
            "predicted_level": level,
            "display_value": level,
            "reference_range": REFERENCE_RANGES.get(analyte, "Reference unavailable"),
            "status": analyte_status,
            "abnormal_probability": round(abnormal_probability, 6),
            "confidence": round(float(confidence), 6),
            "distance": round(float(distance), 6),
            "confidence_margin": round(float(margin), 6),
        }
        
        if col is not None:
            row_data.update({
                "feature_h": round(float(h), 6),
                "feature_s": round(float(s), 6),
                "feature_v": round(float(v), 6),
            })
        else:
            row_data.update({
                "feature_h": 0.0,
                "feature_s": 0.0,
                "feature_v": 0.0,
                "detection_status": "pad_not_detected",
            })
        
        feature_rows.append(row_data)

        if code in {"GLU", "LEU", "PRO", "NIT"}:
            screening_probabilities[code] = abnormal_probability

    knn_abnormal_prob = sum(screening_probabilities.values()) / len(screening_probabilities) if screening_probabilities else 0.0
    fusion_engine = BayesianFusionLREngine(prior_abnormal=0.5)
    provisional_fusion = fusion_engine.fuse(knn_abnormal_prob=knn_abnormal_prob, selected_symptoms={})

    if progress_callback:
        try:
            progress_callback("predictions_complete", 85)
        except Exception:
            pass

    # Count successful detections
    pads_detected = sum(1 for row in feature_rows if row["confidence"] > 0 or "detection_status" not in row)
    pads_unavailable = len(feature_rows) - pads_detected
    
    payload = {
        "id": f"scan_{image_path.stem}",
        "date": None,
        "image_path": str(image_path),
        "status": provisional_fusion["risk_bucket"].lower(),
        "confidence": provisional_fusion["posterior_probability"],
        "posterior_probability": provisional_fusion["posterior_probability"],
        "risk_bucket": provisional_fusion["risk_bucket"],
        "model_version": map_path.name,
        "reference_map_path": str(map_path),
        "pipeline_version": "vision_pipeline_hsv_knn",
        "frames_total": burst.frames_total,
        "frames_used": burst.frames_used,
        "frames_skipped": burst.frames_skipped,
        "frame_errors": burst.frame_errors,
        "features_by_pad": burst.features_by_pad,
        "pads_detected": pads_detected,
        "pads_unavailable": pads_unavailable,
        "analytes": feature_rows,
        "screening_probabilities": screening_probabilities,
        "provisional_visual_fusion": provisional_fusion,
    }

    if progress_callback:
        try:
            progress_callback("complete", 100)
        except Exception:
            pass

    return payload


if __name__ == "__main__":
    main()