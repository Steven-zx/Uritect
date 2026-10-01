# URITECT Final Engineering Brief

This file is the authoritative engineering summary for the final thesis build.
Older experimental reports remain available for traceability but do not define
the production system or its performance claims.

## Final System

URITECT 1.4.0 is an offline Android clinical decision-support prototype for
markerless, semiquantitative interpretation of ten URS-10T reagent pads. Image
processing, normalized HSV feature extraction, per-analyte k-nearest neighbors
classification, UTI interpretation, renal follow-up rules, and local history
storage run on the device. The production manifest requests no Internet
permission and the scan path has no Python-server dependency.

## Frozen Components

- Visual model: `production_semiquant_knn_markerless_roi_topfix_v3_20260908`
- Female UTI model: `uti_bayesian_female_v1_1_20260926`
- Male UTI candidate: `uti_bayesian_male_v0_1_20261001`
- Renal rules: `renal_followup_rules_v1.1_20260919`
- Android release: `1.4.0+5`
- Android application ID: `ph.edu.wvsu.uritect`
- Confidence retake threshold: `0.45` for every analyte

## Final Processing Method

1. Reject unreadable, blank, blurred, dark, overexposed, partial, ambiguous,
   geometrically implausible, or low-confidence captures.
2. Evaluate image orientations and locate one complete strip without the old
   black-and-white macromarker.
3. Use neutral, low-saturation strip/plastic pixels for gray-world white-balance
   gains.
4. Detect the reagent-pad stack using color/chroma activity and validate ten
   aligned pad regions.
5. Extract normalized HSV features and classify each analyte with its frozen
   per-analyte k-NN configuration.
6. Keep the UTI and renal interpretation paths separate.

## Final Clinical Interpretation

The UTI pathway contains separate provisional female and male Bayesian research
models, not calibrated diagnostic probabilities. The unchanged female v1.1
model uses a 50% prior, one dipstick LR, and one symptom LR. The male v0.1
candidate uses a 52.2% literature-derived younger-subgroup prior and one
ordered nitrite/leukocyte threshold LR. Female blood and symptom LRs are never
applied to men. Eligible calculations display the sex-specific model, prior,
posterior, and exact factor without Low/Moderate/High bands; the same details
are stored in the local audit record.

The renal pathway is deterministic and rule-based. It stores every triggered
rule ID and produces one of these actions: `OBSERVE`, `REPEAT_CONFIRM`,
`CONSULT`, `PROMPT_CONSULT`, or `RETAKE`. It does not calculate kidney-disease
probability or diagnose renal disease.

## Frozen Evaluation Claim

Evaluation used exact-row deduplication followed by specimen-grouped splitting,
so Cool, Warm, and Daylight images from one specimen could not cross between
training and test partitions.

- Individual-analyte accuracy: **82.52%** (1,345/1,630 predictions)
- Whole-scan all-ten-correct accuracy: **17.18%** (28/163 scans)
- Mean per-analyte macro F1: **61.22%**
- Mean per-analyte macro sensitivity: **58.99%**
- Mean per-analyte macro specificity: **81.59%**
- Mean per-analyte Cohen's kappa: **0.464**
- Confidence-gated accepted scan rate: **73.62%**
- Accepted individual-analyte accuracy: **83.75%**
- Accepted all-ten-correct accuracy: **19.17%**

The 80% target is achieved only for individual-analyte accuracy. It is not a
whole-scan or diagnostic-accuracy claim.

## Thesis Objective Alignment

1. Dataset construction: implemented with cleaned Laua-an and Cabatuan
   semiquantitative data under three controlled lighting conditions.
2. AWB normalization: implemented using neutral strip/plastic pixels; the
   manuscript must not claim a macromarker or a single guaranteed white patch.
3. Offline ROI application: implemented markerlessly. The final detector uses
   strip geometry, color/chroma activity, and ten-pad alignment validation;
   broad references to adaptive thresholding/contours should be revised to the
   actual algorithm.
4. k-NN and clinical reasoning: implemented and evaluated. Bayesian inference
   applies only to gated UTI screening. Renal abnormality follow-up is a
   separate physician-reviewed rule engine, not Bayesian probability.
5. ISO/IEC 25010-guided evaluation: the instrument and APK are prepared. The
   objective is complete only after the planned 10 registered medical
   technologists perform the app evaluation and the results are analyzed.

## Human Gates That Code Cannot Complete

- Two-medtech content review of the literature-derived Bayesian parameters.
- Ten-medtech final app evaluation using the prepared ISO/IEC 25010-guided form.
- Final physician comparison/sign-off for implemented renal wording and rules.
- Statistician or prediction-model review of the Bayesian combination.
- Physical bottle/box/IFU transcription: manufacturer, catalog number, lot,
  expiry, IFU revision, reaction times, and supported category chart.
- Real-device installation, airplane-mode workflow, invalid-image challenge,
  ROI overlay review, latency, and privacy/deletion checks.
- Culture-confirmed prospective validation before any claim that the Bayesian
  posterior is a calibrated clinical probability.

## Authoritative Files

- `docs/FINAL_PROJECT_HANDOFF.md`
- `docs/MANUSCRIPT_FINAL_REVISION_GUIDE.md`
- `docs/URITECT_Bayesian_UTI_Scoring_System_v1.1.md`
- `docs/URITECT_Bayesian_Parameter_Validation_Form_v1.2.md`
- `docs/URITECT_Renal_Rule_Specification_v1.1.md`
- `docs/URITECT_ISO25010_MedTech_App_Evaluation_v1.0.md`
- `pipeline/output/production_grouped_metrics_complete.json`
- `output/release/URITECT_FINAL_RELEASE_MANIFEST.json`
