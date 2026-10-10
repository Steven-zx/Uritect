# URITECT release acceptance and QA response — 2026-10-06

Version under evaluation: **1.4.1+14**, application ID `ph.edu.wvsu.uritect`.
This is a signed thesis release candidate. It is not accepted for clinical deployment.
The APK and source freeze are authoritative only after the manifest verifier passes.
Device and human evidence have separate completion gates.

## QA decisions

| Recommendation | Action/status |
| --- | --- |
| Offline startup fonts | Bundled six checksum-pinned Inter/Poppins variants and license notices; runtime font fetching disabled. Cold-start asset-loading regression added. |
| One reproducible signed release | Gradle 8.14.3 with distribution SHA-256, AGP 8.11.1, locked dependencies, source archive and per-file hashes; one universal release APK. Build/test results live beside that APK. |
| Splash implementation | Already present since pilot 10: AppSplashPage is the home in main.dart; included in this candidate. QA's proposal-only statement is stale. |
| Windows build/IDE contention | Preserve failed transform-cache log; retry with standard user Gradle cache; disable workspace Gradle auto-detection/nested discovery and Java auto-build/configuration updates alongside existing Gradle import exclusions. Flutter/Dart remains active. |
| Two-phone testing | Required and pending. User will reconnect later. Do not use pilot/debug results to mark this APK passed. |
| Physical strip/IFU | Protocol prepared; manufacturer, lot, expiry and all ten reading times await the user and two MedTechs. Ask again before physical testing. |
| Bayesian status | Preserve literature-derived parameters and strict gates; explicitly disclose female multiplication and male conditioning/transportability assumptions on screen. No risk bands or local calibration claim. |
| Statistician review | Exact tables, branches and unresolved questions in the review packet; review pending. No replacement values invented. |
| Human evaluation | Two MedTech content reviews, physician safety review and planned ten-MedTech ISO/IEC 25010-guided evaluation remain pending. |
| Manuscript | Correct historical claims in the revision guide now; final Chapters 1–5 and exported PDF wait for frozen evaluation. Editable manuscript is absent. |

Expert review evaluates content and implementation. Prediction-model validation evaluates performance, including calibration/discrimination, against patient outcomes. See [PROBAST+AI](https://www.bmj.com/content/388/bmj-2024-082505).
Build compatibility: [AGP 8.11 supports API 36 and requires Gradle >=8.13](https://developer.android.com/build/releases/agp-8-11-0-release-notes).

## Freeze and identity

Candidate folder: `output/release/1.4.1+14/`.
The APK is `Uritect_v1.4.1+14_release.apk`; its SHA-256 is in the regenerated
`output/release/URITECT_FINAL_RELEASE_MANIFEST.json`, rather than copied from an older APK.
The signing certificate is verified by apksigner; debug APKs are rejected by the seal tool.
The source ZIP excludes signing secrets and local SDK paths; those must be configured on another machine.
Pin Flutter 3.41.9 / Dart 3.11.5, the recorded Flutter revision, JDK recorded by the manifest,
Gradle 8.14.3, AGP 8.11.1, Kotlin 2.1.0 and the frozen pubspec.lock.
On this Windows host, set `GRADLE_USER_HOME` to the standard user `.gradle` directory
before Flutter build; the project-local transform cache failed during the first attempt.
`IDE_SETTINGS.json` in the release folder records the workspace import/auto-build settings.
This supports a reproducible configuration, not guaranteed identical APK bytes on a rebuild.

Run these from the repository root with the repo Python environment:

```powershell
.\.venv\Scripts\python.exe pipeline/verify_final_release_manifest.py
.\.venv\Scripts\python.exe pipeline/verify_release_acceptance.py
```

The first verifies integrity. The second must fail while tests or sign-offs are pending.
Do not edit the sealed source, APK, checks or included documents in place. Any software fix gets
a new version and source snapshot, with a newly verified APK and repeat device evaluation.

## Device protocol

Use two different physical Android phone models. Record device ID, model, Android version,
date in Asia/Manila, tester, exact APK hash, input-file hashes, expected/actual behavior,
screenshot/log artifacts with hashes, pass/fail and issue ID.
The case inventory is generated in `output/release/RELEASE_ACCEPTANCE_RECORD.json`;
all cases must run on each phone. Pending means not run, not pass.

Install the sealed release with `adb -s <device> install -r <apk>` and verify installed
versionName 1.4.1/versionCode 14. A debug pilot may have a different signing certificate.
If Android rejects an update, preserve/export research history first and resolve the signature
mismatch with the user; do not automatically uninstall or clear app data.

1. Confirm splash, small screen/large text, reduced motion and dashboard transition.
2. Disable mobile data and Wi-Fi (airplane mode alone can leave Wi-Fi enabled).
   Use USB ADB for evidence if needed; wireless debugging disconnects with Wi-Fi off.
   Run camera and locally stored gallery images offline.
3. Deny/recover camera permission through Android settings; cancel/deny/reopen the picker.
   Modern Android photo picker may not expose a broad gallery-permission prompt; record that
   specific subcase as not applicable with OS/UI evidence, and still test cancel and recovery.
4. Use independent labeled strips/photos under cool, warm and daylight conditions.
   Log reaction time, strip lot, image hash and MedTech labels. Review overlay geometry and
   exact categories; record accepted/retaken separately. An accepted but incorrect result
   is a classification failure, never an accuracy pass because the app did not crash.
   A retake of a valid challenge is an abstention, not a successful valid scan. Report its
   frequency and have reviewers prespecify acceptable operational performance before testing;
   safe rejection alone does not establish scanner usability or diagnostic reliability.
5. Test blank, unreadably blurry/dark/clipped, partial, wrong-strip and multiple-strip images.
   Wrong-product recognition is not guaranteed by shape/color: an unsupported-strip answer
   must block interpretation. Similar-looking strips may evade automatic detection; disclose it.
6. Exercise confidence <0.45, retakes, repeat taps, background/resume and camera/gallery return.
   Confirm old photos/results never reappear and safety guidance survives failed scans.
7. Exercise each UTI exclusion, unknown answer, female and male pathways and systemic warnings.
   Use synthetic or reviewed scenario inputs for rule testing; distinguish these from actual
   image-driven predictions. Do not claim disease sensitivity from software scenario tests.
8. Exercise all five renal actions and triggered-rule IDs, including safety precedence.
9. Save/restart/review offline history, confirm original posterior and versions, and delete
   only designated test records. Record storage behavior and retained unrelated records.
10. Measure at least five scans per phone, state input dimensions and start/end events,
    report median/p95, retake rate, all crashes/hangs and operational observations.
    No undocumented performance cutoff or clinical acceptance threshold is invented.

For exact-byte camera/gallery parity, the automated service regression test uses copies of
a de-identified local file and verifies identical predictions. It accompanies the frozen source.
The release app is not debuggable, so debug `run-as` extraction of its private camera cache
does not work. Physical device testing compares acquisition under controlled strip, light,
angle and IFU timing, recording image hashes and reference labels. A separate native
Camera-app photograph tests acquisition differences; it must not be described as the same file.
No debug pilot result substitutes for executing the final release workflows on each phone.

## Before calling the thesis app final

Verify artifact integrity, complete both phone matrices with no unresolved unsafe acceptance,
confirm the exact IFU/category/timing mapping, obtain content/safety/statistical review evidence,
and complete/analyze the planned usability evaluation. Attach signed review decisions, including
unresolved assumptions and limitations. Then run `pipeline/verify_release_acceptance.py --seal-evidence` to seal a separate
evaluation evidence manifest (it refuses pending records), and synchronize
the editable manuscript. A completed thesis prototype still has no local culture-confirmed
calibration and is not ready for unsupervised clinical deployment.

## Later clinical-validation study

Predefine the target population, recruitment, culture reference standard, sample size and
independent specimens; separate development from untouched patient-level validation.
Review the 408 historical abnormal-error rows and 14 cached-feature review events before any
model retraining. Collect independent abnormal specimens, resolve labels/timing with MedTechs,
and evaluate exact categories, clinical-threshold sensitivity/specificity, confidence intervals,
retake/coverage rates and accepted-scan performance. Evaluate UTI calibration, discrimination
and clinical utility with culture-confirmed outcomes; do not infer them from strip accuracy.

The 82.52% individual-analyte and 17.18% whole-ten-pad historical results are retrospective,
not independent confirmation of this changed image pipeline. The audited original grouping
leaked related captures; parameter selection also inspected those results. See the October 5
abnormal-detection recovery audit. Preserve those limitations until a new evaluation is complete.

The first unsealed candidate (1.4.1+13) was cancelled before producing a final APK when
the unbundled runtime-font dependency was identified. Its cancelled build log/source snapshot
remain forensic history; only 1.4.1+14 is the candidate for acceptance. Font handling follows
[the package bundling guidance](https://pub.dev/packages/google_fonts).
