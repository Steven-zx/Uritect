# Specific gravity and pH development experiment

Three outer folds; three inner folds. StratifiedGroupKFold(shuffle=True). Group = batch plus filename-inferred participant identity, grouping lighting and repeated specimens. Provisional identity only; cross-batch identity unverified. All current data are development data. Selection uses inner macro F1, with inner accuracy as tie-breaker. Outer predictions never select candidates.

Training only: two extra copies per row, saturation multiplied by .99/1.01 and value by .98/1.02, bounded to [0,1]. Hue unchanged. Heuristic, not demonstrated label-preserving physical lighting variation; not additional biological data.

Macro F1 includes all seven schema classes with zero for undefined F1, including unrepresented SG 1.000 and pH 8.0. This convention differs from the historical union-of-observed/predicted-label report. Sensitivity/specificity averages exclude undefined denominators and class support is exposed. No quality/confidence/distance filtering. Exact semiquantitative categories, not disease detection.

| Analyte | Procedure | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Kappa |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Specific Gravity | baseline | 57.14% | 43.85% | 50.95% | 92.47% | 0.4664 |
| Specific Gravity | matched_baseline_augmentation | 55.48% | 42.94% | 50.17% | 92.26% | 0.4492 |
| Specific Gravity | tuning_without_augmentation | 57.91% | 44.45% | 51.44% | 92.58% | 0.4751 |
| Specific Gravity | tuning_with_augmentation | 57.53% | 43.94% | 50.95% | 92.51% | 0.4701 |
| pH | baseline | 70.92% | 30.69% | 33.24% | 87.25% | 0.1354 |
| pH | matched_baseline_augmentation | 69.13% | 38.86% | 42.91% | 87.16% | 0.1244 |
| pH | tuning_without_augmentation | 64.29% | 38.37% | 43.81% | 87.55% | 0.1329 |
| pH | tuning_with_augmentation | 64.29% | 38.37% | 43.81% | 87.55% | 0.1329 |

These scores use a different grouping/split from historical 58.90% SG and 81.60% pH. Compare baseline versus candidate procedures within this experiment only. No deployable model is selected or exported. Nested evaluation describes a tuning procedure whose folds can select different configurations. Independent adjudicated specimens and physical-image/runtime validation remain required before promotion.

## Data and next experiments

Specific Gravity capture counts: {np.str_('1.010'): 133, np.str_('1.025'): 180, np.str_('1.020'): 83, np.str_('1.015'): 127, np.str_('1.005'): 61, np.str_('1.030'): 200}

Specific Gravity provisional identity counts: {'1.000': 0, '1.005': 27, '1.010': 55, '1.015': 56, '1.020': 36, '1.025': 81, '1.030': 88}

pH capture counts: {np.str_('5.0'): 553, np.str_('6.0'): 186, np.str_('7.5'): 10, np.str_('7.0'): 20, np.str_('8.5'): 4, np.str_('6.5'): 11}

pH provisional identity counts: {'5.0': 242, '6.0': 79, '6.5': 6, '7.0': 10, '7.5': 4, '8.0': 0, '8.5': 2}

pH 8.5 has only two inferred identities and four captures. Three-fold inner stratification emitted rare-class warnings; some partitions cannot contain every class. SG 1.000 and pH 8.0 have no examples. Do not claim performance for these absent levels.

Matched small S/V augmentation is an ablation, not proof of physically correct color changes. No hue jitter, SMOTE or synthetic class creation was used. More aggressive color augmentation requires actual repeated captures under known conditions to establish label preservation.

Priorities: verify participant/specimen identities and exact-strip category mappings; collect independent reference-adjudicated examples of rare/missing pH levels; review pad crops, reading time and lighting for SG adjacent-level mistakes. Extract aligned crop/illumination features from verified original images before proposing a different feature representation. Re-run grouped development evaluation and then an untouched independent final evaluation. The slight SG gain and pH accuracy/F1 trade-off do not justify replacing the current production model.

Full fold scores, selected settings, class supports and confusion matrices: experiment.json.
