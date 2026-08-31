#!/usr/bin/env python3
"""
End-to-end validation: test optimized models against Laua-an dataset.
Simulates app prediction flow and measures accuracy.
"""

import argparse
import csv
import json
import pathlib
import pickle
import sys
from collections import Counter, defaultdict
from statistics import mean

sys.path.insert(0, str(pathlib.Path(__file__).parent / "pipeline"))

from semiquant_schema import canonicalize_level

def load_features(features_path: pathlib.Path) -> list[dict]:
    """Load feature CSV."""
    with open(features_path) as f:
        return list(csv.DictReader(f))

def load_models(models_dir: pathlib.Path) -> dict:
    """Load all per-analyte models."""
    models = {}
    
    # Load metadata
    metadata_path = models_dir / "semiquant_models_metadata.json"
    with open(metadata_path) as f:
        metadata = json.load(f)
    
    # Load each model
    for analyte, info in metadata.items():
        model_file = models_dir / info["model_file"]
        with open(model_file, "rb") as f:
            models[analyte] = pickle.load(f)
    
    print(f"[OK] Loaded {len(models)} models from {models_dir}")
    return models

def predict_semiquant(X: list, models: dict) -> dict:
    """Predict all 10 analytes for a single sample."""
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
    
    predictions = {}
    
    for analyte, model in models.items():
        if analyte not in analyte_feature_map:
            continue
        
        feat_cols = analyte_feature_map[analyte]
        features = [X.get(col, 0) for col in feat_cols]
        
        try:
            features = [float(f) for f in features]
            pred = model.predict([features])[0]
            predictions[analyte] = pred
        except Exception as e:
            predictions[analyte] = "ERROR"
    
    return predictions

def evaluate_on_laua_an(rows: list[dict], models: dict) -> dict:
    """Evaluate models on Laua-an data (per-analyte accuracy)."""
    # Group by analyte
    analyte_data = defaultdict(lambda: {"predictions": [], "ground_truth": []})
    
    print(f"\nProcessing {len(rows)} Laua-an samples...")
    
    for row in rows:
        analyte_gt = row.get("analyte", "").strip()
        level_gt = row.get("level", "").strip()
        
        if not analyte_gt or not level_gt:
            continue

        canonical_level = canonicalize_level(analyte_gt, level_gt)
        if canonical_level is None:
            continue
        
        # Get prediction for this analyte
        predictions = predict_semiquant(row, models)
        pred_level = predictions.get(analyte_gt, "ERROR")
        
        analyte_data[analyte_gt]["ground_truth"].append(canonical_level)
        analyte_data[analyte_gt]["predictions"].append(pred_level)
    
    # Compute per-analyte accuracy
    results = {}
    print(f"\n{'Analyte':<20} {'Correct':<8} {'Total':<8} {'Accuracy':<10}")
    print("-" * 50)
    
    for analyte in sorted(analyte_data.keys()):
        data = analyte_data[analyte]
        gt = data["ground_truth"]
        pred = data["predictions"]
        
        correct = sum(1 for g, p in zip(gt, pred) if g == p)
        total = len(gt)
        accuracy = correct / total if total > 0 else 0
        
        results[analyte] = {
            "correct": correct,
            "total": total,
            "accuracy": accuracy,
        }
        
        print(f"{analyte:<20} {correct:<8} {total:<8} {accuracy:.4f} ({accuracy*100:.2f}%)")
    
    total_correct = sum(result["correct"] for result in results.values())
    total_predictions = sum(result["total"] for result in results.values())
    results["_overall"] = {
        "correct": total_correct,
        "total": total_predictions,
        "accuracy": total_correct / total_predictions if total_predictions else 0.0,
    }
    return results


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate optimized semiquant KNN models on Laua-an rows.")
    parser.add_argument(
        "--features",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/dataset/features_normalized_hsv.csv"),
        help="Normalized HSV feature CSV containing Laua-an rows.",
    )
    parser.add_argument(
        "--models-dir",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/output/semiquant_models"),
        help="Directory containing per-analyte model pickle files.",
    )
    parser.add_argument(
        "--source-contains",
        default="LAUAAN",
        help="Only evaluate rows whose source_zip contains this text. Use empty string for all rows.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    print("=" * 70)
    print("END-TO-END VALIDATION: LAUA-AN DATASET")
    print("=" * 70)
    print()
    
    # Load models
    models_dir = args.models_dir
    if not models_dir.exists():
        print(f"[ERROR] Models directory not found: {models_dir}")
        print("Run build_optimized_models.py first")
        sys.exit(1)
    
    models = load_models(models_dir)
    print()
    
    # Load Laua-an features using normalized HSV
    features_hsv = args.features
    if not features_hsv.exists():
        print(f"[WARN] Laua-an HSV features not found: {features_hsv}")
        print("Run: python pipeline/build_normalized_hsv_features.py --input pipeline/dataset/features.csv --output pipeline/dataset/features_normalized_hsv.csv")
        sys.exit(1)
    
    print(f"Loading {features_hsv.name}...")
    rows = load_features(features_hsv)
    if args.source_contains:
        needle = args.source_contains.lower()
        rows = [row for row in rows if needle in row.get("source_zip", "").lower()]
    print(f"[OK] Loaded {len(rows)} rows")
    
    # Evaluate
    results = evaluate_on_laua_an(rows, models)
    
    # Summary
    print("\n" + "=" * 70)
    print("VALIDATION SUMMARY")
    print("=" * 70)
    
    overall = results.pop("_overall")
    accuracies = [r["accuracy"] for r in results.values()]
    avg_acc = mean(accuracies)
    
    print(f"\nOverall accuracy: {overall['accuracy']:.4f} ({overall['accuracy']*100:.2f}%)")
    print(f"Macro average by analyte: {avg_acc:.4f} ({avg_acc*100:.2f}%)")
    print(f"Target: 80.00%")
    print(f"Status: {'TARGET REACHED' if overall['accuracy'] >= 0.80 else 'Below target'}")
    
    # Per-analyte breakdown
    print("\nPer-analyte performance:")
    best_analyte = max(results.keys(), key=lambda a: results[a]["accuracy"])
    worst_analyte = min(results.keys(), key=lambda a: results[a]["accuracy"])
    print(f"  Best:  {best_analyte} ({results[best_analyte]['accuracy']*100:.2f}%)")
    print(f"  Worst: {worst_analyte} ({results[worst_analyte]['accuracy']*100:.2f}%)")
    
    print("\n[OK] Validation complete!")
    print("\nNEXT STEPS:")
    print("  1. Deploy optimized models to app")
    print("  2. Test app prediction endpoint")
    print("  3. Verify results match this validation")
    print("  4. Monitor real-world accuracy on new data")

if __name__ == "__main__":
    main()

