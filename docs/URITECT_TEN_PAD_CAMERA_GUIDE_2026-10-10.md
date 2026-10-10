# Optional ten-pad camera alignment guide ? 2026-10-10

Candidate: URITECT 1.5.3+19, superseding 1.5.2+18 for this UI change.

## Behavior

Tap the grid icon at the top right of Capture Dipstick to show or hide ten outlined pad slots. The guide starts hidden. Align the pad end at the top and the handle below. Labels follow the existing classifier order: LEU, NIT, URO, PRO, pH, BLD, SG, KET, BIL, GLU.

The overlay is placed inside the actual camera image bounds, not the surrounding gray letterbox. Outlines have white and dark teal edges, with readable compact labels. It adapts to preview size and orientation. Tap-to-focus continues through the guide. Capture controls and the continuous outer blue border remain intact.

This is a Flutter preview overlay only; it is never rendered into captured files, gallery images, saved photos, or classifier inputs. It is hidden in photo review, the toggle is disabled there and while busy, and retaking restores the user's current guide preference. No manual crop, pad labeling, measurement, or detection override is introduced.

## Scope and limitations

No classifier, model assets, confidence/reliability gates, Bayesian values, encrypted storage, or patient-name behavior changes. The guide reflects the app's existing supported ten-pad order; it does not establish compatibility with a different strip, correct reaction timing, or increased measured accuracy. Physical-strip IFU verification remains outstanding as previously documented.

## Validation

Camera widget tests cover guide toggle without camera restart, pad/focus coordinate mapping in portrait and landscape, bounds of all ten outlines, hiding during captured-photo review, disabled toggle in review, and restoration on retake. Full Flutter tests, static analysis, release build, source snapshot, and APK signature/asset checks are recorded under output/device_pilot/2026-10-10/1.5.3+19. Previous image-regression evidence is explicitly reused because analysis code and assets are unchanged; this is not a new accuracy evaluation.

Physical-phone visual acceptance of the guide still requires a live alignment walkthrough. For that check, toggle the grid, align all ten pads, tap one pad to focus, take a photo, verify the review image contains no grid, and retake to confirm the guide returns. Existing saved records should remain available after the update.
