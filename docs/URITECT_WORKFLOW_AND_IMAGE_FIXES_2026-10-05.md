# Workflow and image fixes: research pilot 1.4.0+12

Date: 2026-10-05. Purpose: implement the available development priorities and prepare the next phone pilot. This build is not clinically validated.

## Changes in this pilot

The capture page now releases/reinitializes its camera across background/resume transitions, including gallery and lock-screen transitions. Initialization and release are serialized. A capture completing after its camera session changes is discarded, preventing stale-photo restoration. Capture, gallery selection and submission cannot overlap, and asynchronous flash changes cannot update an obsolete session.

The on-device detector previously used absolute saturation to find a strip. A blue-lit background could become one oversized candidate, rejecting a plainly visible strip. The app now retains existing valid geometry first and tries background-relative detection only when every original orientation fails geometry validation. The fallback compares pixels to side-margin background colors on the same row, accounting for a lighting gradient. Confidence does not choose the detector, and the frozen 0.45 abstention setting remains unchanged.

Every orientation candidate must pass the geometry checks before selection. Both Python and Dart reject irregular spacing; individual gaps outside 0.60–1.40 of the median are rejected in addition to the existing 0.24 gap-variation limit. These are engineering geometry checks, not clinical acceptance thresholds. The Python detector previously accepted ten boxes without checking spacing. A successful ten-region count can contain background, plastic gaps or a handle; count alone no longer suffices.

Scan JSON now preserves pipeline_version separately from modelVersion. New scans identify android_markerless_json_knn_v2_background_20261005; old history without a processing version remains unknown. SavedScanRecord retains this through its nested ScanResult. No clinical priors, likelihood ratios, renal rules, classifier parameters, training labels or production model assets were changed in this task.

## Evidence recovered and reviewed

All 146 events represented in the 408 error-review rows now link to recovered source images. Original RHU archives are in new_uritect_dataset. Processed LAUAAN images were resolved from Documents/uritect_training_dataset/packages/LAUAAN_20260730_ID_CLEANED_2026-07-30.zip; processed Cabatuan packages are in pipeline/dataset/cabatuan_cleaned.

Sixty-three priority images have historical and checked technical evidence. Fourteen historical sequences exceeded the existing overall spacing limit. Applying the complete spacing checks produced 57 candidate extractions requiring review and six rejections. Fourteen events have changed geometry or fail geometry and are listed in cached_feature_review_queue.csv. This does not certify the other cached features or establish reference labels.

Visual inspection of LAUAAN-P018-L2700 established a localization issue: historical top crop boxes include background above the physical strip. A spacing-only revision still includes a plastic gap/handle. The complete geometry check rejects this photo. Its technical localization note is recorded, while clinical adjudication and reaction timing remain pending. The Cabatuan 028 Cool overlay shows boxes aligned with visible pads, but an aligned crop does not establish the chemical category or the correctness of its label.

The review CSV retains historical image_path/pad_crop_path and manual review fields. checked_crop_status, checked_pad_crop_path, checked_overlay_path and checked_pad_gap_cv point to the new evidence. Clinical review_status remains pending. Do not use a historical crop when the checked result says extraction_failed_requires_review.

Local source photos and crop directories are ignored by Git. The small de-identified Cabatuan strip-only fixture is included for software regression testing. No participant names or medical workbook sheets were copied into the app.

## Verification and its limits

The exported JSON model agrees with the frozen pickle model on all 7,840 cached feature rows. This is export parity, not independent classification accuracy.

A purposive regression sample contains 18 previously reviewed development photos across the three packages and lighting variants. The pre-change analyzer accepted four; the final analyzer accepts six. All four previously accepted captures retain identical predictions. Two previously rejected daylight images are recovered. Twelve images still require retakes. All-ten-category correctness is one before and one after. Therefore this check demonstrates improved acquisition coverage on this sample; it does not demonstrate improved abnormal-class detection or final clinical performance.

The direct replacement background-mask revision initially lost four working captures. It was superseded by the legacy-preserving fallback before packaging. The superseded regression record is retained for audit. The prepared build contains the fallback revision.

The full Flutter suite covers startup, invalid-image retake navigation, checklist branches, safety gates, renal follow-up, history, camera lifecycle/races, decoder rejection, same-photo camera/gallery parity, physical 90/180-degree rotation and rejection of two strips. Python tests cover split/approval metadata, threshold semantics, missing class support, clustered repeats, and malformed pad sequences. Results and APK identity are recorded in the pilot manifest and logs.

Same-byte file parity does not establish equality between an in-app capture and a separate phone Camera-app capture. Different focus, exposure, processing, lighting or timing can change the pixels. Physical phone testing remains required; ADB showed no device at this session's checks.

## Reproduce the technical checks

~~~powershell
& '.\.venv\Scripts\python.exe' pipeline/validate_production_json_model.py --max-rows-per-analyte 10000
& '.\.venv\Scripts\python.exe' -m unittest discover -s pipeline -p 'test_*.py' -v
& '.\.venv\Scripts\python.exe' pipeline/prepare_abnormal_image_review.py --evidence-name image_evidence_geometry_checked
& '.\.venv\Scripts\python.exe' pipeline/summarize_abnormal_image_review.py
& '.\.venv\Scripts\python.exe' pipeline/summarize_runtime_regression.py
~~~

The optional Flutter tool/offline_scan_regression_test.dart compares the isolated historical analyzer with the current implementation using runtime_regression_manifest.json. Pass its absolute path with --dart-define=URITECT_RUNTIME_AUDIT=... while running flutter test from uritect_app. The historical tool library must never be imported from lib/ or used by the app. Default flutter test does not run that opt-in research tool.

## Phone test sequence

Install Uritect_v1.4.0+12_workflow_image_fixes_pilot.apk when the RMX3933 is connected. Preserve existing research history; an update uses the same app ID. The APK is a debug research build.

1. Open capture, lock/unlock the phone, return from the gallery with both selection and cancellation, and background/resume the app. Confirm the live preview returns and only one camera is active.
2. Capture an invalid image. Complete the symptom safety review, return with NEW SCAN and confirm the old photograph is gone. Repeat with a blank gallery image.
3. Capture a full strip without zoom under controlled lighting. For this debug build, recover that exact app-private capture through ADB, copy it into the phone’s Downloads folder, and upload those same bytes for the parity comparison. The captured cache file is not automatically visible in the gallery; use a byte-preserving transfer and verify its SHA256. Record the image SHA256, model and pipeline versions, acceptance/rejection, timing and each output.
4. Separately compare the phone Camera app against in-app capture using appropriately timed matched specimens. Record them as different captures, not as an identical-file test. A reaction changing between photos can invalidate the comparison.
5. Try sideways orientation, two strips, an incomplete strip, blur and glare. Confirm invalid images request a retake and do not produce a normal-result claim.
6. Walk both male and female checklist paths, Yes/No/Unsure safety and quality answers, serious symptoms, renal follow-up, history save and NEW SCAN. Confirm an invalid scan still permits symptom safety guidance and cannot produce a reliable ordinary posterior.
7. Log every initial failure and retake. Do not erase failures when a later image succeeds. Send the capture filenames and observed behavior back for the next investigation.

## Required work that software cannot complete alone

Two qualified medtechs must review source labels using the actual strip IFU, lot and per-pad read timing, with documented adjudication. The current labels and timing have not been independently verified in this task. Re-extract the full development dataset consistently only after technical crop validation; selectively fixing only observed errors can bias evaluation.

Acquire genuinely new independent abnormal and negative specimens, with globally verified participant/specimen identities. Obtain clinical/statistical acceptance and sample-size decisions, seal an untouched final cohort, lock the chosen model/analysis, and evaluate once. The existing inspected datasets and these regression cases remain development evidence. The current kNN has sparse abnormal support and missed abnormalities; this pilot does not close that limitation. Follow [the abnormal detection recovery plan](URITECT_ABNORMAL_DETECTION_RECOVERY_2026-10-05.md).
