# Focused pH / specific-gravity audit

Reference labels and app model are unchanged. Only the prior 453-event development subset enters error ranking and nested model selection. The already-inspected confirmation subset is not evaluated again. Filename-inferred identities remain unverified across batches.

[Visual review](FOCUSED_REVIEW.html) · [Editable review CSV](FOCUSED_REVIEW.csv) · [Audit summary](AUDIT_SUMMARY.json)

The training and app color extractors differ: OpenCV quantized arithmetic hue/all-pixel means versus float corrected RGB/circular hue/strided sampling. Quantities below use identical supplied ROIs and gains; they do not establish decoder, resize, AWB-estimator or full detector parity.

## pH

Reference counts: {'5.0': 324, '6.0': 101, '7.0': 14, '7.5': 6, '8.5': 4, '6.5': 4}. Supporting inferred groups: {np.str_('8.5'): 2, np.str_('6.0'): 56, np.str_('7.0'): 8, np.str_('7.5'): 3, np.str_('5.0'): 178, np.str_('6.5'): 3}.

Failed predictions: {'n': 121, 'boundary_supported': 67, 'color_support_below_95': 0, 'median_neutral_fraction': 0.0, 'median_feature_hue_mismatch': 0.22716141694360203, 'hue_mismatch_above_5_degrees': 2}. Correct controls: {'n': 332, 'boundary_supported': 184, 'color_support_below_95': 0, 'median_neutral_fraction': 0.0, 'median_feature_hue_mismatch': 0.15264804783220143, 'hue_mismatch_above_5_degrees': 10}.

## Specific Gravity

Reference counts: {'1.025': 113, '1.010': 73, '1.015': 65, '1.020': 48, '1.005': 35, '1.030': 119}. Supporting inferred groups: {np.str_('1.025'): 64, np.str_('1.030'): 64, np.str_('1.020'): 26, np.str_('1.005'): 20, np.str_('1.015'): 36, np.str_('1.010'): 40}.

Failed predictions: {'n': 192, 'boundary_supported': 89, 'color_support_below_95': 0, 'median_neutral_fraction': 0.0, 'median_feature_hue_mismatch': 0.22954512524773918, 'hue_mismatch_above_5_degrees': 5}. Correct controls: {'n': 261, 'boundary_supported': 127, 'color_support_below_95': 0, 'median_neutral_fraction': 0.0, 'median_feature_hue_mismatch': 0.15242923658979635, 'hue_mismatch_above_5_degrees': 9}.

## Nested development comparison

| Analyte | Baseline accuracy | Candidate accuracy | Baseline macro F1 | Candidate macro F1 | Baseline macro sensitivity | Candidate macro sensitivity | Engineering screen |
|---|---:|---:|---:|---:|---:|---:|---|
|pH|73.29%|69.09%|0.2493|0.4283|0.2357|0.4978|False|
|Specific Gravity|57.62%|55.63%|0.5221|0.5156|0.5164|0.5140|False|

The candidate column is the nested selection procedure: each outer fold selects its own configuration using inner training/validation folds only. It is not a single frozen deployable model. All five metrics, class confusion counts, fold configurations and ranked inner comparisons are in NESTED_DEVELOPMENT_RESULTS.json.

Local color-boundary refinement is experimental and falls back to the existing ROI when evidence is weak. It never changes physical analyte order. Brightness is tested separately from hue/saturation; backing calibration uses neutral inter-pad pixels, not other reagent categories. No threshold is described as clinically safe.

Deployment remains unchanged until a stable single recipe passes engineering comparison and Python/Dart parity with regenerated model-bound distance support. Reference-label or reaction-time errors require actual reference evidence; none are fabricated by this audit.
