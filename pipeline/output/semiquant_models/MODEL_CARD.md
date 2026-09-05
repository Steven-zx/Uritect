# Uritect Semiquant KNN Model Card

Model version: `optimized_semiquant_knn_v1_lauaan_20260830`

Scope: 10-parameter semiquant urine dipstick classification only.

Binary screening, posterior risk scoring, and binary fallback are not part of
this model claim.

Training feature file:

- `pipeline/dataset/features_normalized_hsv.csv`
- Rows: 19,840 semiquant analyte rows
- Events per analyte: 1,984
- Includes Laua-an data from `LAUAAN_20260730_ID_CLEANED_2026-07-30.zip`

Metric target:

- Overall 10-analyte semiquant accuracy >= 80%

Current metric evaluation:

- Overall cross-validated accuracy: 82.10%
- Macro average by analyte: 82.10%

Lowest-performing analytes:

- Specific Gravity: 56.00%
- pH: 74.30%
- Bilirubin: 75.60%

App runtime path:

- `pipeline/scan_dipstick.py`
- Preferred model source: `pipeline/output/semiquant_models`
- Feature space: `normalized_hsv`
- Primary Laua-an localization method: markerless strip localization
- ROI method: vertical strip-edge detection plus 10-pad grid over the detected
  reactive pad stack
- AWB method: gray-world correction from low-saturation neutral strip/plastic
  pixels around the detected strip

Legacy macro-marker localization is retained only as a fallback for older
images that still include the black/white marker. It is not the primary method
for the Laua-an validation path.

Next validation step:

- Add Cabatuan as an external holdout dataset.
- Train/freeze without using Cabatuan holdout rows.
- Run `validate_app_scan_batch.py` against Cabatuan images and labels.
