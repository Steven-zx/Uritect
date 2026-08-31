#!/usr/bin/env python3
"""
Semiquant hyperparameter optimization for 80% target.
Tests k values, distance metrics, and feature weighting.
"""

import argparse
import csv
import json
import pathlib
import sys
from collections import Counter, defaultdict
from statistics import mean

sys.path.insert(0, str(pathlib.Path(__file__).parent / "pipeline"))

from model_features import hsv_to_circular_features
from semiquant_schema import canonicalize_level

def load_features(features_path: pathlib.Path) -> list[dict]:
    """Load feature CSV."""
    with open(features_path) as f:
        return list(csv.DictReader(f))

def extract_semiquant_data(rows: list[dict]) -> tuple[list, list]:
    """Extract semiquant samples (one per analyte per event)."""
    X, y_analyte, y_level, event_ids = [], [], [], []
    
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
    
    for row in rows:
        analyte = row.get("analyte", "").strip()
        level = row.get("level", "").strip()
        event_id = row.get("event_id", "")
        
        if not analyte or not level or analyte not in analyte_feature_map:
            continue

        canonical_level = canonicalize_level(analyte, level)
        if canonical_level is None:
            continue
        
        try:
            features = [float(row[col]) for col in analyte_feature_map[analyte]]
            X.append(features)
            y_analyte.append(analyte)
            y_level.append(canonical_level)
            event_ids.append(event_id)
        except (ValueError, KeyError, TypeError):
            pass
    
    return X, y_analyte, y_level, event_ids

def optimize_per_analyte(X: list, y_analyte: list, y_level: list, event_ids: list) -> dict:
    """Optimize per-analyte classifier."""
    from sklearn.model_selection import StratifiedKFold
    from sklearn.neighbors import KNeighborsClassifier
    from sklearn.metrics import accuracy_score, f1_score
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import FunctionTransformer, StandardScaler
    
    results = {}
    
    # Group by analyte
    analyte_data = defaultdict(lambda: {"X": [], "y": [], "events": []})
    for x, analyte, level, event_id in zip(X, y_analyte, y_level, event_ids):
        analyte_data[analyte]["X"].append(x)
        analyte_data[analyte]["y"].append(level)
        analyte_data[analyte]["events"].append(event_id)
    
    print(f"\n{'Analyte':<20} {'Samples':<10} {'Levels':<8} {'Best k':<8} {'Best metric':<15} {'Accuracy':<10}")
    print("-" * 80)
    
    for analyte in sorted(analyte_data.keys()):
        data = analyte_data[analyte]
        X_ana = data["X"]
        y_ana = data["y"]
        
        if len(X_ana) < 10:
            continue
        
        best_acc = 0
        best_config = None
        
        min_level_count = min(Counter(y_ana).values())
        n_splits = min(5, min_level_count)
        if n_splits < 2:
            continue

        for k in [1, 3, 5, 7, 9, 11, 15, 21, 31]:
            if k >= len(X_ana):
                continue
            
            for metric in ["euclidean", "manhattan", "chebyshev"]:
                for transform_name, model in (
                    (
                        "raw",
                        KNeighborsClassifier(n_neighbors=k, metric=metric, weights="distance"),
                    ),
                    (
                        "scaled",
                        make_pipeline(
                            StandardScaler(),
                            KNeighborsClassifier(n_neighbors=k, metric=metric, weights="distance"),
                        ),
                    ),
                    (
                        "circular_scaled",
                        make_pipeline(
                            FunctionTransformer(hsv_to_circular_features, validate=False),
                            StandardScaler(),
                            KNeighborsClassifier(n_neighbors=k, metric=metric, weights="distance"),
                        ),
                    ),
                ):
                    # Stratified CV with enough samples in every level.
                    skf = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)
                    accs = []
                    
                    for train_idx, test_idx in skf.split(X_ana, y_ana):
                        X_train = [X_ana[i] for i in train_idx]
                        X_test = [X_ana[i] for i in test_idx]
                        y_train = [y_ana[i] for i in train_idx]
                        y_test = [y_ana[i] for i in test_idx]
                        
                        model.fit(X_train, y_train)
                        y_pred = model.predict(X_test)
                        acc = accuracy_score(y_test, y_pred)
                        accs.append(acc)
                    
                    avg_acc = mean(accs)
                    if avg_acc > best_acc:
                        best_acc = avg_acc
                        best_config = (k, metric, transform_name)
        
        results[analyte] = {
            "samples": len(X_ana),
            "levels": len(set(y_ana)),
            "best_k": best_config[0] if best_config else 5,
            "best_metric": best_config[1] if best_config else "euclidean",
            "feature_transform": best_config[2] if best_config else "raw",
            "accuracy": round(best_acc, 4),
        }
        
        print(f"{analyte:<20} {len(X_ana):<10} {len(set(y_ana)):<8} {results[analyte]['best_k']:<8} {results[analyte]['best_metric']:<15} {best_acc:.4f} {results[analyte]['feature_transform']}")
    
    return results

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Optimize 10-parameter semiquant KNN models.")
    parser.add_argument(
        "--features",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/dataset/features_normalized_hsv.csv"),
        help="Normalized HSV feature CSV to evaluate.",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path("pipeline/output/semiquant_optimization_results.json"),
        help="Where to save per-analyte optimization results.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    print("=" * 80)
    print("SEMIQUANT OPTIMIZATION FOR 80% ACCURACY")
    print("=" * 80)
    
    features_hsv = args.features
    
    if not features_hsv.exists():
        print(f"[ERROR] Features file not found: {features_hsv}")
        sys.exit(1)
    
    print(f"\nLoading {features_hsv.name}...")
    rows = load_features(features_hsv)
    print(f"[OK] Loaded {len(rows)} rows")
    
    print("\nExtracting semiquant data...")
    X, y_analyte, y_level, event_ids = extract_semiquant_data(rows)
    print(f"[OK] Extracted {len(X)} semiquant samples")
    
    print("\nOptimizing per-analyte classifiers...")
    results = optimize_per_analyte(X, y_analyte, y_level, event_ids)
    
    # Summary
    print("\n" + "=" * 80)
    print("OPTIMIZATION SUMMARY")
    print("=" * 80)
    
    if not results:
        print("\n[ERROR] No results; check data extraction")
        sys.exit(1)
    
    avg_accuracy = mean([r["accuracy"] for r in results.values()])
    print(f"\nAverage per-analyte accuracy: {avg_accuracy:.4f} ({avg_accuracy*100:.2f}%)")
    print(f"Target: 80.00%")
    print(f"Gap: {(0.80 - avg_accuracy)*100:.2f}%")
    
    # Save results
    output_path = args.output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\n[OK] Results saved to {output_path}")
    
    print("\nNEXT STEPS:")
    print("  1. Apply best k/metric configs to train.py")
    print("  2. Test ensemble: combine per-analyte predictions")
    print("  3. Investigate low-accuracy analytes: data quality check")
    print("  4. Consider confidence thresholding: abstain on uncertain predictions")
    print("  5. Gather more Laua-an data: scale up training set")

if __name__ == "__main__":
    main()
