#!/usr/bin/env python3
"""Run a single dipstick image through the semiquant vision + KNN pipeline.

This is the runtime bridge for the Flutter app's 10-parameter semiquant flow:
1) geometric rectification
2) marker-center AWB
3) pad slicing
4) normalized HSV feature extraction
5) optimized per-analyte semiquant KNN prediction
"""

from __future__ import annotations

import argparse
import json
import pickle
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image, ImageOps

try:
    from .evaluate_semiquant import (
        AbstainConfig,
        EventCenteringConfig,
        _load_distance_weights,
        apply_event_centering,
        load_reference_map,
        predict_one,
    )
    from .vision_pipeline import ANALYTE_ORDER, BurstFeaturePipeline, VisionPipelineConfig, analyte_to_key
except ImportError:
    import sys

    workspace_root = Path(__file__).resolve().parent.parent
    if str(workspace_root) not in sys.path:
        sys.path.insert(0, str(workspace_root))

    from pipeline.evaluate_semiquant import (
        AbstainConfig,
        EventCenteringConfig,
        _load_distance_weights,
        apply_event_centering,
        load_reference_map,
        predict_one,
    )
    from pipeline.vision_pipeline import ANALYTE_ORDER, BurstFeaturePipeline, VisionPipelineConfig, analyte_to_key


REFERENCE_RANGES = {
    "Leukocytes": "Negative",
    "Nitrite": "Negative",
    "Urobilinogen": "3.2 - 128",
    "Protein": "Negative",
    "pH": "5.0 - 8.5",
    "Blood": "Negative",
    "Specific Gravity": "1.000 - 1.030",
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
        help="Optional legacy knn_reference_map.json path. Omit to use optimized semiquant models.",
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


def _optimized_models_dir(root: Path) -> Path:
    return root / "pipeline" / "output" / "semiquant_models"


def _load_optimized_models(models_dir: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    metadata_path = models_dir / "semiquant_models_metadata.json"
    if not metadata_path.exists():
        return {}, {}

    with metadata_path.open(encoding="utf-8") as file:
        metadata = json.load(file)

    models: dict[str, Any] = {}
    for analyte, info in metadata.items():
        if not isinstance(info, dict):
            continue
        model_file = info.get("model_file")
        if not model_file:
            continue
        model_path = models_dir / str(model_file)
        if not model_path.exists():
            continue
        with model_path.open("rb") as file:
            models[analyte] = pickle.load(file)

    return models, metadata


def _optimized_model_version(metadata: dict[str, Any]) -> str:
    versions = {
        str(info.get("model_version", "")).strip()
        for info in metadata.values()
        if isinstance(info, dict) and info.get("model_version")
    }
    if len(versions) == 1:
        return versions.pop()
    return "optimized_semiquant_knn_v1_lauaan_20260830"


def _predict_with_optimized_model(
    analyte: str,
    h: float,
    s: float,
    v: float,
    models: dict[str, Any],
) -> tuple[str | None, float, float, float]:
    model = models.get(analyte)
    if model is None:
        return None, 0.0, 0.0, 0.0

    features = [[float(h), float(s), float(v)]]
    predicted = str(model.predict(features)[0])

    confidence = 1.0
    margin = 1.0
    if hasattr(model, "predict_proba"):
        probabilities = model.predict_proba(features)[0]
        ordered = sorted((float(value) for value in probabilities), reverse=True)
        confidence = ordered[0] if ordered else 1.0
        margin = ordered[0] - ordered[1] if len(ordered) > 1 else ordered[0]

    distance = 0.0
    if hasattr(model, "kneighbors"):
        try:
            distances, _ = model.kneighbors(features, n_neighbors=1)
            distance = float(distances[0][0])
        except Exception:
            distance = 0.0

    return predicted, confidence, distance, margin


def _load_exif_corrected_bgr(image_path: Path) -> np.ndarray:
    with Image.open(image_path) as image:
        corrected = ImageOps.exif_transpose(image).convert("RGB")
        rgb = np.asarray(corrected)
    return cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)


def _iter_bgr_orientation_variants(image_path: Path) -> list[tuple[str, np.ndarray]]:
    raw = cv2.imread(str(image_path))
    if raw is None:
        raise ValueError(f"Failed to decode image: {image_path}")

    variants: list[tuple[str, np.ndarray]] = []
    try:
        exif_bgr = _load_exif_corrected_bgr(image_path)
        variants.append(("exif", exif_bgr))
        if raw.shape != exif_bgr.shape or float(np.mean(cv2.absdiff(raw, exif_bgr))) > 1.0:
            variants.append(("raw", raw))
    except Exception:
        variants.append(("raw", raw))

    expanded: list[tuple[str, np.ndarray]] = []
    seen_shapes: set[tuple[str, tuple[int, int, int]]] = set()
    rotations = (
        ("", None),
        ("_rot90_cw", cv2.ROTATE_90_CLOCKWISE),
        ("_rot180", cv2.ROTATE_180),
        ("_rot90_ccw", cv2.ROTATE_90_COUNTERCLOCKWISE),
    )
    for name, image_bgr in variants:
        for suffix, rotation in rotations:
            candidate = image_bgr if rotation is None else cv2.rotate(image_bgr, rotation)
            key = (name + suffix, candidate.shape)
            if key in seen_shapes:
                continue
            seen_shapes.add(key)
            expanded.append((name + suffix, candidate))
    return expanded


def _burst_quality_score(pipeline: BurstFeaturePipeline, burst: Any) -> float:
    features = list(burst.features_by_pad.values())
    if not features:
        return -float("inf")

    hue_values = np.array([h for h, _, _ in features], dtype=np.float32)
    sat_values = np.array([s for _, s, _ in features], dtype=np.float32)
    val_values = np.array([v for _, _, v in features], dtype=np.float32)
    loc_scores = [result.local_score for result in pipeline.slicer.last_pad_localization.values()]
    loc_mean = float(np.mean(np.array(loc_scores, dtype=np.float32))) if loc_scores else 0.0
    usable_values = float(np.mean((val_values > 0.04) & (val_values < 0.98)))
    colored_pads = float(np.sum(sat_values > 0.035))
    return (
        float(np.mean(sat_values)) * 18.0
        + float(np.std(hue_values)) / 60.0
        + usable_values * 3.0
        + colored_pads * 0.15
        + loc_mean * 0.15
    )


def _process_best_orientation(image_path: Path, config: VisionPipelineConfig) -> tuple[Any, str, float]:
    failures: list[str] = []
    best: tuple[float, Any, str] | None = None

    for variant_name, image_bgr in _iter_bgr_orientation_variants(image_path):
        pipeline = BurstFeaturePipeline(config)
        try:
            burst = pipeline.process_burst([image_bgr])
        except Exception as error:
            failures.append(f"{variant_name}: {str(error)[:120]}")
            continue

        score = _burst_quality_score(pipeline, burst)
        if variant_name in {"exif", "raw"} and score >= 4.0:
            return burst, variant_name, score

        if best is None or score > best[0]:
            best = (score, burst, variant_name)

    if best is None:
        joined = "; ".join(failures[:6])
        raise ValueError(f"No valid scan orientation processed. {joined}")

    score, burst, variant_name = best
    return burst, variant_name, score


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

    optimized_models, optimized_metadata = ({}, {})
    models_dir = _optimized_models_dir(root)
    if map_path is None:
        optimized_models, optimized_metadata = _load_optimized_models(models_dir)

    if map_path is not None:
        map_path = Path(map_path).resolve()
    elif optimized_models:
        map_path = None
    else:
        map_path = _reference_map_path(root)
    if progress_callback:
        try:
            progress_callback("map_loaded", 10)
        except Exception:
            pass

    refs = {}
    map_centering = None
    if optimized_models:
        feature_space = "normalized_hsv"
    else:
        refs, map_centering = load_reference_map(map_path)
        feature_space = map_centering.feature_space

    if progress_callback:
        try:
            progress_callback("image_decoded", 20)
        except Exception:
            pass

    config = VisionPipelineConfig(feature_space=feature_space)
    burst, orientation_variant, orientation_quality = _process_best_orientation(image_path, config)
    if progress_callback:
        try:
            progress_callback("features_extracted", 50)
        except Exception:
            pass
    feature_rows: list[dict[str, Any]] = []

    distance_weights = _load_distance_weights(distance_weight_profile, None)
    abstain_config = AbstainConfig(enabled=False, min_confidence=0.0, min_margin=0.0, max_distance=999.0)
    centering_config = None
    if map_centering is not None:
        centering_config = EventCenteringConfig(
            enabled=False,
            target_h=map_centering.target_h,
            target_s=map_centering.target_s,
            target_v=map_centering.target_v,
            mode=map_centering.mode,
            target_by_light=map_centering.target_by_light,
        )

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
            if optimized_models:
                predicted_level, confidence, distance, margin = _predict_with_optimized_model(
                    analyte,
                    h,
                    s,
                    v,
                    optimized_models,
                )
                was_abstained = False
            else:
                if centering_config is not None:
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
                    feature_space=feature_space,
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

    average_confidence = (
        sum(float(row["confidence"]) for row in feature_rows) / len(feature_rows)
        if feature_rows
        else 0.0
    )

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
        "status": "complete",
        "confidence": round(float(average_confidence), 6),
        "posterior_probability": None,
        "risk_bucket": None,
        "model_version": _optimized_model_version(optimized_metadata) if optimized_models else map_path.name,
        "reference_map_path": str(map_path) if map_path is not None else None,
        "optimized_models_path": str(models_dir) if optimized_models else None,
        "pipeline_version": "vision_pipeline_optimized_semiquant_knn" if optimized_models else "vision_pipeline_hsv_knn",
        "feature_space": feature_space,
        "image_orientation_variant": orientation_variant,
        "image_orientation_quality": round(float(orientation_quality), 6),
        "frames_total": burst.frames_total,
        "frames_used": burst.frames_used,
        "frames_skipped": burst.frames_skipped,
        "frame_errors": burst.frame_errors,
        "features_by_pad": burst.features_by_pad,
        "pads_detected": pads_detected,
        "pads_unavailable": pads_unavailable,
        "analytes": feature_rows,
        "screening_probabilities": {},
        "provisional_visual_fusion": None,
    }

    if progress_callback:
        try:
            progress_callback("complete", 100)
        except Exception:
            pass

    return payload


if __name__ == "__main__":
    main()
