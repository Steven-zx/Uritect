# Final Acceptance and Proof Checklist

This checklist separates verified repository evidence from activities that must
be performed by the research team or clinical evaluators.

## Verified in the Repository

| Requirement | Status and evidence |
| --- | --- |
| Offline production scan path | Complete. Main Android manifest has no Internet permission; `ScanAnalysisService` delegates to local Dart analysis. |
| Ten-analyte semiquantitative Android model | Complete. `assets/production_semiquant_model.json` contains all ten analyte models. |
| One frozen visual model | `production_semiquant_knn_markerless_roi_topfix_v3_20260908`. |
| Python/Android model parity | 2,000 checked predictions, zero mismatches. |
| Duplicate control | 7,840 raw and 7,840 deduplicated rows; zero exact duplicate rows under the frozen key. |
| Leakage control | GroupShuffleSplit by specimen group, test size 0.20, random state 42. |
| Complete Objective 4 metrics | Accuracy, macro F1, macro sensitivity, macro specificity, kappa, class support, and confusion matrices in `production_grouped_metrics_complete.json`. |
| Whole-scan reporting | 17.18% all-ten-correct, reported separately from 82.52% individual-analyte accuracy. |
| Confidence retake | Threshold 0.45 for every analyte; grouped accepted-scan metrics documented. |
| Markerless ROI/AWB | Production service uses markerless geometry/chroma localization and neutral strip/plastic gray-world normalization. |
| Invalid-scan rejection | Blank, blur, exposure, partial/geometry, ambiguity, ten-pad, and confidence checks implemented. |
| Bayesian UTI v1.1 | Eligibility gate, source-threshold mapping, grouped LRs, explicit prior/posterior/factor display for eligible calculations, and no risk bands. |
| Renal rules v1.1 | Dedicated engine, rule IDs, final action, separate UI, safety overrides, and tests. |
| Action wording | App uses Observe, Consultation suggested, Prompt consultation suggested, or Insufficient evidence instead of UTI Low/Moderate/High bands. |
| Medtech materials | Two-medtech parameter form and ten-medtech final-app form prepared. |
| APK | `output/apk/Uritect_v1.3.0_bayesian_v1.1_renal_v1.1_release.apk`. |
| Release checksum | Recorded in `output/release/URITECT_FINAL_RELEASE_MANIFEST.json`. |

## Manual Release Gates

| Gate | Required evidence |
| --- | --- |
| Physical strip identity | Manufacturer, address, catalog, lot, expiry, IFU revision, reaction times, and chart copied from the actual product. |
| Target-device install | APK installs and launches on every selected Android test device. |
| Airplane-mode workflow | Capture through saved history succeeds with airplane mode enabled. |
| ROI verification | Saved overlays show all ten boxes centered inside the reagent pads across light conditions and phones. |
| Invalid-image challenge | Blank, blurred, partial, wrong-object, multiple-strip, dark, overexposed, and unsupported-strip cases are documented. |
| Wrong-brand claim | Do not claim brand recognition unless a negative-example brand validator is separately trained and tested. |
| Latency | Capture-to-result time recorded per target phone. |
| Privacy/storage | Permission prompts, local persistence, reopening, deletion, backup behavior, and absence of unintended identifiers checked. |
| Bayesian content review | Two medtechs complete v1.2; physician/statistical boundaries remain stated. |
| Renal sign-off | Physician compares the exact app wording/rules with renal v1.1 and signs the packet. |
| Final app evaluation | 10 medtechs complete the ISO/IEC 25010-guided instrument; results are analyzed. |
| Manuscript alignment | Every item in `MANUSCRIPT_FINAL_REVISION_GUIDE.md` is resolved in the editable thesis source. |

## Required Reporting Sentence

> The frozen production model achieved 82.52% individual-analyte accuracy
> (1,345/1,630 predictions) under specimen-grouped evaluation. Whole-scan
> accuracy, defined as all ten analytes correct in the same scan, was 17.18%
> (28/163 scans). With the 0.45 confidence retake threshold, 73.62% of grouped
> test scans were accepted; accepted scans achieved 83.75% individual-analyte
> accuracy and 19.17% all-ten-correct accuracy.

Do not shorten this to “the app is 80% accurate.”
