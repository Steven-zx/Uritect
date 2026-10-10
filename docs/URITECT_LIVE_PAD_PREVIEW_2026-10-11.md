# Per-pad overlay preview — 1.5.10+27

The loading screen now presents each measured sampling square and analyte label over the submitted photo, with a short fade/scale pop. Earlier squares stay visible. The final tip-to-handle order remains LEU, NIT, URO, PRO, pH, BLD, SG, KET, BIL, GLU.

The detector first selects and direction-checks the strip geometry. The worker then publishes cumulative per-pad events as each analyte is sampled for classification, instead of delivering all ten boxes in one event. The selected, correctly oriented preview is transferred once; subsequent events reuse that exact photo and coordinate system. A classification rejection preserves all measured geometry without inventing readings.

Detection can finish faster than someone can see ten separate updates. The screen therefore presents already-received regions at 180 ms intervals (up to roughly 1.8 seconds for ten), and waits for that presentation before opening results. This is a presentation stagger, not a fabricated detection timer or a claim of live-camera inference. No box can appear before its measured region arrives. Reduced-motion mode displays received regions immediately; animations pause when the app is inactive.

The classifier, features, support policy, confidence gates, Bayesian calculations, physical orientation and stored history are unchanged. No model from the improvement experiment is deployed by this UI change.

Validation: all 141 app tests passed; static analysis reported no issues. Coverage includes progressive real-image counts 1–10, shared preview identity, four physical-strip rotations, classification rejection, fast analysis completion, reduced motion, lifecycle cleanup, actual-photo coordinate mapping and the existing navigation/clinical/history regressions. Device walkthrough remains to be done on the newly built APK.

Release evidence and the source archive are kept in `output/device_pilot/2026-10-11/1.5.10+27/`. Previous APKs and evidence are preserved. The new APK is prepared for installation; this task does not automatically replace the phone's installed build.

[Download APK](../output/device_pilot/2026-10-11/1.5.10+27/Uritect_v1.5.10+27_release.apk). SHA-256: `BF2B53328B9EFBE929D32C90B008A992B6BEB377FE17484FADD575DA6F93FAEF`.

The APK identity, expected release signer, offline permissions, archived source and unchanged classifier/support-policy bytes were verified. See `PILOT_BUILD.json`, `APK_IDENTITY.txt` and `APK_PERMISSIONS.txt` in that evidence folder.

The first build hit a Windows Gradle transform-cache workspace-move error under the project-local Gradle home. The successful retry used the existing user cache by setting `GRADLE_USER_HOME` to `Join-Path $env:USERPROFILE '.gradle'`; source and dependencies were unchanged.
