#!/usr/bin/env python3
"""Quick LAB evaluator - reads LAB reference map and features CSV."""

import csv
import json
import math
import pathlib
from collections import defaultdict
from statistics import median
from sklearn.metrics import accuracy_score, f1_score, cohen_kappa_score

ANALYTE_ORDER = [
    "Leukocytes", "Nitrite", "Urobilinogen", "Protein", "pH", 
    "Blood", "Specific Gravity", "Ketone", "Bilirubin", "Glucose"
]

def safe_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default

def lab_distance(l1, a1, b1, l2, a2, b2):
    """Euclidean distance in LAB space."""
    dl = l1 - l2
    da = a1 - a2
    db = b1 - b2
    return math.sqrt(dl*dl + da*da + db*db)

def load_lab_map(path):
    """Load LAB reference map and extract feature space info."""
    with open(path) as f:
        data = json.load(f)
    feature_space = data.get("reference_color_space", "hsv")
    return data, feature_space

def evaluate_lab():
    map_path = pathlib.Path("pipeline/output/knn_reference_map.json")
    features_path = pathlib.Path("pipeline/dataset/features_lab.csv")
    
    # Load map
    map_data, feature_space = load_lab_map(map_path)
    if feature_space != "lab":
        print(f"ERROR: Reference map shows {feature_space}, expected lab")
        return
    
    print(f"✓ Reference map feature space: {feature_space}")
    
    # Load features
    with open(features_path) as f:
        rows = list(csv.DictReader(f))
    print(f"✓ Loaded {len(rows)} feature rows")
    
    # Build reference database
    refs = {}
    for analyte in ANALYTE_ORDER:
        analyte_data = map_data["analytes"].get(analyte, [])
        refs[analyte] = []
        for item in analyte_data:
            refs[analyte].append({
                "level": item.get("level"),
                "l": safe_float(item.get("l")),
                "a": safe_float(item.get("a")),
                "b": safe_float(item.get("b")),
            })
    print(f"✓ Built reference database for {len(refs)} analytes")
    
    # Predict - one row per analyte-event pair
    y_true, y_pred = [], []
    predictions = 0
    
    for row in rows:
        split = row.get("split")
        if split not in ("train", "val", "test"):
            continue
        
        analyte = row.get("analyte", "").strip()
        truth_level = row.get("level", "").strip()
        
        if not analyte or analyte not in ANALYTE_ORDER or not truth_level:
            continue
        
        # Read LAB features  for this analyte
        col_l = f"{analyte.lower()}_l"
        col_a = f"{analyte.lower()}_a"
        col_b = f"{analyte.lower()}_b"
        
        l_val = safe_float(row.get(col_l))
        a_val = safe_float(row.get(col_a))
        b_val = safe_float(row.get(col_b))
        
        # Find nearest reference
        best_level = None
        best_dist = float('inf')
        
        for ref in refs[analyte]:
            dist = lab_distance(l_val, a_val, b_val, 
                               ref["l"], ref["a"], ref["b"])
            if dist < best_dist:
                best_dist = dist
                best_level = ref["level"]
        
        if best_level:
            y_true.append(truth_level)
            y_pred.append(best_level)
            predictions += 1
    
    if not y_true:
        print("ERROR: No valid predictions generated")
        return
    
    acc = accuracy_score(y_true, y_pred)
    f1_macro = f1_score(y_true, y_pred, average='macro', zero_division=0)
    kappa = cohen_kappa_score(y_true, y_pred)
    
    print(f"\n✓ Evaluated {predictions} analyte predictions")
    print(f"\nLAB Results:")
    print(f"  Accuracy: {acc:.4f}")
    print(f"  F1-macro: {f1_macro:.4f}")
    print(f"  Cohen Kappa: {kappa:.4f}")
    print(f"\nComparison to Centered-HSV Baseline:")
    print(f"  HSV Accuracy: 0.3219")
    print(f"  LAB vs HSV: {(acc - 0.3219) / 0.3219 * 100:+.2f}%")

if __name__ == "__main__":
    evaluate_lab()
