# Repeated pH 5.0 investigation

Investigated 10 October 2026 against the frozen 1.5.0+16 sources and existing development evidence. Production sources and APK were not changed.

## Code trace

- Capture submits its image path to a new AnalyzingPage. Analysis reads the file and extracts pad features.
- LocalScanAnalysisService predicts each analyte from its own features, using the model's k-NN votes. The pH result is prediction.level.
- Display normalization only converts Neg to Negative, trims text, and makes empty labels Unavailable. It does not replace pH with 5.0.
- DipstickResultsTable displays row.result. The 5.0 in the reference range is a range endpoint, not a result default.

This trace does not reproduce a user-specific stale-image scenario, but finds no fixed pH 5.0 assignment in the current analysis/display path.

## Reproduced evidence

The three-fold inferred-identity grouped baseline predicted pH 5.0 in 724/784 out-of-fold predictions (92.35%). Reference labels were 5.0 in 553/784 captures (70.54%). Of 186 reference pH 6.0 captures, 170 were predicted as 5.0. The classifier can output other levels: predicted counts were 39 at 6.0, one at 6.5, nine at 7.0, ten at 7.5, and one at 8.5. This is a strong prediction bias, not a constant output function.

All six accepted photographs in the release development runtime regression returned pH 5.0. Five match their recorded dataset pH labels. The accepted `uritect_2026-7-15_Cabatuan_011_Daylight` image returned 5.0 despite its recorded reference label of 7.5. This establishes an image-path classification mismatch against the recorded label. The label still needs adjudication against the exact strip and reading protocol.

Sources: experiment.json; ../knn_five_metric_evaluation_2026-10-10/metrics.json; ../../../output/device_pilot/2026-10-10/1.5.0+16/runtime_regression.json; constructed features_normalized_hsv_deduped_production.csv.

## What is known and what remains

The user reports that a medical technologist read pH 6.5 while the app displayed 5.0. No photograph is available. This is a reported discrepancy, not an image-reproduced case or independently adjudicated evaluation record. Do not add it to scored accuracy denominators. In the grouped development baseline, nine of eleven reference pH 6.5 captures were predicted as 5.0, and none were correctly classified as 6.5.

Training imbalance and poor non-5.0 generalization are demonstrated. Their relative contribution versus pad localization, white balance/feature extraction, physical strip mismatch, reading timing or reference-label errors has not been isolated for the user's phone captures. A verified non-5.0 photograph is needed to inspect the pH crop, extracted HSV, nearest-neighbor votes and displayed value together.

Do not force alternating pH values, add a result offset, or treat a changed display as improved classification. Small augmentation previously reduced exact-category accuracy. Preserve this release and its limitations until a better candidate passes specimen-grouped development evaluation plus image/runtime checks. Clinical performance requires new independent reference-adjudicated specimens.
