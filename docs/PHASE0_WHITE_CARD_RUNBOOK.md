# Phase 0 White-Card AWB Calibration Runbook

## Purpose
Run a quick, reproducible pre-calibration of your AWB pipeline before dipstick-specific data collection.

## What You Need
- Smartphone (single device for baseline)
- 3 light conditions: 2700K, 4000K, 5500K
- Matte white card or plain white bond paper (non-glossy)
- Fixed support/tripod or stable hand position guide
- Measuring guide for fixed distance (recommended 20 cm)

## Ground Rules (Critical)
1. Use one light source at a time (no mixed light).
2. Keep distance and angle fixed for all shots.
3. Avoid shadows and overexposed glare.
4. Keep camera zoom off.
5. Keep the same white card across all captures.

## Step-by-Step Procedure
1. Set up 2700K light only.
2. Place white card on matte neutral background.
3. Position phone at fixed distance (20 cm) and near-perpendicular angle.
4. In the app calibration screen, choose **Phase 0 (White Card)**.
5. Enter:
   - Batch ID (example: `phase0_day1`)
   - Light condition: 2700K
   - Capture delay: 0 to 2 sec (just keep it constant)
   - Distance: 20 cm
6. Capture 30-50 images under 2700K.
7. Repeat Steps 1-6 for 4000K and 5500K.

## Dataset Target
- Minimum: 30 images x 3 lights = 90 images
- Better: 50 images x 3 lights = 150 images

## AWB Review Checks
For each image:
1. Read white reference mean channels `(R_w, G_w, B_w)`.
2. Compute target `T = (R_w + G_w + B_w) / 3`.
3. Compute gains:
   - `gR = T / R_w`
   - `gG = T / G_w`
   - `gB = T / B_w`
4. Apply gains and verify post-correction white closeness:
   - `|R-G|`, `|G-B|`, `|R-B|` should trend lower.

## Acceptance Criteria for Phase 0 Completion
1. Gain values are stable per lighting condition (no wild jumps).
2. Post-correction white error is consistently low.
3. Across all three lights, corrected white appears visually neutral.
4. Capture process is repeatable and operator-friendly.

## What Comes Next (Phase 1)
After Phase 0 is stable:
- Switch to dipstick controls (L1/L2/L3)
- Keep the same camera protocol
- Use strip white plastic as AWB reference region
- Begin thesis calibration dataset collection

## Logging
Use [uritect_app/assets/calibration/phase0_white_card_metadata_template.csv](../uritect_app/assets/calibration/phase0_white_card_metadata_template.csv) to record every capture and AWB output stats.
