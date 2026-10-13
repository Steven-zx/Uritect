# URITECT developer evaluation release — 1.5.17+35

Prepared for professional software evaluation. This is a frozen offline Android
research prototype, not a clinically validated diagnostic product.

## Repository and build reviewed

- Clean checkout: `developer_evaluation/URITECT`.
- App version: **1.5.17+35**, Android package `ph.edu.wvsu.uritect`.
- Local commit: **`7c8361a17001ead113751d25a3f13749408d4a37`**.
- Commit title: **Keep scans prompt-free and restore visible predictions**.
- Signed APK SHA-256: `41B3EDC2745F7447BD55A2A5A5DF9D85978C914D2FFC3CB8481547E279494341`.
- No new GitHub push was performed as part of the ongoing legacy-dataset audit.
  This brief identifies the verified local checkout; it does not claim a new
  remote publication or release tag.

## Substantial release scope

The cleaned package contains the Flutter application, locked dependencies,
offline model/font assets, regression tests, selected pipeline utilities,
architecture/evaluation documentation, review forms and frozen build evidence.
Raw datasets, patient history, signing credentials, SDK paths, caches and
generated application binaries are excluded. The signed APK is supplied
separately and checked against its recorded checksum.

The app supports camera and gallery capture, image-quality checks,
orientation-aware ten-pad localization, actual-photo ROI overlays, experimental
per-analyte k-NN classification, numerical readings with secondary reliability
labels, a safety checklist, provisional literature-derived Bayesian screening
calculations, rule-based renal follow-up and encrypted editable scan history.
The recorded tip-to-handle order is LEU, NIT, URO, PRO, pH, BLD, SG, KET, BIL, GLU.

The interface uses a consistent teal theme and local typography, a simplified
patient workflow, processing feedback and optional research details. Timing,
eligibility, confidence and serious-symptom gates remain part of the workflow.

## Latest commit details

The latest commit changes current-scan saving to a write-only encrypted pending
inbox, avoiding authentication prompts during scanning. Explicit history access
authenticates before merging and reading verified records. Checklist editing
restores existing answers and updates the same scan ID. Actual available
predictions are visible with Low confidence, Provisional or Unverified labels,
and teal responsive actions and a reference-only category legend are included.
This commit does not retrain the classifier or relax clinical gates.

The local commit records 36 changed files, 2,410 insertions and 1,204 deletions;
these totals include formatting and frozen evidence updates, not only new
functionality. Earlier clean-repository commits include `65828c6` (simplified
patient workflow and optional research information) and `5b048d6` (scan quality,
processing feedback and professional evaluation UI).

## Verification and evaluation limits

The owner checkout recorded **176 passing Flutter tests** and **clean static
analysis**. Source inventories and build receipts bind the packaged source and
signed APK. These checks are not a substitute for independent developer review
or full acceptance testing on Android devices. Installation on the RMX3933 has
been recorded separately; complete current-version device acceptance remains
pending.

Bayesian estimates remain provisional and are not clinically calibrated
probabilities. Existing classification figures are exploratory and must not be
presented as disease-detection accuracy. Actual color swatches, manufacturer/IFU
verification, documented professional review and independent clinical outcome
validation remain separate evidence requirements.

The current legacy-dataset cleaning and model comparison are **not part of this
frozen release**. Any future accepted model change needs its own recorded
version, numerical parity checks, tests and build evidence before evaluation.

Evaluators should record the repository commit, release tag or version reviewed,
APK checksum, device/Android version, test steps, expected and actual behavior,
and deidentified evidence. Start with the clean repository's
`docs/EVALUATION_GUIDE.md` and `docs/DEVELOPER_EVALUATION_REVIEW_FORM.md`.
