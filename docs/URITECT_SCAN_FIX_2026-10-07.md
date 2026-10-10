# RMX3933 scan rejection investigation — October 7, 2026

## Reproduction and cause

The user reported that both direct capture and Camera-app/gallery upload produced
`Detected: 0/10 pads` with release 1.4.1+14. Two specifically identified phone photos
were copied locally over ADB; no unrelated gallery photos were inspected.

- `IMG_20261007_092336.jpg`: patterned floor, a dark object, and weak separation of
  pale endpoint pads. Legacy localization reports multiple strip-like candidates;
  the edge-background detector also fails. Local contrast finds a candidate, but
  ten individual pads remain unconfirmed. The updated scanner still rejects this
  image and requests a retake.
- `IMG_20261007_093746.jpg`: flat strip on white paper. The previous saturation-based
  segmentation misses pale pads. Comparing measured row colors against nearby
  bright plastic locates all ten pads. The current classifier accepts this photo
  with every analyte above its unchanged 0.45 confidence threshold.

The old analysis page assigned zero detected pads to **every** rejected scan,
including low-confidence failures after ten pads had already been located. The
displayed count was not a reliable diagnosis of the failing stage.

## Implementation: 1.4.2+15

- Preserve legacy and background-relative extraction when their full geometry
  checks pass. Add a local contrast fallback for textured backgrounds, and a
  separate nearby-backing color-ratio fallback for pale reagent pads.
- Require ten measured regions; do not extrapolate or manufacture missing pads.
  Existing spacing, ROI alignment, image quality and classifier abstention checks
  remain. The backing fallback checks the visible handle to establish direction.
- Reject competing narrow bright-strip candidates before another detector can
  silently select one. Missing pads, cropped endpoint pads and multiple strips
  have explicit regression coverage.
- Keep unknown localization counts unknown. Low-confidence classification
  reports `Located: 10/10 pads; results unavailable`. Other rejections show the
  specific retake reason and scan-check code. Invalid scans remain ineligible for
  analyte-based interpretation; the safety checklist remains available.
- Model vectors, classifier parameters, 0.45 threshold, Bayesian values and renal
  rules are unchanged. Pipeline ID is
  `android_markerless_json_knn_v3_local_contrast_20261007`.

## Verification and release status

101 Flutter tests pass, including the actual white-paper capture, rotated
captures, missing/cropped pads, multiple strips, and rejection reporting.
Static analysis is clean. Across the previous 18-image development regression,
all six previously accepted images remain accepted with identical predictions.
This is regression evidence, not independent clinical validation or proof of
correct semiquantitative labels for the new photo.

Evidence and the separately versioned signed APK are in
`output/device_pilot/2026-10-07/1.4.2+15/`. Source is archived before building.
`PILOT_BUILD.json` records the APK hash, signing identity and build status;
`INSTALLATION.json` records actual device installation and launch when complete.

The previous 1.4.1+14 APK, source archive and release manifest are preserved.
The working tree has intentionally moved beyond that source freeze, so the old
manifest's current-source comparison will now detect drift. Do not edit the old
manifest to hide that change. Use the new version/hash for this pilot; acceptance
evidence and a new final release manifest must be synchronized before a later
thesis freeze. Two-device testing, strip/IFU confirmation and expert evaluations
remain pending. Three MedTech reviewers can document expert content review;
that does not establish culture-confirmed statistical calibration.
