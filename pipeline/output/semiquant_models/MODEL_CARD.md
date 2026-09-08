# Uritect Production Semiquant Model Card

Model version: `production_semiquant_knn_markerless_roi_topfix_v3_20260908`

Scope: 10-parameter semiquant urine dipstick classification only.

The production claim excludes binary screening, Bayesian/posterior risk scoring,
unsupported symptom weights, priors, and combined disease-probability thresholds.

Frozen artifacts:

- Python model directory: `pipeline/output/semiquant_models`
- Android model asset: `uritect_app/assets/production_semiquant_model.json`
- Export script: `pipeline/export_production_model_json.py`
- Parity check: `pipeline/validate_production_json_model.py`

Training feature file:

- Raw input: `pipeline/dataset/features_normalized_hsv.csv`
- De-duplicated production input:
  `pipeline/dataset/features_normalized_hsv_deduped_production.csv`
- Raw rows: 7,840 semiquant analyte rows
- De-duplicated rows: 7,840 semiquant analyte rows
- Duplicates removed by exact specimen/light/analyte/feature key: 0
- Rejected capture bursts during corrected markerless ingest: 257
- Included sources: Laua-an 2026-07-30 plus Cabatuan 2026-07-15 and
  2026-07-17 cleaned semiquant packages only.

Leakage control:

- Final metric evaluation uses specimen-grouped splitting.
- The split group is `specimen_group`, derived from source and event identity
  after removing light-name tokens.
- All rows from the same specimen group stay on one side of the split.

Corrected metric evaluation:

- Individual-analyte accuracy: 82.52%
- Macro analyte accuracy: see `pipeline/output/production_grouped_evaluation.json`
- Whole-scan all-10-correct accuracy: 17.18%

Confidence abstain policy:

- Android production asset requires every analyte prediction to reach confidence
  threshold `0.45`.
- On the same grouped split, this accepts 73.62% of scans and raises accepted
  individual-analyte accuracy to 83.75%, with 19.17% all-10-correct accuracy.
  See `pipeline/output/whole_scan_optimization_final_knn_grouped.json`.

Important interpretation:

- The 80% target is currently met for individual-analyte predictions.
- It is not met if the metric is whole-scan accuracy requiring all ten analytes
  correct in the same scan.

Runtime path:

- Android app path: `uritect_app/lib/services/local_scan_analysis_service.dart`
- No Python server is required for Android scanning.
- Feature space: `normalized_hsv`
- Localization: markerless strip detection
- ROI method: detected pad column plus ten reagent-pad row centers from
  background-relative color, saturation, and chroma activity. A scan is rejected
  when ten reliable pad rows cannot be detected.
- AWB method: gray-world correction from low-saturation neutral strip/plastic
  pixels near the detected strip.

Invalid-image handling:

- Rejects unreadable/blank images.
- Rejects excessive blur.
- Rejects missing, partial, implausibly wide, or wrong-geometry strip
  candidates.
- Rejects inconsistent pad spacing and low reagent-color signal.

Clinical output:

- The app keeps clinical interpretation as separate rule-based outputs:
  localized UTI findings, systemic UTI warnings, renal follow-up, and metabolic
  follow-up.
- No combined posterior probability is calculated.
