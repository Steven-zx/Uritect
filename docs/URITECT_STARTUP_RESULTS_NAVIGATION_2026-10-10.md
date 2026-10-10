# Single startup and clearer results ? 2026-10-10

Release candidate: **1.5.4+20**. This supersedes the startup UI in the 2026-10-04 implementation note and retains the optional camera guide and editable encrypted patient names from earlier builds.

## Changes

- **One opening screen:** Android renders the native URITECT logo on a pale background matching the app. The first Flutter frame is the dashboard. The second gradient/loading screen, its artificial 2.2-second timer, and its unused widget/test/visual fixture were removed. Older Android versions use a centered logo; Android 12+ uses the system launch icon. Actual operating-system launch timing varies by device.
- **Home from dipstick results:** Both the header icon and the bottom Home button end the flow and open the dashboard. Checklist and New Scan remain available. Readings without a completed checklist are not automatically saved; the results page states this.
- **Black-screen navigation fix:** The analysis page used to pop after its awaited results route completed even when the entire scan stack had already been removed. A removed route can remain mounted during its exit animation. Results now return to a real dashboard with the old routes removed, and the analysis callback pops only if its own route is still current. New Scan still returns the typed retake reason to capture.
- **Clearer dipstick readings:** Two columns, complete wrapping values, neutral readable colors, Negative instead of Neg, and expandable reference ranges. Controls remain visible at the bottom instead of being buried below the readings.
- **Clearer screening summary:** What to do next appears first. All high, moderate and caution safety findings stay visible. Kidney-specific guidance is labeled separately. The provisional UTI estimate remains visible, while evidence factors, priors, formula, model identifier and full assumptions are under How this estimate was calculated. Measurements, detailed checklist reasoning, provenance details and checklist answers are grouped separately. Research/non-diagnostic/no-local-calibration wording remains visible before opening details.
- **Saved reviews:** The recorded estimate remains unchanged. Patient-name editing is retained. A saved review does not display an Edit Checklist control that merely navigates backward; editing the original stored checklist is not implemented. Home is still available.
- **Typography:** Remaining text styles inherit the bundled Inter family. Dividers and table layout were softened to reduce visual clutter.

No model parameters, image-analysis code, support thresholds, clinical rules, priors/LRs, encryption keys or history storage formats changed. UI improvements do not establish improved analyte accuracy or clinical validation.

## Verification

Tests exercise both Home buttons through a real analysis -> results -> checklist navigation stack, preserve the New Scan return reason, confirm warnings are visible with details closed, confirm recorded posterior display and encrypted patient-name editing, verify non-truncated values on small screens with enlarged text, and confirm the first Flutter frame is the dashboard with no subsequent launch timer.

Rendered phone references use bundled fonts and were inspected: `uritect_app/test/goldens/bayesian_results_phone.png` and `uritect_app/test/goldens/dipstick_readings_phone.png`. These contain synthetic test values, not measured clinical findings.

Full test/static-analysis/build logs, frozen source archive, APK checksum/signature/asset checks and installation status are recorded under `output/device_pilot/2026-10-10/1.5.4+20`. Previous development image-regression evidence is reused explicitly because classifier and model assets are unchanged; no new accuracy evaluation is claimed.

Physical-phone cold-launch appearance, result readability and the full Home/retake walkthrough still need user acceptance. Do not clear app data or uninstall to update: use the same-signed release APK as an in-place update.

## Separate developer evaluation repository

A separate repository is feasible. Keep the current working repository as the archive, and export a reviewed source snapshot with build instructions, tests, model documentation, expert-review materials and synthetic examples. Exclude caches/build trees, signing credentials/private keys, device exports, private participant or patient data, and redundant historical APKs. Document any dataset access requirements rather than distributing protected records. Creating/publishing that separate repository is a distinct follow-up; this change does not claim it has already been created.
