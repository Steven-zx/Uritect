# Developer evaluation review

Complete one form for each evaluator and reviewed build. Do not infer review completion from automated checks.

| Review identity | Evaluator entry |
|---|---|
| Reviewer name and role | |
| Organization | |
| Review date | |
| **Repository commit, release tag, or version reviewed** | |
| APK version and SHA-256, if a device build was tested | |
| Device model / Android version, if applicable | |
| Evaluation scope: source review, automated checks, device workflow, usability | |

Find the source commit using `git rev-parse HEAD`. Find a release tag with `git describe --tags --always`. The app version is in `uritect_app/pubspec.yaml`; the frozen APK identity and checksum are in `docs/build`. A branch name alone can change; record a commit, tag or version.

| Recommendation / finding | Steps or source location | Expected | Observed | Severity | Evidence | Retest result |
|---|---|---|---|---|---|---|
| Processing time and progress feedback | | | | | | |
| Lighting / blur rejection and recovery | | | | | | |
| Dashboard organization and readability | | | | | | |
| Consistent Home / Back / New Scan navigation | | | | | | |
| Protected history, patient naming and record persistence | | | | | | |
| Other finding | | | | | | |

Overall software-evaluation conclusion: ____________________

Remaining issues / conditions: ____________________

Reviewer signature or approval reference: ____________________

Keep screenshots and logs de-identified. Software and usability approval do not establish clinical calibration or patient-outcome accuracy.
