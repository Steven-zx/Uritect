# Legacy dataset cleaning and development comparison

Original images, binary values and semiquantitative reference categories are preserved. Printed color charts, unsupported converted references and conflicting labels do not become specimen training data.

- 2,028 unique images reviewed, including 1,974 archive photos and 54 additional unpacked originals.
- 3,846 archive occurrences; 1,872 repeated export occurrences consolidated.
- 210 photographs qualify for the versioned training pool, with 175 within-batch reference groups. These are not established independent-patient counts.
- 12 retained photos require archival context crops. This does not demonstrate that the unchanged app accepts their uncropped originals.
- Source integrity: 202 protected files checked; all unchanged: True.

## Photo dispositions

| Status | Photos |
|---|---:|
| excluded_geometry_or_quality | 265 |
| geometry_only_not_training | 7 |
| reference_only | 193 |
| excluded_decode_or_size | 1 |
| excluded_sampling_boundary_or_quality | 129 |
| excluded_app_quality_or_geometry | 1219 |
| excluded_reference_conflict | 4 |
| accepted_training | 210 |

## Paired exploratory development comparison

Paired 3-fold grouped development comparison on the freshly verified subset of the original 453 target development events. Both arms see identical freshly audited validation-pad features. Baseline is refit using recorded current-training features; candidates train only freshly audited photos. Original 112 confirmation events and related known groups/tokens excluded. Fixed current per-analyte k, metric and transform. No hyperparameter or confidence-threshold search.

The paired target comprises 140 freshly audited development photos; 313 original development photos did not enter this paired target. The 112-photo historical confirmation subset was not evaluated. The results below are not directly comparable with older 79.92% or 82.52% figures from different photos/splits.

Each cell shows baseline → candidate accuracy. The two candidates use cleaned current-only data and cleaned current-plus-legacy data. Selection also considers macro F1, macro sensitivity/specificity, supported downstream-threshold errors and paired group uncertainty; accuracy alone cannot qualify a candidate.

| Analyte | Cleaned current-only | Cleaned + legacy | Qualified recipe |
|---|---:|---:|---|
| Leukocytes | 61.43% → 63.57% | 61.43% → 63.57% | baseline |
| Nitrite | 98.57% → 98.57% | 98.57% → 98.57% | baseline |
| Urobilinogen | 72.14% → 72.14% | 72.14% → 73.57% | baseline |
| Protein | 83.57% → 85.00% | 83.57% → 85.00% | baseline |
| pH | 77.14% → 76.43% | 77.14% → 75.00% | baseline |
| Blood | 95.00% → 91.43% | 95.00% → 91.43% | baseline |
| Specific Gravity | 60.00% → 55.00% | 60.00% → 55.00% | baseline |
| Ketone | 63.57% → 62.86% | 63.57% → 65.00% | baseline |
| Bilirubin | 76.43% → 70.71% | 76.43% → 69.29% | baseline |
| Glucose | 96.43% → 95.00% | 96.43% → 95.00% | baseline |

### Five metrics: baseline

| Analyte | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen's kappa |
|---|---:|---:|---:|---:|---:|
| Leukocytes | 61.43% | 37.24% | 35.72% | 85.29% | 0.2772 |
| Nitrite | 98.57% | 49.64% | 50.00% | 50.00% | 0.0000 |
| Urobilinogen | 72.14% | 53.25% | 55.95% | 82.38% | 0.1538 |
| Protein | 83.57% | 15.18% | 16.39% | 83.08% | -0.0177 |
| pH | 77.14% | 30.84% | 29.56% | 88.32% | 0.2045 |
| Blood | 95.00% | 80.27% | 71.95% | 93.98% | 0.7343 |
| Specific Gravity | 60.00% | 51.08% | 49.90% | 92.53% | 0.4642 |
| Ketone | 63.57% | 39.75% | 39.88% | 86.49% | 0.1919 |
| Bilirubin | 76.43% | 51.66% | 52.44% | 88.57% | 0.5414 |
| Glucose | 96.43% | 44.54% | 49.81% | 88.77% | 0.4337 |

### Five metrics: cleaned_current_only

| Analyte | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen's kappa |
|---|---:|---:|---:|---:|---:|
| Leukocytes | 63.57% | 26.10% | 27.85% | 86.28% | 0.3197 |
| Nitrite | 98.57% | 49.64% | 50.00% | 50.00% | 0.0000 |
| Urobilinogen | 72.14% | 58.13% | 58.54% | 83.41% | 0.2069 |
| Protein | 85.00% | 15.32% | 16.67% | 83.33% | 0.0000 |
| pH | 76.43% | 18.81% | 20.14% | 86.07% | 0.0257 |
| Blood | 91.43% | 52.26% | 50.30% | 90.78% | 0.5291 |
| Specific Gravity | 55.00% | 42.93% | 41.49% | 91.54% | 0.3937 |
| Ketone | 62.86% | 36.92% | 37.09% | 85.14% | 0.1176 |
| Bilirubin | 70.71% | 47.82% | 48.56% | 85.81% | 0.4309 |
| Glucose | 95.00% | 24.36% | 24.81% | 83.21% | -0.0082 |

### Five metrics: cleaned_plus_legacy

| Analyte | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Cohen's kappa |
|---|---:|---:|---:|---:|---:|
| Leukocytes | 63.57% | 26.42% | 28.16% | 86.47% | 0.3270 |
| Nitrite | 98.57% | 49.64% | 50.00% | 50.00% | 0.0000 |
| Urobilinogen | 73.57% | 61.22% | 60.86% | 84.34% | 0.2592 |
| Protein | 85.00% | 15.32% | 16.67% | 83.33% | 0.0000 |
| pH | 75.00% | 18.52% | 19.78% | 85.83% | 0.0033 |
| Blood | 91.43% | 52.26% | 50.30% | 90.78% | 0.5291 |
| Specific Gravity | 55.00% | 42.93% | 41.49% | 91.54% | 0.3937 |
| Ketone | 65.00% | 37.57% | 37.83% | 85.51% | 0.1452 |
| Bilirubin | 69.29% | 46.86% | 47.66% | 85.17% | 0.4045 |
| Glucose | 95.00% | 24.36% | 24.81% | 83.21% | -0.0082 |

| Joint measure | Baseline | Qualified combination |
|---|---:|---:|
| individual_accuracy | 78.43% | 78.43% |
| all_ten_accuracy | 10.71% | 10.71% |
| feature_stage_retake_rate | 64.29% | 64.29% |
| feature_stage_accepted_all_ten_accuracy | 22.00% | 22.00% |

**Promotion decision:** Keep the current app model. The expanded pool did not qualify for promotion.

No analyte passed the predeclared paired engineering screen

## Limits and retained artifacts

- Every original remains intact. Exclusion means exclusion from training, not deletion or a claim that a biological specimen was invalid.
- Boundary/contrast/focus thresholds are conservative dataset engineering screens. Very pale legitimate pads may remain unconfirmed; exclusions and selection bias must be disclosed.
- The visual spot-check found an off-strip first ROI and a partial endpoint ROI. Background-presence and color-boundary checks reject these rather than accepting the detector count as proof.
- Exact current Dart color math is used for admitted feature rows. Native full-photo checks and context-crop results are retained separately.
- Original binary BATCH values are never converted or modified. Their photos remain available for geometry research; a separately traceable per-pad reference is needed for semiquantitative training.
- Historical color-chart cyclic labels are not measured specimen observations. Duplicate exports and repeated photographs do not add biological independence.
- Cross-batch identity and clinical reference adjudication remain unresolved. The inspected historical data cannot become a new untouched external validation set.
- No confidence threshold, support rejection, pad order, physical reading-time rule, or clinical safety gate is relaxed.

Private local outputs: `PHOTO_REVIEW.html`, `FINAL_PHOTO_AUDIT.csv`, `CLEAN_FEATURES.csv`, `cleaned/`, original/crop runtime receipts and protected-input snapshots. Aggregate comparison details: `DEVELOPMENT_COMPARISON.json`. Reference trace: `LABEL_SOURCE_REVIEW.md`.
