# Corrected-model settings: five-metric grouped baseline evaluation

This is the baseline arm of the recorded direction-verified improvement experiment, not the uninstalled candidate arm. The experiment used 565 photo events: 453 development and 112 confirmation events. It refit the baseline model settings on development data. The installed full-data model includes all 565 events, so these results are not an independent test of that frozen APK. The historical data have been inspected; cross-batch specimen identity is unverified.

| Analyte | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen's kappa |
|---|---:|---:|---:|---:|---:|
| Leukocytes | 66.07% | 40.33% | 43.83% | 85.48% | 0.2834 |
| Nitrite | 98.21% | 49.55% | 50.00% | 50.00% | 0.0000 |
| Urobilinogen | 78.57% | 56.25% | 55.65% | 82.26% | 0.1340 |
| Protein | 82.14% | 24.69% | 24.00% | 84.13% | 0.0812 |
| pH | 66.96% | 40.55% | 40.59% | 87.79% | 0.1450 |
| Blood | 86.61% | 41.14% | 41.10% | 94.22% | 0.5859 |
| Specific Gravity | 69.64% | 67.02% | 66.60% | 94.77% | 0.6163 |
| Ketone | 74.11% | 70.53% | 69.78% | 89.93% | 0.4196 |
| Bilirubin | 83.93% | 82.86% | 82.86% | 91.43% | 0.6571 |
| Glucose | 95.54% | 43.28% | 43.75% | 91.51% | 0.5679 |

Combined individual-analyte accuracy: **80.18%**. All-ten-correct accuracy: **12.50%**.

Macro sensitivity and specificity are unweighted one-vs-rest category summaries with defined denominators; class support is recorded in the JSON. They are not UTI or kidney-disease sensitivity/specificity. Nitrite has only two positive reference photos; both were missed by the baseline, giving positive-class sensitivity of 0% despite 98.21% category accuracy. Repeat photos do not establish independent biological support.

Feature classification is evaluated here. Detector failures, timing, distance rejection and clinical eligibility are not reproduced as end-to-end acceptance. Training resubstitution with self-neighbors is not evidence of generalization.

Frozen release reference: 1.5.17+35, direction_verified_experimental_v1_20261011. The ongoing legacy-dataset comparison is separate and is not included in these results.

Source: `pipeline/output/knn_improvement_2026-10-11/CONFIRMATION_RESULTS.json`. SHA-256: `25df115a9bdf254c94333fd93e07246b0dfd0cc85668c036cf154b9116e4fe00`.
