# URITECT teammate AI onboarding — 2026-10-02

This handoff records repository evidence, not recalled chat history. The previous session and exact meaning of “last time” are unavailable. Scope: changes after September 17 commit 050fe10 through October 1 HEAD 680fd1a, plus the working tree inspected October 2. If the teammate already has September 30 commit fb10b84, focus on the October 1 section and uncommitted changes. No application code or existing release files were changed while preparing this handoff.

## Start here

You are continuing URITECT, an offline Flutter/Dart Android thesis prototype for markerless semiquantitative interpretation of ten URS-10T pads. Treat the frozen visual model, sex-specific Bayesian research estimates, and deterministic renal rules as separate components. Use current Markdown specifications and frozen grouped metrics as evidence. Do not describe Bayesian output as locally calibrated, diagnostic, or treatment advice. Do not restore probability bands or combine female and male parameters. Preserve unknown inputs as unknown.

Release: 1.4.0+5; application ID: ph.edu.wvsu.uritect.
Visual model: production_semiquant_knn_markerless_roi_topfix_v3_20260908.
Female model: uti_bayesian_female_v1_1_20260926.
Male candidate: uti_bayesian_male_v0_1_20261001.
Renal rules: renal_followup_rules_v1.1_20260919.

## September 30 — fb10b84 (finalization)

- Replaced earlier clinical fusion and risk buckets with gated female Bayesian v1.1 and a separate deterministic renal v1.1 engine. Eligible UTI results show a provisional posterior, prior, model version and selected factors; no Low/Moderate/High probability bands.
- Expanded the clinical checklist to explicit eligibility, acute urinary symptoms, systemic warnings, renal symptoms, interference, repeat/microscopy history, and strip/test-quality inputs. Unselected symptoms must not be interpreted as confirmed absent.
- Added renal_followup.dart and renal_results_page.dart. Renal output records all triggered rule IDs and resolves to OBSERVE, REPEAT_CONFIRM, CONSULT, PROMPT_CONSULT or RETAKE. Protein, blood, safety, persistence, and interference drive follow-up; there is no renal disease probability.
- Reworked overall results, analyte results, analysis/navigation and phone-width UI around separate UTI findings, systemic/alternate-cause guidance and renal follow-up. Added workflow UI tests and a phone golden image.
- Expanded saved records to clinicalAction, UTI prior/posterior/factors/model/status, conflict context and renal result. Legacy riskBucket records migrate to action wording. Scan history remains local.
- Hardened local scan processing and failure handling; inspect the supplied patch for exact conditions. The final runtime is local Dart: image quality gate, orientation search, markerless strip detection, neutral strip/plastic gray-world AWB, ten-pad geometry validation, normalized HSV, ten per-analyte k-NN predictions, confidence gate, clinical interpretation, local history. Offline markerless processing predates this baseline; do not claim all of it was newly implemented in September 30.
- Established release signing via android/key.properties rather than the debug certificate; release builds require signing configuration. Changed Android namespace/application ID to ph.edu.wvsu.uritect, updated MainActivity/manifest and ignored private signing material. See docs/ANDROID_RELEASE_SIGNING.md; do not transfer signing secrets in an onboarding packet.
- Added complete frozen evaluation reporting, release-manifest generation/verification, ISO/IEC 25010-guided medtech form, CSV response template and descriptive analysis script. Added final engineering/manuscript handoffs and physician/parameter review materials.

## October 1 — 680fd1a (male Bayesian candidate)

- Added explicit female/male selection and separate sex-specific eligibility. Missing or conflicting sex selection blocks calculation. Checklist rendering changes with sex.
- Preserved the female v1.1 model: provisional prior 0.50; one mutually exclusive dipstick LR and one mutually exclusive symptom LR. Dipstick hierarchy uses 7.20, 5.50, 1.70, 1.40 or 0.22; symptom hierarchy uses 1.50, 1.30, 1.20 or 1.10. Exact source thresholds and unknown-input handling are in the female specification.
- Added male v0.1: prior 97/186 = 0.521505… (52.2% displayed), derived from the younger complementary subgroup of the cited Dutch study. This is not Filipino prevalence or a precise match to ages 18–64.
- Male factors use exactly one ordered rule: both nitrite and LE positive → 5.14; nitrite threshold without the stronger pattern → 4.87; LE threshold without earlier patterns → 1.65; both confirmed negative → 0.35. Unavailable/unreliable/unmatched evidence does not calculate. Do not multiply correlated threshold LRs.
- Male LE-positive includes Trace 15, Small 70, Moderate 125 and Large 500; nitrite requires Positive. Female blood and symptom LRs are never applied to men. Blood and visible hematuria remain consultation context, not male numerical factors.
- Both pathways require age 18–64, no catheter, no known urinary tract abnormality, no immunocompromise, acute qualifying symptoms and no systemic override. Female requires nonpregnancy; vaginal discharge/irritation routes to alternate-cause guidance. Male additionally requires no diabetes and no suspected STI; qualifying symptoms are dysuria, frequency or urgency.
- Male M2/M3 are explicitly an ordered-threshold approximation, since published LRs are threshold-level rather than mutually exclusive exact-pattern LRs. Statistical review and prospective calibration remain required.
- Updated model labels/details in results and audit behavior; expanded fusion/UI tests and updated the golden image. Renal v1.1 and the frozen visual classifier remain unchanged by the male-model commit.
- Updated release to 1.4.0+5 and expanded the manifest. Added sex-specific specification v1.2, medtech parameter validation form v1.3, personalized review cover letter v1.3, their PDF exports, release clinical sign-off addendum, and pipeline/build_bayesian_v1_3_pdfs.py.
- The active cover-letter PDF is addressed to Krizzler Faith M. Montaño, RMT. It requests expert content review of laboratory mappings, literature-derived LRs, missing/unreliable input handling and screening workflow. Expert content review is distinct from clinical calibration.

## Current uncommitted changes — preserve and review

1. docs/FINAL_PROJECT_HANDOFF.md changes the reported passing-test count from 59 to 56.
2. docs/URITECT_Release_1.4.0_Clinical_Signoff_Addendum.md changes the APK checksum from A244432523DE2ED8E33BC5D0F371EDD76450E1984AA1B76A3217038B5C1CF9A2 to E4B190E2C5134CFC23208989E460E716BE0421B352A7D0D09A470576C819C3E8, plus a trailing blank line.
3. uritect_app/test/screening_fusion_test.dart removes three tests: male nitrite-only LR 4.87; unavailable male dipstick evidence → insufficient; systemic male finding → not_designed. The diff contains no corresponding runtime-code change and no rationale for removal. Do not assume they were redundant or failing.

Tests were not rerun for this onboarding task. “56 pass” is a current documentation claim, not a freshly verified test result. Review removed coverage before accepting the working-tree changes.

## Release integrity actually checked

All 27 manifest entries were checked directly for byte count and SHA-256. The APK and 24 other entries match; two entries fail: docs/FINAL_PROJECT_HANDOFF.md and docs/URITECT_Release_1.4.0_Clinical_Signoff_Addendum.md. These are locally edited documents.

The actual local 1.4.0 APK hash is A244432523DE2ED8E33BC5D0F371EDD76450E1984AA1B76A3217038B5C1CF9A2 (52,476,397 bytes), matching the manifest. The addendum's uncommitted E4B190… value does not match that APK. Resolve which APK is intended before changing checksums or rebuilding the manifest. Do not silently treat the new addendum checksum as authoritative.

The manifest is a recorded snapshot, not proof that current edited documents still match. Reconcile intended release artifacts, then regenerate and verify it. Existing generated handoff PDFs can lag newer Markdown; prefer current source specs for onboarding.

## Frozen evaluation and claims

Specimen-grouped 80/20 evaluation keeps Cool/Warm/Daylight variants of the same specimen together; exact-row deduplication was applied. Final guide reports 7,840 analyte rows, zero duplicates removed by the frozen key, 257 rejected capture bursts, GroupShuffleSplit test_size 0.20/random_state 42/specimen_group.

- Individual analyte accuracy: 82.52% (1,345/1,630).
- Whole scan, all ten correct: 17.18% (28/163).
- Mean macro F1: 61.22%; sensitivity: 58.99%; specificity: 81.59%; kappa: 0.464.
- Every analyte must meet confidence 0.45. Accepted scan rate: 73.62%; accepted analyte accuracy: 83.75%; accepted whole-scan accuracy: 19.17%.
- The 80% target applies only to individual-analyte classification. These are not UTI or kidney-disease diagnostic metrics. Rare classes and weaker specific-gravity/leukocyte performance must remain visible in reporting.

## Remaining work

- Two-medtech sex-specific Bayesian content review using v1.3.
- Physician comparison/sign-off for actual renal wording and rules, using the intended final APK.
- Physical manufacturer/catalog/lot/expiry/IFU revision/reaction times/category-chart transcription.
- Real-device installation, airplane-mode workflow, invalid-image challenges, ROI overlays, latency, local storage/deletion and privacy checks.
- Ten registered medtech app evaluations, CSV data entry and pipeline/analyze_medtech_app_evaluation.py analysis. Objective 5 is not complete until this happens; do not invent a post-hoc pass threshold or claim ISO certification.
- Revise original Word/Google Docs manuscript with MANUSCRIPT_FINAL_REVISION_GUIDE.md. The repository contains the old manuscript PDF, not an editable thesis source.
- Statistician/prediction-model review and prospective culture-confirmed local validation before claiming calibrated clinical probabilities.

## Suggested continuation checks

Run flutter analyze and flutter test from uritect_app when checking implementation changes. Verify release artifacts with python pipeline/verify_final_release_manifest.py from repository root; it currently has the two documented source-file mismatches. Use pipeline/evaluate_final_production_metrics.py for frozen metrics, pipeline/build_bayesian_v1_3_pdfs.py for the latest Bayesian packet, and pipeline/build_final_release_manifest.py only after reconciling the intended release. These commands are pointers, not claims that they were executed during this handoff.

## Complete committed file inventory

A = added; M = modified. Baseline 050fe10 to HEAD 680fd1a.

```text
M	.gitignore
M	THESIS_PROJECT_BRIEF.md
A	docs/ANDROID_RELEASE_SIGNING.md
A	docs/FINAL_PROJECT_HANDOFF.md
A	docs/MANUSCRIPT_FINAL_REVISION_GUIDE.md
A	docs/URITECT_Bayesian_Parameter_Validation_Form_v1.2.md
A	docs/URITECT_Bayesian_Parameter_Validation_Form_v1.3.md
A	docs/URITECT_Bayesian_Review_Cover_Letter_v1.3.md
A	docs/URITECT_Bayesian_UTI_Scoring_System_v1.0.md
A	docs/URITECT_Bayesian_UTI_Scoring_System_v1.1.md
A	docs/URITECT_ISO25010_MedTech_App_Evaluation_v1.0.md
A	docs/URITECT_Release_1.4.0_Clinical_Signoff_Addendum.md
A	docs/URITECT_Renal_Physician_Implementation_Signoff_v1.1.md
A	docs/URITECT_Renal_Rule_Specification_v1.1.md
A	docs/URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.md
A	docs/Uritect_Bayesian_UTI_Physician_Review_Packet.docx
A	docs/bayesian_uti_physician_validation_packet.md
M	docs/final_acceptance_and_proof_checklist.md
M	docs/final_clinical_rule_table.md
M	docs/final_implementation_alignment.md
M	docs/uti_screening_weight_table_for_physician_review.md
A	output/forms/URITECT_ISO25010_MedTech_App_Evaluation_Data_Template.csv
A	output/pdf/URITECT_Bayesian_Parameter_Validation_Form_v1.2.pdf
A	output/pdf/URITECT_Bayesian_Parameter_Validation_Form_v1.3.pdf
A	output/pdf/URITECT_Bayesian_Review_Cover_Letter_v1.3.pdf
A	output/pdf/URITECT_Bayesian_UTI_Scoring_System_v1.0.pdf
A	output/pdf/URITECT_Bayesian_UTI_Scoring_System_v1.1.pdf
A	output/pdf/URITECT_Final_Project_Handoff_v1.0.pdf
A	output/pdf/URITECT_ISO25010_MedTech_App_Evaluation_v1.0.pdf
A	output/pdf/URITECT_Renal_Physician_Implementation_Signoff_v1.1.pdf
A	output/pdf/URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.pdf
A	output/release/URITECT_FINAL_RELEASE_MANIFEST.json
A	pipeline/analyze_medtech_app_evaluation.py
A	pipeline/build_bayesian_v1_3_pdfs.py
A	pipeline/build_final_release_manifest.py
A	pipeline/evaluate_final_production_metrics.py
A	pipeline/output/production_grouped_metrics_complete.json
M	pipeline/output/semiquant_models/MODEL_CARD.md
A	pipeline/verify_final_release_manifest.py
M	uritect_app/android/app/build.gradle.kts
M	uritect_app/android/app/src/main/AndroidManifest.xml
M	uritect_app/android/app/src/main/kotlin/com/example/uritect_app/MainActivity.kt
M	uritect_app/lib/models/clinical_symptoms.dart
A	uritect_app/lib/models/renal_followup.dart
M	uritect_app/lib/models/saved_scan_record.dart
M	uritect_app/lib/models/screening_fusion.dart
M	uritect_app/lib/pages/analyzing_page.dart
M	uritect_app/lib/pages/home_page.dart
M	uritect_app/lib/pages/landing_page.dart
M	uritect_app/lib/pages/overall_results_page.dart
A	uritect_app/lib/pages/renal_results_page.dart
M	uritect_app/lib/pages/results_page.dart
M	uritect_app/lib/pages/root_page.dart
M	uritect_app/lib/pages/symptom_checklist_page.dart
M	uritect_app/lib/services/local_scan_analysis_service.dart
M	uritect_app/lib/services/scan_analysis_service.dart
M	uritect_app/lib/services/scan_history_service.dart
M	uritect_app/lib/widgets/bottom_nav_bar.dart
M	uritect_app/lib/widgets/common_widgets.dart
M	uritect_app/pubspec.yaml
A	uritect_app/test/bayesian_workflow_ui_test.dart
A	uritect_app/test/goldens/bayesian_results_phone.png
A	uritect_app/test/renal_followup_test.dart
M	uritect_app/test/screening_fusion_test.dart
```

## Full diff companion

URITECT_CHANGES_SINCE_2026-09-17.patch.txt contains the complete textual committed diff followed by the pre-existing uncommitted diff. Git binary changes are identified but their contents are not embedded; share the repository or actual PDF/DOCX/PNG/APK artifacts when those are needed. The APKs are local release artifacts and are not shown as added in the tracked change inventory.

## Source documents copied below for standalone context

The following source snapshots make this handoff useful even before the assistant opens the repository. Later live source changes take precedence. Read the earlier integrity/test notes before interpreting the copied documents' release and test claims.


---

## Snapshot: THESIS_PROJECT_BRIEF.md

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


---

## Snapshot: docs/FINAL_PROJECT_HANDOFF.md

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
| Automated tests | 56 tests pass across sex-specific Bayesian, renal, invalid-scan, persistence, navigation, and phone-width UI behavior | `uritect_app/test` |
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


---

## Snapshot: docs/URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.md

# URITECT Sex-Specific Bayesian UTI Research Specification v1.2

**Female model:** `uti_bayesian_female_v1_1_20260926`  
**Male candidate model:** `uti_bayesian_male_v0_1_20261001`  
**Status:** Implemented research models; literature-derived and not locally calibrated  
**Reference standard in principal studies:** Urine culture / microbiologically confirmed UTI

## 1. Intended Use

URITECT provides offline ten-analyte strip classification, safety assessment,
renal follow-up, and a sex-specific Bayesian UTI research estimate for eligible
symptomatic adults aged 18-64. Neither estimate diagnoses UTI, recommends
antibiotics, replaces urine culture, or represents a locally calibrated
probability.

Female and male calculations are separate. Female values are never applied to
male users. The male model uses only nitrite and leukocyte esterase because no
adequate male-specific blood LR was identified.

## 2. Eligibility

Both models require confirmed age 18-64, no urinary catheter, no known urinary
tract abnormality, no immunocompromise, at least one qualifying acute urinary
symptom, and no systemic finding that moves the user to the safety pathway.

Female calculations additionally require confirmed nonpregnancy. Dysuria,
frequency, urgency, suprapubic pain, or visible hematuria can satisfy the
female symptom gate. Vaginal discharge or irritation stops the calculation and
activates alternate-cause consultation guidance.

Male calculations additionally require no diabetes and no suspected sexually
transmitted infection, matching the principal male study exclusions. Dysuria,
frequency, or urgency must be present. The study included men aged 18 years and
older; use in URITECT's narrower 18-64 population remains a transportability
limitation.

## 3. Female Model

The female v1.1 model is unchanged. It uses a provisional prior of 0.50, one
mutually exclusive dipstick LR, and one mutually exclusive symptom LR.

| Female dipstick pattern | LR |
| --- | ---: |
| Nitrite positive plus source-threshold leukocytes or blood | 7.20 |
| Nitrite positive without the stronger grouped pattern | 5.50 |
| Blood positive when nitrite is not positive | 1.70 |
| Leukocytes positive when nitrite and blood are not positive | 1.40 |
| Nitrite, leukocytes, and blood all confirmed negative | 0.22 |

| Female symptom pattern | LR |
| --- | ---: |
| Dysuria and urgency | 1.50 |
| Dysuria | 1.30 |
| Urgency | 1.20 |
| Frequency | 1.10 |

See `URITECT_Bayesian_UTI_Scoring_System_v1.1.md` for the complete female
threshold mapping, evidence, and limitations.

## 4. Male Evidence and Prior Derivation

Den Heijer et al. enrolled 603 symptomatic men from Dutch general practices.
Complete data were available for 490; 321 had microbiologically confirmed UTI
at at least 10^3 CFU/mL. The median age was 65 years (range 18-97). The study
excluded relevant urological or nephrological comorbidity other than benign
prostatic hypertrophy, diabetes, immunocompromising disease, catheterization,
and suspected sexually transmitted infection.

The full cohort prevalence was 321/490 = 65.5%, but URITECT does not use that
as its prior because the cohort was older than the app population. Table 3
reported 224 culture-positive and 80 culture-negative participants in its
older-age category. Therefore, in the complementary younger subgroup:

```text
culture positive = 321 - 224 = 97
culture negative = 169 - 80 = 89
candidate prior = 97 / (97 + 89) = 0.521505... (52.2%)
candidate prior odds = 97 / 89 = 1.089888...
```

This is a transparent subgroup derivation, not a published Filipino prevalence
estimate. The article describes the age boundary as both `>=60` in narrative
text and `>60` in a table, so URITECT does not claim an exact birthday boundary
for this derived subgroup. It does not exactly represent the app's 18-64
population and is frozen only as a provisional research prior pending local
culture-confirmed calibration.

## 5. Male Ordered-Threshold Model

Den Heijer et al. assigned one point to positive leukocyte esterase and two
points to positive nitrite. Table 2 reported the following thresholds:

| Published threshold | LR+ | LR- | 95% CI for LR+ / LR- |
| --- | ---: | ---: | --- |
| Score at least 1: LE or nitrite positive | 1.65 | 0.35 | 1.41-1.94 / 0.28-0.45 |
| Score at least 2: nitrite positive | 4.87 | 0.48 | 3.19-7.43 / 0.42-0.55 |
| Score 3: nitrite and LE positive | 5.14 | 0.54 | 3.24-8.17 / 0.48-0.60 |

URITECT applies the first matching row below and never multiplies these
correlated thresholds:

| Male rule | Pattern | Candidate LR |
| --- | --- | ---: |
| M1 | Nitrite positive and LE positive | 5.14 |
| M2 | Nitrite-positive threshold met without M1 | 4.87 |
| M3 | LE-positive threshold met without M1 or M2 | 1.65 |
| M4 | Nitrite and LE both confirmed negative | 0.35 |
| M5 | Missing, unreliable, or unmatched | 1.00; no calculation |

M2 and M3 use an ordered-threshold approximation: the publication reports
threshold LRs, not mutually exclusive exact-pattern LRs. This is an explicit
URITECT design assumption requiring statistical review and prospective
validation. It is not hidden as a published clinical rule.

The male study treated any LE color change as positive. URITECT therefore maps
`Trace 15`, `Small 70`, `Moderate 125`, and `Large 500` to male LE-positive.
Nitrite requires `Positive`. Blood is not numerically weighted in the male UTI
model.

## 6. Equation

```text
prior odds = prior probability / (1 - prior probability)
posterior odds = prior odds x the one selected LR
posterior probability = posterior odds / (1 + posterior odds)
```

Female calculations multiply one dipstick LR and one symptom LR. Male
calculations use one ordered dipstick-threshold LR only.

## 7. Safety and Display Rules

- Fever/chills, flank pain, significant nausea/vomiting, inability to maintain
  hydration or medication, severe weakness, confusion, or fainting remain
  outside the ordinary posterior and enter the safety pathway.
- Visible hematuria is consultation context and is not numerically weighted.
- No Low/Moderate/High probability bands or treatment thresholds are used.
- The app displays the sex-specific model version, starting prior, selected LR,
  and provisional posterior with a screening-only warning.
- Local records store calculation status, prior, posterior, factors, and model
  version.

## 8. Validation Boundary

The calculations are mathematically reproducible, but neither complete model
is clinically calibrated for the local population. Expert content review can
assess relevance and implementation clarity. Clinical validity requires
physician and statistical review plus prospective culture-confirmed
patient-level validation, including calibration, discrimination, confidence
intervals, and subgroup performance.

## 9. References

1. den Heijer CDJ, van Dongen MCJM, Donker GA, Stobberingh EE. Diagnostic
   approach to urinary tract infections in male general practice patients: a
   national surveillance study. *Br J Gen Pract*. 2012;62:e780-e786.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC3481519/
2. Koeijers JJ, Kessels AGH, Nys S, et al. Evaluation of the nitrite and
   leukocyte esterase activity tests for the diagnosis of acute symptomatic
   urinary tract infection in men. *Clin Infect Dis*. 2007;45:894-896.
   https://pubmed.ncbi.nlm.nih.gov/17806056/
3. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults:
   Rapid Evidence Review. *Am Fam Physician*. 2024;109:167-174.
4. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict
   urinary tract infection in primary care settings. *Br J Gen Pract*.
   2006;56:606-612.
5. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does this woman have an
   acute uncomplicated urinary tract infection? *JAMA*. 2002;287:2701-2710.


---

## Snapshot: docs/URITECT_Bayesian_UTI_Scoring_System_v1.1.md

# URITECT Bayesian UTI Scoring System v1.1

**Implemented model:** `uti_bayesian_lr_v1_1_20260926`  
**Method:** Provisional grouped likelihood-ratio Bayesian research estimate  
**Prior:** 50% for the narrowly gated population only  
**Status:** Frozen app implementation; literature-derived and not clinically calibrated

> Plain explanation: URITECT can calculate a research estimate only for a
> narrowly defined group of symptomatic women. For an eligible calculation,
> the app shows the provisional percentage, the starting prior, and the exact
> evidence factors used. It is not a diagnosis, treatment recommendation, or
> Low/Moderate/High UTI category.

## 1. What Changed From Version 1.0

| Review finding | Version 1.1 correction |
| --- | --- |
| Combined model was not validated as one probability model | Calls it provisional and literature-derived; explicitly states the independence assumption and validation requirement. |
| Visible hematuria could duplicate dipstick blood | Removed its LR from the equation; retained it as consultation context. |
| Vaginal findings came from a different population | Removed their LRs from the equation; either finding stops ordinary calculation and routes to consultation. |
| The 50% prior was too broadly applicable | Added six required population confirmations and an acute urinary-symptom gate. |
| Analyte positivity was too broad | Added exact URITECT-to-study threshold mapping. |
| 20% and 80% bands were invented | Removed every probability band and UTI likelihood label. |
| Unknown could be interpreted as absent | Defined unchecked, unknown, unavailable, and unreliable as no update. |
| Nausea alone triggered an urgent pathway | Prompt action now requires an approved combination or serious safety condition. |

## 2. Intended Population Gate

The estimate is calculated only when **all six confirmations** and at least one
acute urinary symptom are present.

| Gate ID | Required confirmation |
| --- | --- |
| E1 | Patient is a woman. |
| E2 | Patient is 18 to 64 years old. |
| E3 | Patient is confirmed not pregnant. |
| E4 | Patient does not have a urinary catheter. |
| E5 | Patient has no known urinary tract abnormality. |
| E6 | Patient is not immunocompromised. |
| E7 | At least one acute urinary symptom is reported: dysuria, urgency, frequency, suprapubic pain, or visible hematuria. |

The ordinary calculation is stopped when vaginal discharge, vaginal
irritation, fever/chills, flank pain, or nausea/vomiting is reported. The app
then shows a consultation action instead of an ordinary lower-UTI estimate.

If a required confirmation is unchecked, its state is **not confirmed or
unknown**. It is not assumed to be false. The app displays:

> This UTI screening estimate is not designed for your reported situation.
> Consultation with a healthcare professional is suggested.

## 3. Exact Dipstick Mapping

The frozen ten-analyte k-NN model uses the labels below. Source-study
positivity follows Little et al.: leukocyte esterase `+` or greater and blood
`haemolysed trace` or greater.

| Analyte | URITECT label | Treatment in Group A |
| --- | --- | --- |
| Nitrite | `Positive` | Positive |
| Nitrite | `Neg` / `Negative` | Confirmed negative |
| Leukocytes | `Small 70`, `Moderate 125`, `Large 500` | Positive (`+` or greater) |
| Leukocytes | `Trace 15` | No source-matched update; not positive and not negative |
| Leukocytes | `Neg` / `Negative` | Confirmed negative |
| Blood | `Hemolyzed 10`, `Small 25`, `Moderate 80`, `Large 200` | Positive (hemolyzed trace or greater) |
| Blood | `Non-hemolyzed 10` | No source-matched update; not used as the Little threshold |
| Blood | `Neg` / `Negative` | Confirmed negative |
| Any | `Unavailable`, invalid, or unreliable | LR 1.00; no update |

**Strip profile used in software:** URS-10T. The study threshold mapping above
is frozen in the implementation. The physical product's exact manufacturer,
lot, IFU revision, and reaction-time instructions must still be recorded for
each validation run; they must not be inferred from the generic URS-10T name.

## 4. Evidence Library

These values are retained to show the cited evidence. Not every value is used
in the implemented equation.

| Finding | LR+ / present | LR- / absent | Population and reference standard | Implemented? |
| --- | ---: | ---: | --- | --- |
| Nitrite | 5.50 | 0.56 | Symptomatic women; review table based on culture-referenced evidence | LR+ only through Group A hierarchy |
| Leukocyte esterase | 1.40 | 0.40 | Symptomatic women; review table based on culture-referenced evidence | LR+ only through Group A hierarchy |
| Dipstick blood | 1.70 | 0.89 | Symptomatic women; review table based on culture-referenced evidence | LR+ only through Group A hierarchy |
| Dysuria | 1.30 | 0.67 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Urgency | 1.20 | 0.75 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Frequency | 1.10 | 0.71 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Dysuria with urgency | 1.50 | 0.44 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Visible hematuria | 2.00 (95% CI 1.3-2.9) | Not assigned | Meta-analysis of signs/symptoms in women with acute uncomplicated UTI | No; context only |
| Vaginal discharge | 0.30 (95% CI 0.1-0.9) | Not assigned | Same Bent review | No; alternate-cause route |
| Vaginal irritation | 0.20 (95% CI 0.1-0.9) | Not assigned | Same Bent review | No; alternate-cause route |
| Nitrite plus leukocytes or blood | 7.20 | Not assigned | 427 women with suspected UTI; laboratory diagnosis using European urinalysis guideline | Yes |
| Nitrite, leukocytes, and blood all negative | Not assigned | 0.22 | Same Little validation study | Yes |

The AAFP table's displayed post-test probabilities assume a 50% pretest
probability. Bent et al. reports an approximate 50% probability among women
presenting with one or more UTI symptoms. This supports 50% only as a
provisional starting assumption for the gated study-like population.

## 5. Exact Implemented Scoring Hierarchy

### 5.1 Group A - Dipstick Pattern

Apply the first matching rule only.

| Rule | Pattern | Candidate LR |
| --- | --- | ---: |
| A1 | Nitrite positive plus source-threshold leukocytes or blood positive | 7.20 |
| A2 | Nitrite positive without either additional source-threshold positive finding | 5.50 |
| A3 | Nitrite not positive or unavailable; source-threshold blood positive | 1.70 |
| A4 | Nitrite and blood not positive; source-threshold leukocytes positive | 1.40 |
| A5 | Nitrite, leukocytes, and blood all confirmed negative | 0.22 |
| A6 | No rule above matches | 1.00; no update |

### 5.2 Group B - Urinary Symptom Pattern

Apply the first matching rule only.

| Rule | Pattern | Candidate LR |
| --- | --- | ---: |
| B1 | Dysuria and urgency present | 1.50 |
| B2 | Dysuria present | 1.30 |
| B3 | Urgency present | 1.20 |
| B4 | Frequency present | 1.10 |
| B5 | None of the weighted symptoms is reported | 1.00; no update |

Visible hematuria and suprapubic pain can satisfy the symptomatic eligibility
gate but have no numerical factor in v1.1. Visible hematuria triggers a
separate consultation-context message.

### 5.3 State Handling

| Input state | Numerical treatment |
| --- | --- |
| Present | Apply the approved present LR if the variable is in Groups A or B. |
| Confirmed absent | No symptom-negative LR is used in v1.1. Exact dipstick negatives may satisfy A5. |
| Not selected / not asked / unknown | LR 1.00; no update. |
| Unavailable / unreliable | LR 1.00; no update. |
| Not applicable or outside population | Do not calculate. |

## 6. Equation

```text
prior probability = 0.50
prior odds = 0.50 / (1 - 0.50) = 1.00

posterior odds = prior odds x selected Group A LR x selected Group B LR
posterior probability = posterior odds / (1 + posterior odds)
```

Example for an eligible patient with nitrite plus leukocytes positive and both
dysuria and urgency:

```text
posterior odds = 1.00 x 7.20 x 1.50 = 10.80
research posterior = 10.80 / 11.80 = 0.915 or 91.5%
```

This arithmetic is correct, but the combined equation is a **URITECT design
assumption**. The cited sources do not validate the exact multiplication of
Group A and Group B as a single calibrated clinical model. Dependency,
transportability, and calibration require culture-confirmed patient-level
validation and statistical review.

## 7. Separate Action Pathways

| Trigger | App action |
| --- | --- |
| Eligibility incomplete or outside intended population | Consultation with a healthcare professional is suggested. |
| Vaginal discharge or irritation | Other conditions may cause similar symptoms. Consultation is suggested; no ordinary posterior. |
| Visible hematuria | Consultation is suggested; no hematuria LR is added. |
| Fever with flank pain | Prompt medical consultation is suggested. |
| Nausea/vomiting with fever or flank pain | Prompt medical consultation is suggested. |
| Vomiting prevents hydration or oral medication | Prompt medical consultation is suggested. |
| Confusion, fainting, or severe weakness with a urinary finding | Prompt medical consultation is suggested. |
| Nausea/vomiting alone | Consultation is suggested; it does not independently activate the prompt pathway. |
| No usable source-matched evidence | Insufficient evidence. The 50% prior is not shown as a patient result. |

The UTI pathway is separate from the renal follow-up engine. Neither pathway
recommends antibiotics or diagnoses disease.

## 8. Display and Audit Rules

- No 20%/80% thresholds exist in v1.1.
- No Lower, Intermediate, or Higher UTI probability label is produced.
- An eligible calculation displays the provisional percentage, 50% prior, and each applied LR.
- The display label is: **Bayesian UTI screening estimate - screening support only, not a diagnosis or treatment recommendation.**
- The calculated posterior and factors are also stored in the local scan audit record.
- The model version and calculation status are stored with the result.
- A blocked or insufficient case stores no patient-specific posterior.

## 9. Validation Boundaries

Two registered medical technologists may assess relevance, clarity,
manufacturer-label mapping, workflow feasibility, missing-result handling, and
laboratory limitations. Content Validity Index agreement does **not** establish
diagnostic accuracy or probability calibration.

Before any clinical probability claim, the complete model requires:

- Physician review of population gates, symptom meaning, actions, and safety wording.
- Statistician or clinical prediction-model review of priors, dependence, calibration, and reporting.
- Prospective culture-confirmed patient-level validation, including calibration assessment and confidence intervals.
- Validation of the exact supported strip product, IFU revision, reading times, phone/camera workflow, and classifier errors.

## 10. Medical Technologist Review Checklist

Rate each item: `4 = highly relevant/clear`, `3 = relevant/clear with minor
revision`, `2 = major revision needed`, `1 = not relevant/unclear`.

| ID | Review statement | 1 | 2 | 3 | 4 | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | The intended population gate is understandable. | [ ] | [ ] | [ ] | [ ] | |
| C2 | Unchecked eligibility items are clearly treated as unknown. | [ ] | [ ] | [ ] | [ ] | |
| C3 | Nitrite positive mapping is appropriate for the supported strip. | [ ] | [ ] | [ ] | [ ] | |
| C4 | Leukocyte `+` threshold mapping is clear. | [ ] | [ ] | [ ] | [ ] | |
| C5 | `Trace 15` leukocytes are correctly excluded from source-threshold positivity. | [ ] | [ ] | [ ] | [ ] | |
| C6 | Hemolyzed-trace blood mapping is clear. | [ ] | [ ] | [ ] | [ ] | |
| C7 | Non-hemolyzed trace blood is appropriately excluded from the Little threshold. | [ ] | [ ] | [ ] | [ ] | |
| C8 | Missing, unreliable, and negative results are clearly distinguished. | [ ] | [ ] | [ ] | [ ] | |
| C9 | One mutually exclusive dipstick factor reduces duplicate counting. | [ ] | [ ] | [ ] | [ ] | |
| C10 | Visible hematuria is appropriately retained as context without a numerical LR. | [ ] | [ ] | [ ] | [ ] | |
| C11 | Vaginal symptoms are appropriately routed to consultation. | [ ] | [ ] | [ ] | [ ] | |
| C12 | The systemic-symptom action wording is clear and safe. | [ ] | [ ] | [ ] | [ ] | |
| C13 | The 50% prior limitation is stated clearly. | [ ] | [ ] | [ ] | [ ] | |
| C14 | The lack of local calibration is stated clearly. | [ ] | [ ] | [ ] | [ ] | |
| C15 | The distinction between CVI and clinical validation is clear. | [ ] | [ ] | [ ] | [ ] | |
| C16 | The workflow is feasible for intended rural/offline use. | [ ] | [ ] | [ ] | [ ] | |

**Overall decision:** [ ] Accept as written  [ ] Accept with minor revisions  [ ] Major revision required  [ ] Reject

Reviewer name and credentials: ______________________________  
Registration/license number: ________________________________  
Institution: ________________________________________________  
Signature: __________________________  Date: _________________

## 11. Required Product and Validation Record

| Field | Entry |
| --- | --- |
| Strip manufacturer | ______________________________ |
| Exact product/catalog number | ______________________________ |
| Lot number and expiry | ______________________________ |
| IFU revision/date | ______________________________ |
| Nitrite reaction time | ______________________________ |
| Leukocyte reaction time | ______________________________ |
| Blood reaction time | ______________________________ |
| Phone model / Android version | ______________________________ |
| App version / model version | `1.3.0+4` / `uti_bayesian_lr_v1_1_20260926` |

## 12. References

1. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults: Rapid Evidence Review. *American Family Physician*. 2024;109(2):167-174. https://www.aafp.org/afp/2024/0200/acute-uncomplicated-utis-adults
2. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict urinary tract infection in primary care settings. *British Journal of General Practice*. 2006;56(529):606-612. https://pmc.ncbi.nlm.nih.gov/articles/PMC1874525/
3. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does this woman have an acute uncomplicated urinary tract infection? *JAMA*. 2002;287(20):2701-2710. https://pubmed.ncbi.nlm.nih.gov/12020306/

## 13. Final Reviewer Acknowledgment

I understand that this review evaluates content and implementation clarity. It
does not establish that the combined posterior is calibrated or clinically
valid, and it does not replace physician, statistical, or culture-confirmed
validation.

Reviewer signature: __________________________  Date: _________________


---

## Snapshot: docs/URITECT_Renal_Rule_Specification_v1.1.md

# URITECT Renal-Related Follow-up Rule Specification v1.1

**Status:** Physician-reviewed, guideline-checked, and implementation-frozen for final comparison  
**Date:** 19 September 2026  
**Module type:** Deterministic referral and follow-up rules  
**Not a:** diagnostic system, kidney-disease detector, CKD staging system, or renal probability calculator

## 1. Intended use

This module evaluates selected urine-strip findings, reported symptoms, possible interferences, and result reliability to provide only one of the following actions:

1. Observe for symptoms;
2. Repeat or confirm the urine test;
3. Consultation with a healthcare professional is suggested;
4. Prompt medical consultation is suggested; or
5. The scan cannot be interpreted and should be repeated.

The module must never state or imply:

- “You have kidney disease”;
- “CKD detected”;
- “Renal disease probability”;
- “Normal kidneys”;
- “No kidney disease”;
- Low, Moderate, or High renal risk.

## 2. Inputs

The rules may execute only when the corresponding input is collected reliably.

### Dipstick and scan inputs

- Protein category reported by the validated strip;
- Blood category reported by the validated strip;
- Protein-result reliability;
- Blood-result reliability;
- Overall scan validity.

### User-reported inputs

- Visible blood in urine;
- Blood clots;
- Difficulty or inability to urinate;
- Markedly reduced urine output;
- Edema or unusual swelling;
- Shortness of breath;
- Fever or chills;
- Flank or back pain;
- Nausea or vomiting;
- Inability to maintain hydration or take oral medication;
- Confusion, fainting, or severe weakness;
- Severe flank or abdominal pain;
- Menstruation or vaginal bleeding;
- Possible specimen contamination;
- Recent strenuous exercise;
- Dehydration;
- Current acute illness;
- Possible or clinically managed UTI;
- Whether an abnormal finding remains present on a properly collected repeat test.

If the application does not collect an input, the associated rule must not be represented as implemented.

## 3. User-facing outputs

| Internal code | User-facing heading | Meaning |
|---|---|---|
| OBSERVE | Observe for symptoms | No follow-up trigger was identified from the available reliable inputs. This does not rule out disease. |
| REPEAT_CONFIRM | Repeat or confirm the test | A finding may require a properly collected repeat sample or laboratory confirmation. |
| CONSULT | Consultation suggested | A healthcare professional should interpret the finding and decide on confirmation or assessment. |
| PROMPT_CONSULT | Seek prompt medical consultation | Reported warning findings require timely professional assessment. This is an action instruction, not a risk level. |
| RETAKE | Unable to interpret—retake the scan | The relevant scan or analyte result is unreliable. |

The internal codes may be stored for programming and audit purposes, but the application must display the action wording, not a severity label.

## 4. Rule priority

Rules are evaluated in this order:

1. **Safety symptoms:** PROMPT_CONSULT overrides all other outputs, including an invalid scan.
2. **Technical validity:** If no safety trigger is present and the relevant result is unreliable, use RETAKE.
3. **Visible blood and combined findings:** Apply consultation rules.
4. **Possible contamination or temporary causes:** Use REPEAT_CONFIRM unless another finding independently requires consultation.
5. **Isolated protein or blood:** Apply the confirmation rules below.
6. **No trigger:** Use OBSERVE with a safety-net message.

An invalid scan must never suppress advice based on serious symptoms reported by the user.

### 4.1 Frozen implementation clarifications

- Action priority is fixed as `PROMPT_CONSULT > RETAKE > CONSULT > REPEAT_CONFIRM > OBSERVE`.
- Protein `Trace` activates the trace repeat rule but is not positive for combined protein-and-blood or protein-and-edema rules.
- Protein `0.3 g/L` or higher is manufacturer-positive for these referral-support rules.
- Persistence is used only when the user explicitly confirms an appropriate repeat result. A single scan never creates a persistence label.
- Possible or clinically managed UTI is an explicit checklist input. It is not inferred from the Bayesian UTI percentage.
- Systemic safety symptoms may override an invalid scan, but unreliable protein and blood values are never interpreted.

### 4.2 Supported URS-10T profile

| Field | Frozen value |
|---|---|
| Product designation | URS-10T reagent strip, ten parameters |
| Software profile | `urs10t_protein_blood_60s_v1` |
| Protein reaction time | 60 seconds |
| Blood reaction time | 60 seconds |
| Protein categories | `Neg`, `Trace`, `0.3`, `1.0`, `3.0`, `>=20.0` g/L |
| Blood categories | `Neg`, `Non-hemolyzed 10`, `Hemolyzed 10`, `Small 25`, `Moderate 80`, `Large 200` cells/uL |
| Protein positive threshold | `0.3 g/L` or higher |
| Blood positive threshold | Any supported non-negative blood category |

The category labels and 60-second protein/blood timing match the frozen model and an available URS-10T product chart. However, `URS-10T` is not a unique manufacturer identifier. Current project records contain placeholders (`GenericStrip`, `ModelX`, `LOT-TBD`) instead of a physical-bottle manufacturer and IFU revision.

Before external release, transcribe the manufacturer, legal manufacturer address, catalog number, lot number, and IFU revision from the physical bottle, box, and insert used for final testing. Do not infer a manufacturer from an online manual. A strip that does not match this frozen category order, chart, and timing is unsupported and activates `TECH-02`.

Category/timing cross-check: *Urine Testing Series Catalogue 2025*, product `UT-008`, URS-10T. This cross-check does not establish that UT-008 is the physical product used by the project.

## 5. Final rules

### 5.1 Technical validity

| Rule | Condition | Output and action |
|---|---|---|
| TECH-01 | Invalid image, uncertain strip, implausible strip geometry/color, or fewer than ten reliable pad regions | RETAKE. Do not interpret the protein or blood result. |
| TECH-02 | Strip is expired, damaged, read outside the manufacturer’s reaction time, or not supported by the application | RETAKE using the validated strip and procedure. |

The application must not claim that it can identify the wrong strip brand unless brand identification has been implemented and validated.

### 5.2 Safety overrides

| Rule | Condition | Output and action |
|---|---|---|
| SAFE-01 | Visible blood with clots or inability to urinate | PROMPT_CONSULT. |
| SAFE-02 | Markedly reduced or absent urine output | PROMPT_CONSULT. |
| SAFE-03 | Edema or unusual swelling with shortness of breath | PROMPT_CONSULT. |
| SAFE-04 | Fever/chills together with flank or back pain | PROMPT_CONSULT. |
| SAFE-05 | Fever or flank/back pain accompanied by nausea or vomiting | PROMPT_CONSULT. |
| SAFE-06 | Vomiting prevents drinking fluids or taking oral medication | PROMPT_CONSULT. |
| SAFE-07 | Severe flank or abdominal pain with visible or dipstick-detected blood | PROMPT_CONSULT. |
| SAFE-08 | Confusion, fainting, severe weakness, or signs of serious illness with urinary findings | PROMPT_CONSULT and show the application’s emergency safety-net instruction. |

Nausea or vomiting alone does not activate SAFE-05. Without the listed associated findings, the application should advise observation and consultation if the symptom persists, worsens, or prevents hydration.

### 5.3 Interference and temporary-cause rules

| Rule | Condition | Output and action |
|---|---|---|
| INT-01 | Menstruation, vaginal bleeding, or suspected contamination with a blood-positive dipstick result | REPEAT_CONFIRM. Do not treat dipstick blood as urinary or renal evidence. Recommend a properly collected repeat specimen after the interference resolves. |
| INT-02 | Recent strenuous exercise, fever, dehydration, or acute illness with protein detected | REPEAT_CONFIRM and explain that temporary conditions may affect urine protein. |
| INT-03 | Possible active UTI with protein detected | Do not describe the result as kidney disease or persistent proteinuria. Suggest professional consultation and reassessment after the infection is clinically addressed. |

Interference rules do not override safety rules or an independent reason for consultation.

### 5.4 Protein rules

| Rule | Condition | Output and action |
|---|---|---|
| PRO-01 | Protein negative; blood negative; no edema, visible blood, or safety trigger | OBSERVE. |
| PRO-02 | Trace protein only; blood negative; no edema or safety trigger | REPEAT_CONFIRM using a properly collected sample. Professional consultation may be suggested if it continues. |
| PRO-03 | Protein 1+ or higher, or manufacturer-defined positive when no trace category exists | CONSULT. Suggest professional interpretation and quantitative confirmation using urine ACR or PCR where clinically appropriate. |
| PRO-04 | Protein remains present on an appropriate repeat test after temporary causes are addressed | CONSULT. |
| PRO-05 | A previously positive result becomes negative on repeat, with no symptoms or warning findings | OBSERVE, while retaining any follow-up already advised by a healthcare professional. |

A single protein result must never be labelled “persistent.” The software mapping used for implementation is frozen in Section 4.2. Physical manufacturer and IFU identity must still be copied from the bottle and insert before external release.

### 5.5 Blood rules

| Rule | Condition | Output and action |
|---|---|---|
| BLD-01 | Trace or greater dipstick blood without visible blood or safety findings | REPEAT_CONFIRM. Explain that a dipstick alone does not confirm microhematuria; properly collected repeat urinalysis and/or microscopy may be recommended. |
| BLD-02 | Visible blood without clots, urinary obstruction, severe pain, or other safety findings | CONSULT. |
| BLD-03 | Blood remains present on an appropriate repeat test or is confirmed microscopically | CONSULT. |

The application must not label dipstick blood alone as confirmed hematuria or kidney disease.

### 5.6 Combined and edema rules

| Rule | Condition | Output and action |
|---|---|---|
| COMB-01 | Protein is positive and dipstick blood is trace or greater | CONSULT. Suggest professional interpretation, quantitative urine protein/albumin testing, and microscopy as clinically appropriate. |
| COMB-02 | Protein is positive and edema or unusual swelling is reported | CONSULT. |
| COMB-03 | Persistent or unexplained edema is reported, even when protein and blood are negative | CONSULT for assessment of renal and non-renal causes. |

These combinations are consultation triggers. They must not be converted into a kidney-disease diagnosis or probability.

## 6. Approved user messages

### OBSERVE — Observe for symptoms

> No renal-related follow-up trigger was identified from the available results and reported symptoms. This does not rule out a kidney or urinary tract condition. Consult a healthcare professional if symptoms appear, continue, or worsen.

### REPEAT_CONFIRM — Repeat or confirm the test

> A finding was detected that may be affected by sample collection or a temporary condition. A properly collected repeat urine test or professional consultation for confirmatory testing may be appropriate.

### CONSULT — Consultation suggested

> A urine-strip finding or related symptom was reported. These findings can have several causes and cannot diagnose kidney disease. Consultation with a healthcare professional and confirmatory laboratory testing are suggested.

### PROMPT_CONSULT — Seek prompt medical consultation

> A warning symptom or finding was reported. Please seek prompt medical consultation. If you feel severely unwell or symptoms rapidly worsen, seek emergency medical assistance. This result is not a diagnosis.

### RETAKE — Unable to interpret

> The relevant urine-strip result could not be interpreted reliably. Please repeat the test using the correct strip, collection method, timing, and scanning procedure. Seek professional care based on your symptoms even if the scan is unsuccessful.

## 7. Implementation pseudocode

```text
evaluate safety symptoms independently

if any prompt-consultation condition is present:
    output PROMPT_CONSULT
else if scan, protein, or blood result needed by the rule is unreliable:
    output RETAKE
else if visible blood is reported:
    output CONSULT
else if protein is positive and blood is trace-or-greater:
    output CONSULT
else if protein is positive and edema is reported:
    output CONSULT
else if persistent or unexplained edema is reported:
    output CONSULT
else if menstruation, vaginal bleeding, or contamination affects blood:
    output REPEAT_CONFIRM and do not interpret blood
else if a temporary condition may affect protein:
    output REPEAT_CONFIRM
else if possible active UTI and protein is detected:
    output CONSULT and recommend reassessment after clinical management
else if protein is manufacturer-positive:
    output CONSULT
else if protein is trace only:
    output REPEAT_CONFIRM
else if blood is trace-or-greater:
    output REPEAT_CONFIRM
else:
    output OBSERVE
```

When more than one rule fires, store every triggered rule for the audit trail and display the action with the highest priority. The explanation may list all relevant findings without using diagnostic language.

## 8. Required audit trace

For each evaluation, store locally:

- Rule-set version;
- Strip/model version;
- Scan-validity result;
- Protein and blood categories and reliability;
- User-reported inputs used;
- Interference flags;
- Every triggered rule identifier;
- Final internal action code;
- Exact message version shown;
- Date and time.

Do not store more personally identifiable or health information than the approved research and privacy protocol permits.

## 9. Guideline basis and limitations

1. **Philippine Clinical Practice Guidelines on UTI, 2015 Update, Part 2:** Supports professional evaluation for complicated or recurrent UTI situations, gross hematuria or persistent microscopic hematuria, failure or rapid relapse, possible obstruction or structural abnormality, pyelonephritis/systemic illness, and inability to maintain oral hydration or medication. It does not validate a general renal-disease algorithm based on protein and edema.
2. **KDIGO 2024 CKD Guideline:** Supports confirmation of reagent-strip-positive protein/albumin findings using quantitative laboratory measurements such as ACR or PCR, with attention to collection and temporary/interfering factors.
3. **AUA/SUFU Microhematuria Guideline:** A positive dipstick blood result alone does not define microhematuria and should prompt formal microscopic evaluation where clinically appropriate.
4. **Validated strip manufacturer’s instructions:** Must supply the pad order, reaction time, negative/trace/positive categories, units, reference colors, storage conditions, and known interferences used by the application.

The guideline cross-check supports the wording and referral logic; it does not establish diagnostic accuracy, clinical effectiveness, or population-wide validation.

## 10. Documentation of expert review

The project may state:

> The clinical content and referral-support rules were reviewed by a Family Medicine physician for scope, wording, referral recommendations, and safety considerations, and were cross-checked against applicable UTI, kidney-health, and hematuria guidelines.

The project must not state that physician review alone clinically validated the application.

Record the following before final physician comparison and external release:

- Physician reviewer name and credentials;
- Review date;
- Exact specification version reviewed (`v1.1`);
- Approved revisions or conditions;
- Signature or documented confirmation;
- Manufacturer, catalog number, lot, and exact strip product copied from the physical packaging;
- Final manufacturer-category mapping;
- Corresponding implemented software version and checksum.

## 11. Release conditions

The module is ready for programming only when:

- Every required user input exists in the application;
- The physical strip manufacturer, catalog number, lot, and IFU revision are recorded and checked against the frozen software profile;
- Safety rules override scan failure and lower-priority rules;
- No Low/Moderate/High renal-risk label remains;
- No diagnostic wording remains;
- Unit tests cover every rule and priority conflict;
- The physician confirms that the implemented wording matches this reviewed version;
- The app displays its screening/referral-support limitation.


---

## Snapshot: docs/URITECT_Bayesian_Parameter_Validation_Form_v1.3.md

# URITECT Sex-Specific Bayesian UTI Parameter Review Form v1.3

**Female model:** `uti_bayesian_female_v1_1_20260926`  
**Male candidate:** `uti_bayesian_male_v0_1_20261001`  
**Purpose:** Expert content review, not clinical validation

## Reviewer Brief

URITECT is an offline smartphone urinalysis screening and decision-support
application. It uses separate literature-derived female and male research
models. Please review whether the proposed laboratory mappings, evidence
parameters, and limitations are relevant and clearly implemented.

The output is not a diagnosis, treatment recommendation, or replacement for
urine culture or professional judgment. Further clinical and statistical
validation is required before the percentages can be interpreted as
clinically validated estimates.

## Female Parameters

| ID | Finding or pattern | Candidate value | Source |
| --- | --- | ---: | --- |
| F01 | Starting prior in eligible symptomatic women | 50% | Bent 2002; Kurotschka 2024 |
| F02 | Nitrite positive | LR 5.50 | Kurotschka 2024 |
| F03 | Leukocyte esterase positive | LR 1.40 | Kurotschka 2024 |
| F04 | Dipstick blood positive | LR 1.70 | Kurotschka 2024 |
| F05 | Nitrite plus leukocytes or blood | LR 7.20 | Little 2006 |
| F06 | Nitrite, leukocytes, and blood all negative | LR 0.22 | Little 2006 |
| F07 | Dysuria and urgency | LR 1.50 | Kurotschka 2024 |
| F08 | Dysuria | LR 1.30 | Kurotschka 2024 |
| F09 | Urgency | LR 1.20 | Kurotschka 2024 |
| F10 | Frequency | LR 1.10 | Kurotschka 2024 |

## Male Candidate Parameters

| ID | Finding or pattern | Candidate value | Source |
| --- | --- | ---: | --- |
| M01 | Younger male subgroup starting prior | 52.2% | Derived from den Heijer 2012 Table 3 |
| M02 | Nitrite and leukocyte esterase positive | LR 5.14 | den Heijer 2012 Table 2 |
| M03 | Nitrite-positive threshold | LR 4.87 | den Heijer 2012 Table 2 |
| M04 | Leukocyte-est-positive threshold | LR 1.65 | den Heijer 2012 Table 2 |
| M05 | Nitrite and leukocyte esterase both negative | LR 0.35 | den Heijer 2012 Table 2 |

The male values are applied in an ordered hierarchy, with one LR only. The
source reports overlapping score thresholds rather than exact mutually
exclusive pattern LRs. M03 and M04 are therefore a documented URITECT research
approximation requiring statistical and culture-confirmed validation.

## Mapping and Use Statements

Rate each statement: `4 = highly relevant/acceptable`, `3 = minor revision`,
`2 = major revision`, `1 = not acceptable`.

| ID | Review statement | 1 | 2 | 3 | 4 | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| C01 | Female nitrite, LE, and blood mappings match the stated source thresholds. | [ ] | [ ] | [ ] | [ ] | |
| C02 | Female Trace 15 LE is neutral because the female source threshold is `+` or greater. | [ ] | [ ] | [ ] | [ ] | |
| C03 | Male Trace 15 LE is positive because the male study counted any color change. | [ ] | [ ] | [ ] | [ ] | |
| C04 | Nitrite requires the strip category `Positive` in both models. | [ ] | [ ] | [ ] | [ ] | |
| C05 | Blood is appropriately omitted from the male numerical model. | [ ] | [ ] | [ ] | [ ] | |
| C06 | One mutually exclusive factor prevents duplicate multiplication of correlated dipstick evidence. | [ ] | [ ] | [ ] | [ ] | |
| C07 | Missing and unreliable results correctly receive no update. | [ ] | [ ] | [ ] | [ ] | |
| C08 | The female and male eligibility restrictions are understandable. | [ ] | [ ] | [ ] | [ ] | |
| C09 | Safety and alternate-cause findings are appropriately handled outside the equation. | [ ] | [ ] | [ ] | [ ] | |
| C10 | The lack of local calibration and culture-confirmed validation is stated clearly. | [ ] | [ ] | [ ] | [ ] | |

## Parameter Ratings

Please separately rate each parameter listed as F01-F10 and M01-M05.

| Parameter ID | 1 | 2 | 3 | 4 | Recommended revision or comment |
| --- | --- | --- | --- | --- | --- |
| F01 | [ ] | [ ] | [ ] | [ ] | |
| F02 | [ ] | [ ] | [ ] | [ ] | |
| F03 | [ ] | [ ] | [ ] | [ ] | |
| F04 | [ ] | [ ] | [ ] | [ ] | |
| F05 | [ ] | [ ] | [ ] | [ ] | |
| F06 | [ ] | [ ] | [ ] | [ ] | |
| F07 | [ ] | [ ] | [ ] | [ ] | |
| F08 | [ ] | [ ] | [ ] | [ ] | |
| F09 | [ ] | [ ] | [ ] | [ ] | |
| F10 | [ ] | [ ] | [ ] | [ ] | |
| M01 | [ ] | [ ] | [ ] | [ ] | |
| M02 | [ ] | [ ] | [ ] | [ ] | |
| M03 | [ ] | [ ] | [ ] | [ ] | |
| M04 | [ ] | [ ] | [ ] | [ ] | |
| M05 | [ ] | [ ] | [ ] | [ ] | |

## Overall Decision

[ ] Acceptable as provisional literature-derived research parameters  
[ ] Acceptable with minor revisions  
[ ] Major revision required before research use  
[ ] Unable to assess

Comments:  
________________________________________________________________________  
________________________________________________________________________  
________________________________________________________________________

## Acknowledgment

I reviewed the proposed literature-derived parameters, strip mappings, and
screening logic for their stated research purpose. I understand that this
expert content review does not independently establish diagnostic accuracy,
clinical calibration, sensitivity, specificity, or clinical validity of the
complete URITECT models.

Reviewer name: _________________________________________________  
Professional position: _________________________________________  
PRC license number: ____________________________________________  
Institution: ___________________________________________________  
Signature: ______________________________ Date: _________________

## References

1. den Heijer CDJ, et al. *Br J Gen Pract*. 2012;62:e780-e786.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC3481519/
2. Koeijers JJ, et al. *Clin Infect Dis*. 2007;45:894-896.
   https://pubmed.ncbi.nlm.nih.gov/17806056/
3. Kurotschka PK, et al. *Am Fam Physician*. 2024;109:167-174.
4. Little P, et al. *Br J Gen Pract*. 2006;56:606-612.
5. Bent S, et al. *JAMA*. 2002;287:2701-2710.



---

## Snapshot: docs/URITECT_Bayesian_Review_Cover_Letter_v1.3.md

# Request for Expert Content Review

**Krizzler Faith M. Montaño, RMT**  

Registered Medical Technologist

**Dear Ms. Montaño:**

Greetings!

We are fourth-year Bachelor of Science in Computer Science students from West
Visayas State University. As part of our undergraduate thesis, we developed
**URITECT**, an offline smartphone-based urinalysis dipstick screening and
clinical decision-support application.

We respectfully request your professional review of the proposed urinalysis
dipstick mappings and literature-derived likelihood-ratio parameters used in
URITECT's sex-specific Bayesian urinary tract infection (UTI) research
component.

URITECT serves eligible male and female adult users for ten-analyte strip
scanning, safety assessment, and renal follow-up. Its UTI research component
uses separate evidence pathways because the available studies differ by sex:

- The female candidate model uses evidence derived principally from
  symptomatic, nonpregnant women.
- The male candidate model uses culture-referenced evidence from symptomatic
  men and is limited to nitrite and leukocyte esterase. Female blood and
  symptom likelihood ratios are not applied to men.

A likelihood ratio describes how a finding changes the evidence supporting
UTI. A value greater than 1 increases the evidence, a value below 1 decreases
it, and a value of 1 produces no update. An LR is not itself a percentage.

The attached form shows every candidate value, its source, the exact strip
mapping, and how URITECT prevents correlated findings from being counted more
than once. The resulting estimates are provisional, literature-derived, and
not locally calibrated. They do not diagnose UTI, recommend treatment, replace
urine culture, or replace professional judgment. URITECT does not convert the
estimates into Low, Moderate, or High categories.

We ask you to assess whether the laboratory mappings, candidate parameters,
handling of missing or unreliable results, and screening workflow are relevant
and acceptable for the stated research purpose. Further physician, clinical,
statistical, and culture-confirmed patient-level validation is required before
the estimates can be described as clinically validated probabilities.

Thank you for sharing your professional time and expertise.

Respectfully,

The URITECT Research Team

Bachelor of Science in Computer Science  
West Visayas State University


---

## Snapshot: docs/MANUSCRIPT_FINAL_REVISION_GUIDE.md

# URITECT Manuscript Final Revision Guide

The current source available in the repository is
`docs/BSCS_Group5_Manuscript_50.pdf`; no editable manuscript source is present.
The PDF cannot be safely rewritten as a thesis source document. Apply the
changes below to the original Word/Google Docs file, then replace the exported
PDF.

## Global Replacements

Search the entire manuscript, including captions, diagrams, tables, abstract,
and conclusion.

| Current claim to remove | Final replacement |
| --- | --- |
| Python/FastAPI scan server, SciPy runtime, HTTP endpoint | All production scan and interpretation logic executes locally in Flutter/Dart on Android. |
| Marker-based or macromarker localization | Markerless strip localization based on plausible strip geometry and color/chroma activity. |
| Adaptive thresholding and contour detection as the final ROI algorithm | Orientation search, strip-candidate scoring, pad-column detection, chroma-activity row localization, and ten-pad geometry validation. |
| k-NN probabilities sent directly into disease Bayesian fusion | k-NN outputs semiquantitative analyte classes and confidence. The UTI research model maps source-matched LEU/NIT/BLD categories into one grouped dipstick LR. |
| Four sentinel analytes GLU/PRO/LEU/NIT in one Bayesian disease engine | Bayesian inference is limited to gated lower-UTI screening using LEU/NIT/BLD. Renal follow-up is a separate deterministic rule engine using protein, blood, symptoms, repeat history, safety, and interference inputs. |
| Low/Moderate/High UTI risk or 20/80, 30/70, or 35/70 thresholds | Display the provisional posterior with its prior and applied LRs only for eligible calculations, plus Observe, Consultation suggested, Prompt medical consultation suggested, or Insufficient evidence. Do not convert the number into a probability band. |
| Bayesian renal probability | Deterministic renal follow-up action; no renal probability and no renal diagnosis. |
| 80% overall app/scan accuracy | 82.52% individual-analyte accuracy and 17.18% all-ten-correct whole-scan accuracy under specimen-grouped evaluation. |
| Random train/test split with images treated independently | Specimen-grouped 80/20 split; all lighting variants from one specimen remain on one side. |
| ISO compliance/certification | Evaluation guided by ISO/IEC 25010. |

## Title and Abstract

Keep “Bayesian Late Fusion” only if the abstract immediately limits it to the
provisional, literature-derived UTI research pathway. State that renal output
uses deterministic follow-up rules. Include offline Android execution,
markerless ten-pad processing, the exact model version, grouped evaluation, and
both individual and whole-scan accuracy. Do not call the posterior clinically
calibrated or validated.

## Chapter 1

### General objective

Describe an offline Android urinalysis screening prototype with markerless
computer vision, ten-analyte k-NN classification, gated Bayesian UTI research
interpretation, and separate renal follow-up rules.

### Specific Objective 2

Retain the unreacted strip/plastic reference concept, but use this operational
wording:

> Develop a neutral strip/plastic-referenced gray-world normalization method
> that estimates channel gains from low-saturation pixels adjacent to the
> detected reagent-pad stack to reduce lighting-related color shifts.

### Specific Objective 3

Replace adaptive-threshold/contour wording with:

> Develop an offline Android application with markerless strip localization
> and automated ten-pad ROI extraction using orientation search, strip geometry,
> color/chroma activity, pad-spacing validation, and invalid-scan rejection.

### Specific Objective 4

Use:

> Train and evaluate per-analyte k-nearest neighbors models using accuracy,
> macro F1-score, one-vs-rest macro sensitivity and specificity, and Cohen's
> kappa under specimen-grouped splitting; integrate source-matched dipstick
> categories and symptoms into a gated Bayesian UTI research estimate, while
> producing renal follow-up through a separate deterministic rule engine.

### Scope and limitations

State the supported strip profile and unresolved physical-manufacturer gate.
Describe the female v1.1 pathway as limited to symptomatic, nonpregnant women aged 18-64 with
all six eligibility confirmations and no alternate-cause/systemic finding.
State that no culture-confirmed calibration study was performed.

## Chapter 3

Document these exact reproducible details:

- Laua-an plus Cabatuan 2026-07-15 and 2026-07-17 cleaned packages.
- 7,840 final analyte rows; zero exact duplicates removed by the frozen key.
- 257 capture bursts rejected during corrected markerless ingest.
- Normalized HSV features and analyte-specific `k`, distance metric, and feature
  transform from the final report.
- GroupShuffleSplit, test size 0.20, random state 42, group `specimen_group`.
- Confidence threshold 0.45 applied to every analyte at scan acceptance.
- UTI v1.1 eligibility, mapping, grouped LR hierarchy, and audit-only posterior.
- Renal v1.1 rule IDs, priority order, final action, and invalid-scan safety
  override.

Do not describe unselected symptoms as confirmed absent. Unselected/unknown,
unavailable, or unreliable inputs receive no Bayesian update. Add the separate
male v0.1 candidate from the sex-specific v1.2 specification: symptomatic men
18-64, study-matched exclusions, 52.2% younger-subgroup prior, and one ordered
nitrite/leukocyte threshold LR. State that its threshold hierarchy and local
calibration require prospective culture-confirmed validation.

## Chapter 4

Replace architecture, sequence, activity, deployment, and data-flow diagrams
that still show Python, FastAPI, HTTP, macromarkers, four-sentinel fusion, or
risk buckets. The final flow is:

```text
Android image capture/gallery
  -> image-quality rejection
  -> orientation search
  -> markerless strip localization
  -> neutral strip/plastic AWB
  -> ten-pad ROI validation
  -> normalized HSV extraction
  -> ten per-analyte k-NN predictions
  -> confidence retake gate
  -> separate UTI, systemic/alternate-cause, and renal outputs
  -> local history
```

The k-NN library is not shipped as Python/scikit-learn. Training uses
scikit-learn; the frozen neighbors, labels, scaling parameters, feature
transforms, metrics, and `k` values are serialized to JSON and the same
algorithm is executed in Dart on Android.

## Results

Use `pipeline/output/production_grouped_metrics_complete.json` as the classifier
source. Report the full per-analyte table from `FINAL_PROJECT_HANDOFF.md`, class
support/confusion matrices where space permits, and the confidence-gated
coverage results. Explain that weak macro F1/sensitivity for some analytes
reflect class imbalance and rare-level performance despite high aggregate
accuracy.

Do not compute diagnostic sensitivity/specificity for UTI or renal disease from
the reagent-class metrics. No culture-confirmed disease reference standard was
used for the Bayesian model.

## Objective 5 and ISO/IEC 25010

Use the prepared 10-medtech form. Report task-success results, per-item and
per-characteristic means/standard deviations, observed processing time, defects,
and overall decisions. Call this an ISO/IEC 25010-guided evaluation, not
certification. Do not mark Objective 5 complete before data collection.

## Conclusion

Conclude only that the offline prototype achieved the stated individual-analyte
performance under the frozen grouped evaluation and implements conservative
screening/referral-support logic. Explicitly retain these limitations:

- Whole-scan all-ten-correct accuracy is 17.18%.
- Specific Gravity and Leukocytes remain weak analytes.
- Cross-device and real-world invalid-image acceptance require field testing.
- Physical manufacturer/IFU identity must be recorded.
- Bayesian probability calibration and diagnostic validation require
  culture-confirmed prospective cases.
