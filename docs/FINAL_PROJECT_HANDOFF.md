# URITECT Final Project Handoff

**Release candidate:** 1.4.0+5

**Finalization date:** 2026-10-01

**Scope:** Offline Android thesis prototype; ten-analyte semiquantitative URS-10T interpretation
**Android application ID:** `ph.edu.wvsu.uritect`

## What Is Finished

| Area | Final state | Evidence |
| --- | --- | --- |
| Dataset | Laua-an and Cabatuan packages cleaned, aligned, and ingested; exact-row deduplication applied | `pipeline/dataset/features_normalized_hsv_deduped_production.csv` |
| Leakage control | Specimen-grouped 80/20 split; lighting variants stay together | `pipeline/output/production_grouped_metrics_complete.json` |
| Visual classifier | Ten per-analyte k-NN configurations frozen | `pipeline/output/semiquant_models` |
| Android inference | Model and image pipeline execute locally in Dart | `uritect_app/lib/services/local_scan_analysis_service.dart` |
| Network independence | No Internet permission in the production manifest; no HTTP scan path | `uritect_app/android/app/src/main/AndroidManifest.xml` |
| AWB | Neutral strip/plastic gray-world normalization | local scan service |
| ROI | Markerless strip localization and ten-pad alignment validation | local scan service |
| Invalid scans | Blank, blurred, dark, overexposed, partial, ambiguous, implausible, and low-confidence captures rejected | local scan service |
| Confidence abstention | Every analyte must meet 0.45 confidence | model asset and grouped optimization report |
| UTI interpretation | Separate female v1.1 and male v0.1 research models; sex-specific gates and one-factor anti-duplication hierarchy; no probability bands | `screening_fusion.dart` and sex-specific v1.2 specification |
| Renal interpretation | Separate deterministic v1.1 rule engine with all triggered IDs and final action | `renal_followup.dart` |
| Clinical UI | Separate findings, systemic warning, and renal follow-up; action wording replaces risk bands | results pages |
| Automated tests | 59 tests pass across sex-specific Bayesian, renal, invalid-scan, persistence, navigation, and phone-width UI behavior | `uritect_app/test` |
| Release integrity | Final checksums stored in a machine-readable manifest | `output/release/URITECT_FINAL_RELEASE_MANIFEST.json` |

## Final Metrics

All metrics below use the frozen grouped split. They evaluate reagent-pad class
prediction, not UTI diagnosis or renal-disease diagnosis.

| Analyte | Accuracy | Macro F1 | Macro sensitivity | Macro specificity | Kappa |
| --- | ---: | ---: | ---: | ---: | ---: |
| Leukocytes | 68.10% | 44.50% | 46.72% | 85.74% | 0.315 |
| Nitrite | 99.39% | 83.18% | 75.00% | 75.00% | 0.664 |
| Urobilinogen | 82.82% | 64.57% | 62.15% | 62.15% | 0.309 |
| Protein | 87.73% | 25.93% | 24.56% | 83.34% | 0.253 |
| pH | 81.60% | 57.49% | 52.25% | 87.79% | 0.357 |
| Blood | 93.25% | 90.69% | 88.93% | 91.15% | 0.714 |
| Specific Gravity | 58.90% | 55.57% | 56.43% | 91.54% | 0.494 |
| Ketone | 73.01% | 67.52% | 66.81% | 66.81% | 0.367 |
| Bilirubin | 87.12% | 85.39% | 84.65% | 84.65% | 0.708 |
| Glucose | 93.25% | 37.41% | 32.38% | 87.75% | 0.457 |

Aggregate results:

- 82.52% individual-analyte accuracy (1,345/1,630).
- 17.18% whole-scan all-ten-correct accuracy (28/163).
- 61.22% mean per-analyte macro F1.
- 58.99% mean per-analyte macro sensitivity.
- 81.59% mean per-analyte macro specificity.
- 0.464 mean per-analyte Cohen's kappa.
- At confidence 0.45: 73.62% scan acceptance, 83.75% accepted
  individual-analyte accuracy, and 19.17% accepted all-ten-correct accuracy.

Rare semiquantitative classes have small support, so accuracy can look strong
while macro F1, sensitivity, or kappa remains modest. Report the complete table
and class supports; do not report only the 82.52% aggregate.

## Objective Status

| Objective | Status before human evaluation |
| --- | --- |
| 1. Calibrated combined dataset under three lights | Engineering work complete. The manuscript must accurately enumerate volunteer/control composition and collection provenance. |
| 2. Strip-plastic-referenced AWB | Implemented. Final wording must match the neutral strip/plastic gray-world method. |
| 3. Offline automated ten-pad ROI | Implemented markerlessly. Real-device ROI overlay acceptance remains a manual verification gate. |
| 4. Per-analyte k-NN plus UTI/renal interpretation | Implemented and fully re-evaluated. Bayesian applies to gated UTI only; renal is rule-based. |
| 5. ISO/IEC 25010-guided app evaluation | Instrument and release are ready. Not complete until 10 medtechs test the app and results are analyzed. |

## Do Not Use as Final Evidence

Files under `pipeline/output` containing names such as `phase1`, `binary`,
`performance_drop`, `legacy`, or earlier holdout experiments are development
history. They must not replace the frozen reports named in this handoff. The old
Bayesian v1.0 PDF and the superseded weight-table filename are also not final.

## Remaining Human Work

1. Copy the physical URS-10T manufacturer, catalog number, lot, expiry, IFU
   revision, reaction times, and category chart into the sign-off documents.
2. Obtain the two-medtech sex-specific Bayesian parameter content review using v1.3.
3. Obtain final physician comparison/sign-off for renal v1.1 and the safety
   wording actually displayed by the app.
4. Run the real-device acceptance protocol on the target phones: airplane mode,
   valid scans, invalid-image challenge set, ROI overlays, latency, storage,
   deletion, and privacy behavior.
5. Have 10 registered medtechs complete the final app evaluation form and
   enter responses in
   `output/forms/URITECT_ISO25010_MedTech_App_Evaluation_Data_Template.csv`.
   Run `python pipeline/analyze_medtech_app_evaluation.py` to produce the
   descriptive analysis without inventing a post-hoc pass threshold.
6. Revise the manuscript using `MANUSCRIPT_FINAL_REVISION_GUIDE.md`.

Culture-confirmed prospective cases and statistical calibration review are
required before describing the Bayesian output as a validated clinical
probability. This is a post-thesis clinical validation boundary, not a missing
software feature.
