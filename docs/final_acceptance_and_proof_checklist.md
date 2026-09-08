# Final Acceptance And Proof Checklist

This checklist separates completed implementation evidence from items that
require real-device or clinical/manual review. Do not mark the manual gates as
passed until they are actually performed.

## Completed In Repository

| Requirement | Evidence |
| --- | --- |
| Remove Python/network server dependency from app scan path | `uritect_app/lib/services/scan_analysis_service.dart` delegates to local Android scanning |
| Remove production internet/network manifest permissions | `uritect_app/android/app/src/main/AndroidManifest.xml` has no internet or network-state permissions |
| Run ten-analyte semiquant model directly on Android | `uritect_app/lib/services/local_scan_analysis_service.dart` loads `assets/production_semiquant_model.json` |
| Freeze one production model | `pipeline/output/semiquant_models` and `uritect_app/assets/production_semiquant_model.json` use `production_semiquant_knn_markerless_roi_topfix_v3_20260908` |
| Verify Python-to-JSON prediction parity | `pipeline/validate_production_json_model.py` checked 2,000 predictions with zero mismatches |
| Remove duplicate feature rows before final grouped evaluation | `pipeline/output/production_grouped_evaluation.json` reports 7,840 raw rows, 7,840 deduped rows, 0 duplicates removed |
| Prevent specimen leakage in final evaluation | GroupShuffleSplit by `specimen_group`; all lighting variants from a specimen stay on the same split side |
| Recalculate metrics | Individual-analyte accuracy 82.52%; whole-scan all-ten-correct accuracy 17.18% |
| Apply corrected ROI gate during production ingest | 257 capture bursts rejected before model training/evaluation |
| Apply confidence retake gate | Android JSON requires every analyte prediction to reach confidence threshold `0.45`; accepted-scan grouped metrics are in `pipeline/output/whole_scan_optimization_final_knn_grouped.json` |
| Remove inactive Bayesian/probability code | Bayesian fusion files, probability package export, and stale app probability fields were removed |
| Keep separate clinical outputs | `screening_fusion.dart` outputs localized UTI, systemic warning, renal follow-up, and metabolic follow-up categories |
| Fix release APK build | Release build completed successfully; APK at `uritect_app/build/app/outputs/flutter-apk/app-release.apk` |
| APK checksum | SHA256 `3C8322479429C7B64599B61F35D116B37370E91CA5702FA98B5A682FD341420F` |

## Manual Gates Still Required

| Gate | Status |
| --- | --- |
| Install release APK on target Android devices | Not claimed until tested on actual devices |
| Airplane-mode capture-to-history scan | Not claimed until tested on actual devices |
| ROI overlays from Android capture images | Not claimed until real Android captures are reviewed |
| Blank, blurred, partial, and wrong-object rejection on target devices | Not claimed until tested with controlled invalid images |
| Wrong-strip brand rejection | Not guaranteed without negative examples or a trained brand/strip validator; current logic rejects implausible strip geometry/color, not brand identity |
| Latency on target Android devices | Not claimed until measured |
| Local storage, deletion, backup, and privacy behavior | Not claimed until verified on target Android devices |
| Clinical safety wording and rule table review | Requires medical/clinical reviewer signoff |

## Reporting Rule

Use this wording unless a later validated evaluation replaces it:

> The frozen production model achieved 82.52% individual-analyte accuracy under
> specimen-grouped evaluation. Whole-scan accuracy, defined as all ten analytes
> correct in the same scan, was 17.18%. With the production confidence retake
> threshold of 0.45, 73.62% of grouped test scans were accepted; among accepted
> scans, individual-analyte accuracy was 83.75% and all-ten-correct accuracy
> was 19.17%.
