# AWB Calibration Protocol (Phase 1 Foundation)

## Objective
Create a reproducible calibration dataset and AWB tuning workflow that keeps urinalysis strip colors stable across 2700K, 4000K, and 5500K lighting.

## Required Setup
- 3 bulbs / light sources: 2700K, 4000K, 5500K
- 1 fixed phone device for baseline calibration run
- Same urinalysis strip brand and lot where possible
- Synthetic control solutions: Level 1 (negative), Level 2 (low abnormal), Level 3 (high abnormal)
- Plain matte background (neutral gray preferred)
- Fixed strip holder and fixed camera distance (recommend 18–22 cm)

## Capture Standard (Must Not Change During a Session)
1. Lock strip orientation (pads always top-to-bottom in same order).
2. Fix distance and angle (near-perpendicular, avoid perspective tilt).
3. Disable digital zoom.
4. Use fixed capture delay after dipping (example: 60 s, based on strip manufacturer timing).
5. Avoid mixed lighting and shadows.

## Session Design
For each light condition (2700K / 4000K / 5500K):
1. Capture all 3 control levels.
2. Capture at least 20 images per control level.
3. Total minimum baseline images: 3 lights x 3 levels x 20 = 180 images.

Suggested naming:
`<device>_<kelvin>_<controlLevel>_<index>.jpg`
Example:
`redmiNote12_2700K_L2_014.jpg`

## Metadata to Record per Image
- `deviceId`
- `cameraMode` (auto/pro/manual details)
- `lightKelvin` (2700/4000/5500)
- `controlLevel` (L1/L2/L3)
- `captureDelaySec`
- `distanceCm`
- `timestamp`
- `operatorId`

## AWB Tuning Workflow
1. For each image, identify the unreacted white strip plastic reference region.
2. Compute average white-region RGB: `(R_w, G_w, B_w)`.
3. Compute target gray value: `T = (R_w + G_w + B_w) / 3`.
4. Compute gains:
   - `gR = T / R_w`
   - `gG = T / G_w`
   - `gB = T / B_w`
5. Apply gains to all pixels with clipping to `[0, 255]`.
6. Log `gR, gG, gB` and residual white error after correction.

## Quality Checks
- White reference post-correction should satisfy channel closeness:
  - `|R-G| <= 5`, `|G-B| <= 5`, `|R-B| <= 5` (starting target)
- Under same control level, cross-light HSV variation should decrease after AWB.
- Reject frames with severe blur, glare saturation, or strip partially out of frame.

## Deliverables for This Phase
1. Calibrated image dataset with metadata CSV/JSON.
2. AWB gain logs and before-vs-after color variance report.
3. Initial thesis plots:
   - Per-light gain distributions
   - Pre/post AWB HSV variance boxplots

## Immediate Next Step in App
Implement a calibration capture flow first (no diagnosis yet):
- Select light condition
- Enter control level
- Capture frame
- Save frame + metadata
- Run AWB preview and persist gains

Once stable, proceed to pad ROI segmentation on corrected images.
