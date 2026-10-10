# URITECT per-analyte k-NN evaluation

Evaluated 10 October 2026. Frozen production settings; constructed normalized-HSV feature dataset. No production artifacts changed.

## production training resubstitution

Fit each classifier to all constructed feature rows, then predict those same rows. Self-neighbors are included. Apparent fit only.

| Analyte | n | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen kappa |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Leukocytes | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Nitrite | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Urobilinogen | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Protein | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| pH | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Blood | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Specific Gravity | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Ketone | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Bilirubin | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Glucose | 784 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |

## historical split training resubstitution

Fit to historical 80% grouped partition, then predict those same training rows.

| Analyte | n | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen kappa |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Leukocytes | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Nitrite | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Urobilinogen | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Protein | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| pH | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Blood | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Specific Gravity | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Ketone | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Bilirubin | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Glucose | 621 | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |

## historical split development test

Predict historical 20% grouped partition. GroupShuffleSplit, specimen_group, random_state=42. Reproduces prior report, but related-capture grouping is imperfect and configurations were tuned on this split.

| Analyte | n | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen kappa |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Leukocytes | 163 | 68.10% | 44.50% | 46.72% | 85.74% | 0.3155 |
| Nitrite | 163 | 99.39% | 83.18% | 75.00% | 75.00% | 0.6639 |
| Urobilinogen | 163 | 82.82% | 64.57% | 62.15% | 62.15% | 0.3087 |
| Protein | 163 | 87.73% | 25.93% | 24.56% | 83.34% | 0.2530 |
| pH | 163 | 81.60% | 57.49% | 52.25% | 87.79% | 0.3567 |
| Blood | 163 | 93.25% | 90.69% | 88.93% | 91.15% | 0.7142 |
| Specific Gravity | 163 | 58.90% | 55.57% | 56.43% | 91.54% | 0.4938 |
| Ketone | 163 | 73.01% | 67.52% | 66.81% | 66.81% | 0.3669 |
| Bilirubin | 163 | 87.12% | 85.39% | 84.65% | 84.65% | 0.7082 |
| Glucose | 163 | 93.25% | 37.41% | 32.38% | 87.75% | 0.4565 |

## Interpretation

Unweighted means of per-category one-vs-rest TP/(TP+FN) and TN/(TN+FP). Labels are union of actual and predicted categories within each partition. Undefined denominators use zero to reproduce the historical convention. Not clinical positive-versus-negative sensitivity/specificity.

Unweighted Cohen kappa, not ordinal weighted kappa.

Cached-feature classification only. No image-detector, confidence-abstention or new distance-rejection filtering. No independent clinical validation.

Distance-weighted k-NN can obtain perfect apparent training fit because each training row is its own zero-distance neighbor. This does not establish generalization. Use the development test results to discuss observed weaknesses, and a new specimen-independent test set for final claims.

All 50 historical per-analyte metric values reproduced within 1e-12; confusion matrix totals reconciled.

Run: `.venv/Scripts/python.exe pipeline/evaluate_knn_training_metrics.py`
