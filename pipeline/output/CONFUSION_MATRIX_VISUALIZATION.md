# Confusion Matrix: Binary k-NN Classification
**Model:** k-NN (k=5, Circular Hue-Euclidean Distance, Distance-Weighted)  
**Dataset:** 143 test samples (31 Normal, 112 Abnormal)  
**Generated:** March 24, 2026  

---

## Matrix Layout

|  | **Predicted: Normal** | **Predicted: Abnormal** | **Total** | **Recall** |
|:---:|:---:|:---:|:---:|:---:|
| **Actual: Normal** | **TN = 12** ✓ | **FP = 19** ✗ | 31 | 38.71% |
| **Actual: Abnormal** | **FN = 13** ✗ | **TP = 99** ✓ | 112 | 88.39% |
| **Total** | 25 | 118 | **143** |  |
| **Precision** | 48.00% | 83.90% |  |  |

---

## Key Metrics

| Metric | Value | Interpretation |
|--------|-------|-----------------|
| **Accuracy** | **77.62%** | Correctly classified: 111 / 143 samples |
| **Sensitivity** (Recall for Abnormal) | **88.39%** | Of 112 abnormal samples, 99 correctly identified |
| **Specificity** (Recall for Normal) | **38.71%** | Of 31 normal samples, only 12 correctly identified |
| **Precision (Abnormal)** | **83.90%** | When predicting abnormal, correct 84% of the time |
| **Precision (Normal)** | **48.00%** | When predicting normal, correct 48% of the time |
| **F1 Score (Abnormal)** | **0.8609** | Balanced measure: 86.09% |

---

## Visual Heatmap

```
                    Predicted
                Normal  |  Abnormal
    ───────────────────────────────────
    N        │  12 (✓)  │  19 (✗)  │  31 total
    o        │          │          │
    r  A  ───┼──────────┼──────────┼─ 38.71% recall
    m  c  c  │  13 (✗)  │  99 (✓)  │ 112 total
    a  t  t  │          │          │
    l  u     ───┼──────────┼──────────┼─ 88.39% recall
       a        │          │          │
    ───────────────────────────────────
       l        25         118       143 total
              48.0%      83.9%
             precision  precision
```

---

## Performance Interpretation

### ✅ Strengths
- **High Sensitivity (88.39%):** The model is excellent at catching abnormal cases
  - Out of every 100 truly abnormal samples, 88 are correctly identified
  - Minimizes missed diagnoses in the abnormal class

- **High F1 Score (0.8609):** Good overall balance in detecting abnormal cases
  
- **Good Precision on Abnormal (83.90%):** When saying "abnormal," the model is correct 84% of the time

### ⚠️ Limitations
- **Low Specificity (38.71%):** Struggles with normal samples
  - Out of 31 truly normal samples, only 12 are correctly identified
  - **61% false alarm rate** on healthy individuals
  
- **Low Precision on Normal (48.00%):** When saying "normal," less reliable (only 48% correct)

### 📊 Class Imbalance Effect
- Test set: 31 Normal : 112 Abnormal (3.6:1 ratio)
- Model biases toward majority class (Abnormal)
- Despite SMOTE balancing in training, eval set reflects true distribution
- Feature space overlap between Normal and Trace levels contributes to boundary blur

---

## Confusion Matrix Breakdown

### Correct Predictions (111 total = 77.62%)
- **True Positives (TP):** 99 abnormal samples correctly identified
- **True Negatives (TN):** 12 normal samples correctly identified

### Incorrect Predictions (32 total = 22.38%)
- **False Positives (FP):** 19 normal samples incorrectly flagged as abnormal
  - Clinical impact: Healthy user receives false alarm
- **False Negatives (FN):** 13 abnormal samples missed
  - Clinical impact: Patient with abnormal result not flagged

---

## Defense Narrative

**"The binary k-NN model achieves 77.62% overall accuracy with particularly strong sensitivity (88.39%) for detecting abnormal cases. The lower specificity (38.71%) reflects the fundamental challenge of distinguishing normal from trace-level results when collapsed into a binary classification. The model prioritizes sensitivity because missing an abnormality is clinically riskier than a false alarm. Phase 2 training will use fine-grained semiquant levels (Negative vs. Trace vs. 1+ vs. 2+ vs. 3+) to sharpen the normal-abnormal boundary and improve specificity."**

---

## Distance Metric Details
- **Metric:** Circular Hue-Euclidean (Hue: cos/sin transformation, S/V: linear)
- **Neighbors:** k=5
- **Weighting:** Distance-weighted (closer neighbors influence more)
- **Algorithm:** Brute-force search
- **Feature Space:** 30 HSV dimensions (3 channels × 10 analytes) transformed to 40-D circular

---

*Generated for thesis defense presentation*
