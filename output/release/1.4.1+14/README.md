# URITECT 1.4.1+14 signed release candidate

Use only Uritect_v1.4.1+14_release.apk after the release manifest verifier passes.
The exact checksum, signing certificate and toolchain are recorded in
../URITECT_FINAL_RELEASE_MANIFEST.json. Earlier pilot/debug/release APKs are historical.

Theme fonts are bundled with license notices; runtime fetching is disabled.

The candidate contains the startup splash, progressive checklist, camera lifecycle/retake
fixes, geometry-checked localization fallback, local frozen k-NN model, provisional
sex-specific Bayesian UTI estimate, deterministic renal follow-up and offline history.
Bayesian numerical parameters and the frozen classifier are unchanged.

Automated validation: 91 Flutter tests, clean Flutter analysis, 32 Python tests and
7,840 model-export comparisons with no mismatches. Logs/check exit codes are included.

SOURCE_SNAPSHOT.json and URITECT_SOURCE_SNAPSHOT.zip contain the pre-build app source,
assets, tests and build configuration; signing secrets are excluded.
Pin Flutter 3.41.9/Dart 3.11.5 and the Flutter revision in the manifest.
Gradle 8.14.3 is pinned with a distribution checksum; AGP 8.11.1 supports Android API 36.
The release key and local SDK/JDK paths must be supplied separately on another machine.
Rebuild command: flutter build apk --release --no-pub, after restoring locked dependencies.
This is a reproducible configuration, not a promise that rebuild APK bytes are identical.

Do not replace this APK or modify frozen source/docs/checks in place.
A bug fix requires a new version, freeze, checksum and repeat evaluation.

Pending: two physical phone matrices, exact manufacturer/lot/expiry/IFU and ten-pad timing
reconciliation, two MedTech content reviews, physician safety review, statistician review,
planned ten-MedTech ISO/IEC 25010-guided usability study and final editable thesis synchronization.
The user deferred phone connection and strip details on 2026-10-06; ask again next session.

See docs/URITECT_RELEASE_ACCEPTANCE_2026-10-06.md and the pending
output/release/RELEASE_ACCEPTANCE_RECORD.json. Integrity verification and evidence
completeness are separate checks. Neither means clinical calibration or deployment readiness.
Do not infer disease accuracy from historical 82.52% individual-analyte / 17.18% all-ten-pad
development metrics, which have known leakage and selection limitations.

An installed debug pilot may have a different certificate. If install -r fails for signature
mismatch, preserve/export research history and resolve migration with the user before any
uninstall or data clearing.

On this Windows machine the project-local Gradle transform cache failed to finalize an
AndroidX core transform. The failed build log is retained. The same source was retried with
the standard user Gradle cache (set GRADLE_USER_HOME to the user .gradle folder before
Flutter build). No application data, signing key or app source was cleared for recovery.

VS Code workspace Java auto-build/configuration updates are disabled, alongside existing
Gradle import/build-server exclusions, to avoid repeated root-project imports competing
with the Flutter release. Flutter/Dart tooling remains active.
