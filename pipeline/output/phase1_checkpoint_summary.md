# Phase 1 Checkpoint Summary

Generated at: 2026-05-11T04:49:18.021163+00:00

## Scope
- Official Phase 1 dataset: 175 IDs
- Validated unique IDs: 175
- Extra IDs beyond 170: 171, 172, 173, 174, 175
- Canonicalization issues: 1
- Invalid values: 1

## Baseline
- Strict accuracy: 0.2320 | F1-macro: 0.1744 | Kappa: 0.2157
- Coverage: 1.0000 on 250 evaluated samples

## Scorecard
| Metric | Value | Objective | Pass |
|---|---:|---:|:---:|
| overall_accuracy_strict_multiclass | 0.232000 | 0.800000 | NO |
| overall_adjacent_accuracy | 0.564000 | 0.800000 | NO |
| overall_coarse_normal_abnormal_accuracy | 0.684000 | 0.800000 | NO |
| Nitrite_adjacent_accuracy | 1.000000 | 0.800000 | YES |
| Protein_coarse_normal_abnormal_accuracy | 0.800000 | 0.800000 | YES |
| pH_coarse_normal_abnormal_accuracy | 0.800000 | 0.800000 | YES |
| Ketone_coarse_normal_abnormal_accuracy | 0.800000 | 0.800000 | YES |
| Glucose_coarse_normal_abnormal_accuracy | 0.800000 | 0.800000 | YES |

## Tuning
- Best candidate: event_center_hsv=off, distance_weight_profile=analyte-v1
- Best overall: Acc=0.2229, F1-macro=0.1187, Kappa=0.2059
- F1-macro improvement over baseline: -0.0558

## Feature-Space Hotspots
| Analyte | Level A | Level B | Distance |
|---|---|---|---:|
| Blood | Hemolyzed 10 | Moderate 80 | 0.022185 |
| Urobilinogen | 128 | 64 | 0.029971 |
| pH | 8.0 | 8.5 | 0.032964 |
| Glucose | 30 ++ | 60 +++ | 0.033300 |
| Protein | 0.3 | 1.0 | 0.034570 |
| Leukocytes | Moderate 125 | Small 70 | 0.038643 |
| Nitrite | Neg | Positive | 0.048426 |
| Specific Gravity | 1.025 | 1.030 | 0.050393 |

## Checkpoint Decision
- Ready for the 50% progress report as a frozen Phase 1 baseline.

## Next Objectives
- Treat more sample collection as Phase 2, not a blocker for the current checkpoint.
- Mine the hotspot analytes and closest centroid pairs for targeted hard-case retraining.
- Keep the frozen protocol fixed while the report is being prepared.
