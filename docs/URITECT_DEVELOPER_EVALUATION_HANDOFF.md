# URITECT developer evaluation handoff

Updated 2026-10-11. **Frozen evaluation build: 1.5.11+28**, Android package `ph.edu.wvsu.uritect`. This is the current research prototype for professional software evaluation. Clinical deployment approval and calibrated disease-probability claims are not established.

## Exact build and evidence

Use [the signed APK](../output/device_pilot/2026-10-11/1.5.11+28/Uritect_v1.5.11+28_release.apk). Its [build receipt](../output/device_pilot/2026-10-11/1.5.11+28/EVALUATION_BUILD.json), [checksum](../output/device_pilot/2026-10-11/1.5.11+28/SHA256SUMS.txt), and [source inventory](../output/device_pilot/2026-10-11/1.5.11+28/SOURCE_SNAPSHOT.json) identify the exact artifact. The accompanying source ZIP excludes signing secrets. APKs and archives are local distribution artifacts, not Git contents.

Earlier APKs and release manifests are historical. Do not describe them as this evaluation build. The current source changes are not represented by the old 1.5.10+27 snapshot.

## Implemented behavior

- Offline camera/gallery image analysis, strip-direction validation, ten-pad localization, and per-analyte experimental k-NN classification with geometry, confidence and distance-support checks.
- Final physical order **LEU, NIT, URO, PRO, pH, BLD, SG, KET, BIL, GLU** from tip to handle. Rotations preserve physical identity. See [the orientation specification](URITECT_FINAL_PAD_ORIENTATION.md).
- Actual submitted-photo sampling overlays: received measured regions appear progressively with labels. The reveal animation is a UI presentation of worker progress, not proof of correct reagent interpretation. See [live preview behavior](URITECT_LIVE_PAD_PREVIEW_2026-10-11.md).
- Numerical readings with explicit low-confidence review notices where supported; invalid geometry/distance remains gated. Bayesian and renal outputs have their own required-pad and safety/eligibility checks. See [numerical-results behavior](URITECT_NUMERICAL_RESULTS_RESTORATION_2026-10-11.md).
- Checklist, safety messages, provisional literature-derived Bayesian UTI output and separate rule-based renal follow-up.
- Retake/home navigation, saved-history naming/editing and local protected history. Inspect the [security/input review](URITECT_SECURITY_AND_INPUT_REVIEW_2026-10-10.md) and native history implementation for the precise guarantees and limits.

## Code entry points

| Area | Files |
|---|---|
| App entry/navigation | `uritect_app/lib/main.dart`, `uritect_app/lib/pages/` |
| Detector, orientation, classification | `uritect_app/lib/services/local_scan_analysis_service.dart` |
| Shared color math | `uritect_app/lib/services/runtime_pad_features.dart`, `pipeline/runtime_pad_features.py` |
| Deployed experimental model/support limits | `uritect_app/assets/production_semiquant_model.json`, `training_support_policy.json` |
| Reliability and required-pad gating | `uritect_app/lib/models/scan_model.dart`, `screening_fusion.dart`, `renal_followup.dart` |
| Persistence/security | `uritect_app/lib/services/scan_history_service.dart`, `uritect_app/android/app/src/main/` |
| Analysis overlay | `uritect_app/lib/pages/analyzing_page.dart`, `uritect_app/lib/widgets/strip_analysis_animation.dart` |
| Tests | `uritect_app/test/`, `pipeline/test_*.py` |

## Reproduce engineering checks

The observed build environment uses Flutter **3.41.9**, Dart **3.11.5**, Gradle **8.14.3** (wrapper checksum pinned), Android SDK build-tools **36.0.0**, and Android Studio's bundled JDK. The SDK constraint in `pubspec.yaml` is a minimum compatibility range, not the exact build environment. Dependencies are locked in `pubspec.lock`.

From `uritect_app`, run `flutter pub get`, `flutter analyze`, then `flutter test`. Local debug builds use `flutter build apk --debug`. Signed release builds require the owner-managed signing key and ignored `android/key.properties`; those must not enter the developer repository. On the current Windows laptop, build with Android Studio's JDK and the existing user Gradle cache (`GRADLE_USER_HOME` set to the user's `.gradle` directory).

From the repository root, Python checks use `.venv\Scripts\python.exe -m unittest discover -s pipeline -p 'test_*.py'`. Research dataset inputs are local and excluded from Git; dataset-dependent reproductions require separately authorized access to those inputs. Preserve reference labels and source hashes.

**Observed checks:** 50 Python tests and 143 Flutter tests passed; Flutter static analysis reported no issues. The APK receipt separately verifies source-snapshot consistency, package/version, release signing, embedded model/support-policy equality and absence of Internet permission. Automated checks do not establish real-device usability or clinical performance.

## Performance evidence and non-deployed experiments

The app retains `direction_verified_experimental_v1_20261011`, SHA-256 `1380D9E04D044413B42BD045E3C7370BF3D06A720695D2654598657234742279`. Its clinical validation flag remains false.

[The grouped improvement report](../pipeline/output/knn_improvement_2026-10-11/REPORT.md) reports a retrospectively refitted baseline at **80.18% individual-analyte accuracy and 12.50% all-ten accuracy** on 112 previously inspected confirmation events. This is exploratory and is not an independent end-to-end validation of the frozen phone APK. The earlier corrected 79.92%/13.56% figures came from a different split and should not be compared as a direct gain/loss. Historical 82.52%/17.18% figures precede the orientation/grouping corrections.

[The focused pH/SG audit](URITECT_PH_SG_ERROR_AUDIT_2026-10-11.md) reviewed development crops, documented pH majority bias and SG class overlap, fixed an experimental boundary-refinement error, and compared 216 configurations per target using nested grouped development folds. Neither target passed promotion. The experimental recipes, balanced votes and comparison models are **not** the deployed classifier. All five metrics, category supports and confusion counts accompany the reports; category accuracy is not disease-detection accuracy.

Python/Dart parity covers identical decoded pixel/ROI/gain feature calculations. No new classifier was exported, so full new-classifier prediction parity is not asserted. Any future export requires matching feature recipes, regenerated model-bound support limits and prediction parity before installation.

## Evaluation still requiring actual observations

Test the exact 1.5.11+28 APK and record device model/Android version/date, expected and observed behavior, screenshot, latency and pass/fail:

1. Offline scanning; camera/gallery permission denial and recovery.
2. Valid strip under cool/warm/daylight lighting; blank, blurry, dark, overexposed, partial, wrong-strip and multiple-strip inputs.
3. Tip/handle orientation and physical identity of every overlay; low-confidence notices, rejection and retake.
4. Checklist exclusions, safety messages, required-pad Bayesian gates and renal follow-up.
5. Home/new-scan navigation, background/resume, camera/grid behavior and progressive photo overlays.
6. History naming/editing, lock/unlock, encrypted save/load, migration, interrupted-write recovery and deletion; verify records survive an in-place update.

Two-phone acceptance and this build's phone installation are pending. The owner deferred strip manufacturer/catalogue, lot, expiry and manufacturer reading times; complete [the physical-strip protocol](URITECT_PHYSICAL_STRIP_PROTOCOL.md) when these details are available. Record actual MedTech/physician/statistician review and usability results in [the expert review packet](URITECT_STATISTICAL_AND_EXPERT_REVIEW_PACKET.md). Owner-reported orientation verification is not a substitute for inventing other sign-offs.

Use [the device checklist CSV](URITECT_EVALUATION_DEVICE_CHECKLIST.csv), duplicated per phone, to record actual observations. Every row starts as `NOT_RUN`; no device passes are inferred from automated tests. The [recorded Python environment](../pipeline/output/ph_sg_error_audit_2026-10-11/PYTHON_ENVIRONMENT.json) lists the installed package versions used for the current audit.

Bayesian values remain provisional literature-derived estimates. Expert content approval does not statistically calibrate them. Female evidence multiplication, male prior/LR transportability, rare/absent reagent classes and lack of local culture-confirmed outcome validation remain disclosed. New specimen collection was deferred by the owner; no augmentation is presented as a substitute.

## Clean repository handoff boundary

The next task is a separate clean evaluation repository containing app source/tests/assets, locked build configuration, selected pipeline source, this handoff, current evidence and a clear dataset-access note. Exclude raw photos/specimen records, encrypted history, signing keys/passwords, local SDK paths, caches/build directories, virtual environments, obsolete pilot binaries and large historical research artifacts. Distribute the frozen APK separately with its checksum. Preserve the current repository and history; do not rewrite or force-push it as part of cleanup.

This document is the current starting point. Older handoff and acceptance documents remain historical evidence, not current acceptance claims.
