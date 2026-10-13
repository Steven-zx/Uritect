# Runtime-consistent k-NN development: knn_runtime_metric_2026-10-13

**No classifier was promoted or installed. These are exploratory development results.**

The current Dart detector rechecked 210 retained photographs: 188 geometric passes and 22 exclusions pending review. After conservative cross-batch participant-token grouping, known-alias linkage and removal of inspected-confirmation tokens, the safe training pool contained 77 photos; the paired comparison used 70 development photos from 47 inferred groups. The original 112 confirmation events were not evaluated again. Identities remain provisional.

Each outer group fold selected settings using only inner training/validation folds. Training-only scaling, within-class shrinkage distance, raw/normalized circular hue and saturation/value combinations were compared. Reference labels were unchanged. Sensitivity/specificity below are macro one-versus-rest category metrics, not disease-detection performance. Kappa is a coefficient. Absent categories cannot support a sensitivity claim.

| Analyte | Arm | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen’s kappa |
|---|---|---:|---:|---:|---:|---:|
| Leukocytes | baseline | 60.00% | 44.11% | 42.97% | 84.17% | 0.2238 |
| Leukocytes | runtime_fixed | 47.14% | 19.35% | 23.22% | 79.66% | -0.0339 |
| Leukocytes | nested_candidate | 68.57% | 60.36% | 58.19% | 88.96% | 0.4568 |
| Nitrite | baseline | 97.14% | 49.28% | 50.00% | 50.00% | 0.0000 |
| Nitrite | runtime_fixed | 97.14% | 49.28% | 50.00% | 50.00% | 0.0000 |
| Nitrite | nested_candidate | 100.00% | 100.00% | 100.00% | 100.00% | 1.0000 |
| Urobilinogen | baseline | 75.71% | 52.38% | 54.59% | 81.84% | 0.1263 |
| Urobilinogen | runtime_fixed | 77.14% | 62.21% | 61.00% | 84.40% | 0.2689 |
| Urobilinogen | nested_candidate | 92.86% | 90.48% | 89.74% | 95.90% | 0.8096 |
| Protein | baseline | 91.43% | 31.84% | 33.33% | 83.33% | 0.0000 |
| Protein | runtime_fixed | 91.43% | 31.84% | 33.33% | 83.33% | 0.0000 |
| Protein | nested_candidate | 90.00% | 46.34% | 45.10% | 88.13% | 0.3185 |
| pH | baseline | 72.86% | 32.44% | 33.62% | 90.42% | 0.3044 |
| pH | runtime_fixed | 74.29% | 28.12% | 28.11% | 87.83% | 0.1645 |
| pH | nested_candidate | 65.71% | 26.26% | 26.48% | 87.43% | 0.0919 |
| Blood | baseline | 92.86% | 75.33% | 70.63% | 90.21% | 0.5098 |
| Blood | runtime_fixed | 90.00% | 65.47% | 62.70% | 87.57% | 0.3137 |
| Blood | nested_candidate | 91.43% | 76.19% | 76.19% | 92.06% | 0.5238 |
| Specific Gravity | baseline | 65.71% | 70.38% | 68.97% | 93.52% | 0.5399 |
| Specific Gravity | runtime_fixed | 61.43% | 40.45% | 41.18% | 92.60% | 0.4749 |
| Specific Gravity | nested_candidate | 57.14% | 40.72% | 41.23% | 91.99% | 0.4256 |
| Ketone | baseline | 65.71% | 58.00% | 57.82% | 85.94% | 0.1608 |
| Ketone | runtime_fixed | 68.57% | 44.68% | 50.34% | 83.45% | 0.0090 |
| Ketone | nested_candidate | 64.29% | 59.06% | 59.52% | 86.51% | 0.1830 |
| Bilirubin | baseline | 70.00% | 47.70% | 48.81% | 85.50% | 0.4224 |
| Bilirubin | runtime_fixed | 74.29% | 49.64% | 50.69% | 86.86% | 0.4899 |
| Bilirubin | nested_candidate | 80.00% | 54.94% | 55.44% | 90.35% | 0.6154 |
| Glucose | baseline | 95.71% | 49.44% | 50.00% | 87.50% | 0.3913 |
| Glucose | runtime_fixed | 94.29% | 24.26% | 25.00% | 83.33% | 0.0000 |
| Glucose | nested_candidate | 94.29% | 24.81% | 25.00% | 95.11% | 0.4093 |

## Whole-scan development comparison

| Arm | Individual-analyte accuracy | All-ten accuracy | Feature-stage retake rate | All-ten accuracy among accepted scans |
|---|---:|---:|---:|---:|
| baseline | 78.71% | 8.57% | 72.86% | 15.79% |
| runtime_fixed | 77.57% | 11.43% | 81.43% | 23.08% |
| nested_candidate | 80.43% | 7.14% | 24.29% | 7.55% |

Feature-stage acceptance assumes known localization. It is not actual camera/gallery acceptance, measured phone latency, clinical accuracy or an untouched final evaluation. These percentages must not replace historical figures from different photo cohorts. The baseline is a development-only refit using recorded classifier settings; it is not a test of the installed model fitted on all its data.

## Decisions

- **Leukocytes:** Paired group accuracy interval includes zero; female_le_small_or_higher specificity decreased; male_le_trace_or_higher specificity decreased; analytical_any_nonnegative specificity decreased; Nested folds selected different recipes; no stable single deployment recipe.
- **Nitrite:** Paired group accuracy interval includes zero; Nested folds selected different recipes; no stable single deployment recipe.
- **Urobilinogen:** analytical_above_baseline_category specificity decreased; Nested folds selected different recipes; no stable single deployment recipe.
- **Protein:** accuracy decreased/undefined; Paired group accuracy interval includes zero; renal_protein_0_3_or_higher specificity decreased; analytical_any_nonnegative specificity decreased; Nested folds selected different recipes; no stable single deployment recipe.
- **pH:** accuracy decreased/undefined; macro_f1_supported_reference_classes decreased/undefined; macro_sensitivity decreased/undefined; macro_specificity decreased/undefined; cohens_kappa decreased/undefined; Paired group accuracy interval includes zero; No macro F1 improvement; Nested folds selected different recipes; no stable single deployment recipe.
- **Blood:** accuracy decreased/undefined; Paired group accuracy interval includes zero; analytical_any_nonnegative specificity decreased; Nested folds selected different recipes; no stable single deployment recipe.
- **Specific Gravity:** accuracy decreased/undefined; macro_f1_supported_reference_classes decreased/undefined; macro_sensitivity decreased/undefined; macro_specificity decreased/undefined; cohens_kappa decreased/undefined; Paired group accuracy interval includes zero; No macro F1 improvement; Nested folds selected different recipes; no stable single deployment recipe.
- **Ketone:** accuracy decreased/undefined; Paired group accuracy interval includes zero; analytical_any_nonnegative specificity decreased; Nested folds selected different recipes; no stable single deployment recipe.
- **Bilirubin:** Paired group accuracy interval includes zero; Nested folds selected different recipes; no stable single deployment recipe.
- **Glucose:** accuracy decreased/undefined; macro_f1_supported_reference_classes decreased/undefined; macro_sensitivity decreased/undefined; Paired group accuracy interval includes zero; No macro F1 improvement; Nested folds selected different recipes; no stable single deployment recipe.

No candidate passed promotion. The first broad comparison improved some individual categories but worsened all-ten accuracy. The rule-constrained follow-up retained baseline when inner-fold all-five/rule criteria failed, but outer-fold pH still regressed. Urobilinogen, ketone and bilirubin showed promising category gains; uncertainty, recipe instability or threshold-specific errors prevent treating those gains as established app improvements. Ordered-level aggregation did not improve pH/SG.

The paired pH references contain 53 at 5.0, 15 at 6.0, one at 7.0 and one at 8.5; there are no 6.5 references in this cohort. Nitrite has only two positive photos. Repeated images and synthetic perturbations cannot establish independent rare-category performance.

Next useful work is traceable review of pH/SG pad crops and their original reference readings, followed by checking the exact bottle chart and controlled calibration. Correct verified label/localization mistakes only with source evidence. More tuning on this inspected cohort is not independent confirmation. No labels were guessed, confidence threshold lowered, originals deleted or binary values modified.

[Machine-readable results](RESULTS.json) · [Five-metric CSV](FIVE_METRICS.csv) · [Analysis plan](ANALYSIS_PLAN.json)
