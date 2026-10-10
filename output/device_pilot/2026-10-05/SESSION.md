# Progressive checklist pilot — 2026-10-05

User requested the attached progressive/conditional questionnaire proposal, explicitly deferring new Bayesian LR values. Implemented five progressive stages: basic information, sex-specific pathway, shared safety, conditional follow-up context, and expandable test quality.

Explicit Yes/No/Not sure answers and questionnaireVersion persist with existing clinical flags. Input gate version is interpretation_gates_v2_20261005. Current model IDs, priors, numerical LRs and rule priorities remain. Unknown safety/urinary/alternate-cause inputs prevent an ordinary estimate for new records; uncertain quality prevents strip interpretation without suppressing known safety findings.

Validation: flutter analyze --no-pub: no issues found. Final full suite: 81 tests passed; log checklist_tests.log. Existing parameter/rule/history/retake/startup/camera checks passed along with seven new progressive questionnaire tests. git diff --check clean.

No ADB device connected at preflight. User chose: Prepare the APK; I’ll test later. Do not install or claim a physical walkthrough. Pilot APK build 1.4.0+11 pending packaging at this entry.

Read docs/URITECT_PROGRESSIVE_CHECKLIST_2026-10-05.md for implementation and later test cases.

Release build completed successfully (175.7 s). Archived output/device_pilot/2026-10-05/Uritect_v1.4.0+11_progressive_checklist_pilot.apk, SHA-256 93ECB1B4DE8C35AC4C657BABD10C16EBBFDD98A7F975A631F4820BB0FE5373E6. Installation deferred at user request; physical walkthrough pending.
aapt confirms package ph.edu.wvsu.uritect, versionCode 11, versionName 1.4.0, minSdk 24 and targetSdk 36.


## Pilot 12: workflow and image fixes

Prepared Uritect_v1.4.0+12_workflow_image_fixes_pilot.apk. APK badging verified ph.edu.wvsu.uritect, version 1.4.0, versionCode 12, minSdk 24, targetSdk 36. SHA256: 8C1C606DEB1361B105D3F5A4FBD23D6388B9CC24B5499C4CAC16CC3A0EBC62C9.

90 Flutter tests, 18 Python tests and clean static analysis. Pickle/JSON parity: 7,840 predictions, zero mismatches. In 18 retrospective image cases, accepted captures increased from four to six with no loss or prediction changes among the four shared accepted captures. All-ten-correct remained one; abnormal detection is not solved. Source evidence: 146 events linked to 408 review rows; 63 priority images processed, six geometry rejections and 14 cached-feature review events.

ADB showed no device at the final check. APK was not installed. Phone workflow testing, medtech reference/timing adjudication and new independent clinical validation remain pending. See docs/URITECT_WORKFLOW_AND_IMAGE_FIXES_2026-10-05.md and PILOT_BUILD_1.4.0+12.json.
