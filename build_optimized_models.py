#!/usr/bin/env python3
"""
Build and save optimized per-analyte KNN models based on hyperparameter tuning.
Uses the results from optimize_semiquant.py to create production-ready models.
"""

import argparse
import csv
import json
import pathlib
import pickle
import sys
from collections import defaultdict
from statistics import mean

sys.path.insert(0, str(pathlib.Path(__file__).parent / "pipeline"))

from model_features import hsv_to_circular_features
from semiquant_schema import canonicalize_level

MODEL_VERSION = "optimized_semiquant_knn_v1_lauaan_20260830"

def load_features(features_path: pathlib.Path) -> list[dict]:
    """Load feature CSV."""
    with open(features_path) as f:
        return list(csv.DictReader(f))

def build_optimized_models(rows: list[dict], optimization_results: dict) -> dict:
    """Build per-analyte KNN models using optimized hyperparameters."""
    from sklearn.neighbors import KNeighborsClassifier
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import FunctionTransformer, StandardScaler
    
    analyte_feature_map = {
        "Leukocytes": ["leukocytes_h", "leukocytes_s", "leukocytes_v"],
        "Nitrite": ["nitrite_h", "nitrite_s", "nitrite_v"],
        "Urobilinogen": ["urobilinogen_h", "urobilinogen_s", "urobilinogen_v"],
        "Protein": ["protein_h", "protein_s", "protein_v"],
        "pH": ["ph_h", "ph_s", "ph_v"],
        "Blood": ["blood_h", "blood_s", "blood_v"],
        "Specific Gravity": ["specific_gravity_h", "specific_gravity_s", "specific_gravity_v"],
        "Ketone": ["ketone_h", "ketone_s", "ketone_v"],
        "Bilirubin": ["bilirubin_h", "bilirubin_s", "bilirubin_v"],
        "Glucose": ["glucose_h", "glucose_s", "glucose_v"],
    }
    
    # Group data by analyte
    analyte_data = defaultdict(lambda: {"X": [], "y": []})
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        
        if not analyte or not level or analyte not in analyte_feature_map:
            continue

        canonical_level = canonicalize_level(analyte, level)
        if canonical_level is None:
            continue
        
        try:
            features = [float(row[col]) for col in analyte_feature_map[analyte]]
            analyte_data[analyte]["X"].append(features)
            analyte_data[analyte]["y"].append(canonical_level)
        except (ValueError, KeyError, TypeError):
            pass
    
    print(f"Data grouped by analyte:")
    for ana in sorted(analyte_data.keys()):
        print(f"  {ana}: {len(analyte_data[ana]['X'])} samples")
    print()
    
    # Build models
    models = {}
    
    print(f"{'Analyte':<20} {'k':<4} {'Metric':<15} {'Samples':<8} {'Levels':<8} Status")
    print("-" * 75)
    
    for analyte in sorted(analyte_feature_map.keys()):
        if analyte not in analyte_data or len(analyte_data[analyte]["X"]) == 0:
            print(f"{analyte:<20} N/A    N/A             N/A      N/A      [WARN] No data")
            continue
        
        X = analyte_data[analyte]["X"]
        y = analyte_data[analyte]["y"]
        
        # Get optimized hyperparameters
        opt = optimization_results.get(analyte, {})
        k = opt.get("best_k", 5)
        metric = opt.get("best_metric", "euclidean")
        transform = opt.get("feature_transform", "raw")
        
        # Build model
        knn = KNeighborsClassifier(n_neighbors=k, metric=metric, weights="distance")
        if transform == "scaled":
            model = make_pipeline(StandardScaler(), knn)
        elif transform == "circular_scaled":
            model = make_pipeline(
                FunctionTransformer(hsv_to_circular_features, validate=False),
                StandardScaler(),
                knn,
            )
        else:
            model = knn
        model.fit(X, y)
        
        models[analyte] = {
            "model": model,
            "k": k,
            "metric": metric,
            "feature_transform": transform,
            "n_samples": len(X),
            "n_levels": len(set(y)),
            "accuracy": opt.get("accuracy", 0),
        }
        
        print(f"{analyte:<20} {k:<4} {metric:<15} {len(X):<8} {len(set(y)):<8} [OK]")
    
    return models

def save_models(models: dict, output_dir: pathlib.Path):
    """Save models to disk."""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Save each model
    for analyte, data in models.items():
        model_path = output_dir / f"{analyte.lower().replace(' ', '_')}_knn_model.pkl"
        with open(model_path, "wb") as f:
            pickle.dump(data["model"], f)
    
    # Save metadata
    metadata = {}
    for analyte, data in models.items():
        metadata[analyte] = {
            "model_version": MODEL_VERSION,
            "k": data["k"],
            "metric": data["metric"],
            "feature_transform": data["feature_transform"],
            "feature_space": "normalized_hsv",
            "n_samples": data["n_samples"],
            "n_levels": data["n_levels"],
            "accuracy": data["accuracy"],
            "model_file": f"{analyte.lower().replace(' ', '_')}_knn_model.pkl",
        }
    
    metadata_path = output_dir / "semiquant_models_metadata.json"
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)
    
    print(f"\n[OK] Saved {len(models)} models to {output_dir}")
    print(f"[OK] Metadata saved to {metadata_path}")
    
    return metadata_path

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build optimized 10-parameter semiquant KNN models.")
    parser.add_argument(
        "--features",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/dataset/features_normalized_hsv.csv"),
        help="Normalized HSV feature CSV used to train the saved models.",
    )
    parser.add_argument(
        "--optimization-results",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/output/semiquant_optimization_results.json"),
        help="Per-analyte k/metric results from optimize_semiquant.py.",
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/output/semiquant_models"),
        help="Directory for saved model pickle files and metadata.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    print("=" * 75)
    print("BUILD OPTIMIZED SEMIQUANT MODELS")
    print("=" * 75)
    print()
    
    # Load optimization results
    opt_path = args.optimization_results
    if not opt_path.exists():
        print(f"[ERROR] Optimization results not found: {opt_path}")
        print("Run optimize_semiquant.py first")
        sys.exit(1)
    
    with open(opt_path) as f:
        optimization_results = json.load(f)
    print(f"[OK] Loaded optimization results from {opt_path}")
    print()
    
    # Load features
    features_hsv = args.features
    if not features_hsv.exists():
        print(f"[ERROR] Features file not found: {features_hsv}")
        sys.exit(1)
    
    print(f"Loading {features_hsv.name}...")
    rows = load_features(features_hsv)
    print(f"[OK] Loaded {len(rows)} rows\n")
    
    # Build models
    print("Building per-analyte KNN models...")
    models = build_optimized_models(rows, optimization_results)
    print()
    
    # Save models
    output_dir = args.output_dir
    metadata_path = save_models(models, output_dir)
    
    # Summary
    print("\n" + "=" * 75)
    print("SUMMARY")
    print("=" * 75)
    avg_accuracy = mean([data["accuracy"] for data in models.values()]) if models else 0.0
    print(f"[OK] Built {len(models)} per-analyte KNN models")
    print(f"[OK] Cross-validation average accuracy: {avg_accuracy:.4f} ({avg_accuracy*100:.2f}%)")
    print("[OK] Models ready for semiquant validation")
    print()
    print("NEXT: Test with app integration and Laua-an validation data")

if __name__ == "__main__":
    main()
