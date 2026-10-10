# Actual-photo sampling-region animation - 1.5.6+23

This pilot candidate replaces the illustrative strip with the submitted photo. A subtle search sweep is an animation, not a measured boundary or progress percentage. Once the detector confirms geometry, the UI outlines its actual inner color-sampling regions and moves a highlight through them. The ten labels use the existing analyte order.

The background worker emits a prepared preview and then the selected localization before classification. Previews use the exact EXIF-baked, resized (longest side 1100 pixels), detector-oriented image. The photo and overlays share centered BoxFit.contain coordinates. Outlines wait until the matching preview frame is decoded; image updates never retain old orientation underneath new coordinates. No guessed pad boxes are displayed. Preview JPEG encoding is for display only and never feeds the classifier.

Localization does not guarantee a valid reading. Existing image-quality, support-distance, confidence and clinical eligibility gates remain. A scan rejected after localization can show the actual regions while still withholding all analyte readings. Geometry failures do not produce invented regions. No artificial minimum delay is imposed; an expandable "View sampled pad regions" replay on the immediate results page allows inspection after fast analysis.

Preview bytes and coordinates stay in memory. They are not added to saved history, exported patient files or additional plaintext photo files. The existing encrypted history and authentication behavior remains.

Reduced-motion/accessibility settings show static regions. Animation pauses when the app goes to the background. Scrolling supports small screens and larger text. Retake and Home navigation guards remain intact.

Verification:
- Widget tests cover containment, no timer-generated geometry, rejection after localization, reduced motion, lifecycle and a rendered phone reference.
- Eighteen retrospective development images retain exactly the prior acceptance/rejection behavior, accepted predictions, confidence values and distances. Actual preview callbacks are enabled during this regression.
- A known development image is tested in four rotations plus EXIF orientation 6, with resizing. All locate ten regions. Preview dimensions, sampled pixels and region bounds match the selected detector orientation.
- Full Flutter tests, static analysis, signed release identity/assets/security and exact installed APK checks are recorded in output/device_pilot/2026-10-11/1.5.6+23.

These engineering checks are not a new accuracy study or clinical validation. Physical-phone visual acceptance of the new overlay remains a pilot check. Historical release artifacts and model/Bayesian values are unchanged.
