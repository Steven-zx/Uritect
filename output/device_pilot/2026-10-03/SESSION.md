# URITECT device acceptance and pilot — 2026-10-03

## Session state

Target build: Android 1.4.0+5, ph.edu.wvsu.uritect.
Phone model: RMX3933 (user-reported). Android version: pending detection.
Initial ADB check: no attached devices. USB debugging/authorization requested.
No on-device checks have passed yet.
Automated test attempt in restricted runtime could not access Flutter SDK cache lockfile; rerun started with SDK access.

## Execution order and evidence

| ID | Check | Status | Evidence to record |
| --- | --- | --- | --- |
| D01 | Detect authorized phone and record model/Android | Pending | ADB device status; model; OS version |
| D02 | Verify installed package/version; install release if needed | Pending | APK checksum; package version; install output |
| D03 | Launch and check startup/navigation/layout | Pending | Screenshot; launch result; relevant app errors |
| D04 | Camera/gallery permissions and denied-permission recovery | Pending | Observed prompts and recovery |
| D05 | Valid ten-pad scan with airplane mode, Wi-Fi and mobile data off | Pending | Inputs; ten results; processing duration |
| D06 | ROI centering across lighting conditions | Pending | Ten-pad overlay for each capture |
| D07 | Blank/wrong-object/blur/partial/multiple-strip/dark/overexposed challenges | Pending | One observed outcome per input |
| D08 | Confidence retake behavior | Pending | Input; confidence; retake message |
| D09 | Female/male eligibility, missing inputs, prior/LR/model display | Pending | Synthetic checklist cases; expected and actual behavior |
| D10 | Separate renal follow-up and systemic/alternate-cause guidance | Pending | Synthetic case; action and rule details |
| D11 | Save/reopen/relaunch persistence and delete session-created record | Pending | Before/after observations; no pre-existing data removal |
| D12 | Repeat scans and record latency/crashes | Pending | Per-run timings; crash evidence |

## Physical-scan inputs required

Record manufacturer, catalog, lot, expiry, IFU revision, reaction times and chart from the actual bottle/box/IFU. Use reference-labelled or control material where available; record the reference method and lighting. Software workflow success alone does not establish analyte or disease accuracy.

## Pilot boundary

This session is a technical rehearsal. It does not replace two-medtech Bayesian content review, physician renal sign-off, ten-medtech ISO/IEC 25010-guided app evaluation, or prospective culture-confirmed clinical validation. Do not invent ratings, reference labels or passed tests. Use docs/URITECT_ISO25010_MedTech_App_Evaluation_v1.0.md for subsequent evaluator sessions.

## Completed preflight checks

- flutter test --reporter expanded: exit 0, 56 tests passed.
- flutter analyze --no-pub: exit 0, no issues found.
- ADB checks in restricted and normal Windows runtime: no devices attached after user enabled debugging. Windows present-device search found no matching ADB/Android/RMX/realme/MTP entries. Device connection remains unresolved; no installation or on-phone tests performed.
- Restarted ADB service; device list remained empty.

## Wi-Fi connection and installation

- ADB detects authorized RMX3933 over wireless debugging.
- Device reports Android 16.
- Release APK installation returned Success.
- Offline scan, camera, ROI, latency, and history checks remain pending.

## Workflow test start

- Authorized wireless phone connection remains active.
- Brought existing URITECT task to foreground successfully (hot launch; Android am start TotalTime 217 ms, not scan latency).
- Captured workflow_start.png: existing result page, expanded Checklist Review (16/42 selected), banner states Invalid scan; no analyte values interpreted. Input provenance and safety action not yet verified, so invalid-image test not marked passed.
- Next controlled case: no-strip image, followed by user-observed rejection and symptom-safety behavior.

## Pilot defect: NEW SCAN retains previous photo

User reported retake appeared stuck and reused the previous photo after an invalid scan. Root cause: AnalyzingPage used pushReplacement for ResultsPage; that completed the camera page navigation future with null before ResultsPage could return scanAgain. Fix: keep the analysis route pending while results are displayed, then forward the results exit reason back to capture; stop the analysis progress timer while results are shown. Both valid and rejected results use this return path.

Validation: existing 56 tests passed after navigation fix; new controlled invalid-analysis retake navigation regression passed separately. Final static analysis reports no issues. Phone retest pending updated APK installation. Original 1.4.0+5 release APK and manifest are preserved; new pilot uses build code 6.

Final suite: 57 tests passed; static analysis: no issues. Release build completed successfully. Installed separate pilot APK Uritect_v1.4.0+6_retake_fix_pilot.apk via adb install -r (Success). APK SHA-256: 913B443E9C601FF012700EF84D777A6068DB07427C74A5F5D664EB0D7EF4762E. Physical retake test pending user observation.

Phone retest: user confirms NEW SCAN now works properly in pilot build 1.4.0+6. Retake defect resolved by user observation.

Methodology audit source changes: 69 tests passed; static analysis clean. See docs/URITECT_Methodology_Implementation_Audit_2026-10-03.md. Statistical Issues 1–3 remain unresolved. Audited source has NOT been installed on phone; phone still uses retake-only build 1.4.0+6.

## Audit safeguards pilot build 1.4.0+7

Requested continuation: build audited source and reconnect phone. Initial ADB and mDNS discovery returned no attached/discovered devices. Build started with --build-number=7; prior 69 passing tests and clean analysis apply to this unchanged audited source. Installation and device workflow checks are pending.

Build 7 installed successfully on wireless RMX3933; Android package reports versionCode 7. Visible home screen verified in pilot7_launch.png after startup. Phone screenshot exposed a recent-scan layout defect: an unconstrained long clinical-action label leaves the date/time almost no horizontal space. Layout repair in progress; workflow tests remain pending.

Build 8: history card layout correction formatted; flutter analyze --no-pub clean. Release build successful. Archived Uritect_v1.4.0+8_history_layout_pilot.apk, SHA-256 9FE4502E5C2E77ADFB27E3F7A8DD7666908AFC7654466D49E69CEEF1CE16351D. Installed successfully; device reports versionCode 8/versionName 1.4.0. Cold launch Status ok (2911 ms app launch, not scan latency). pilot8_launch.png visually verifies readable date/time, wrapped long action text, visible delete button and preserved existing record. Prior 69-test result applies to audit source before this layout-only change; suite was not rerun for layout. User selected invalid-image/retake test, actual observations pending.
