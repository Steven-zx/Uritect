# Android Compatibility Strategy (Uritect Calibration)

## Goal
Maximize real-world camera compatibility across Android devices for AWB calibration and capture workflows.

## Current Hardening Implemented
1. Compatibility initialization fallback through multiple camera presets:
   - veryHigh -> high -> medium -> low
2. Safer camera defaults after initialization:
   - FocusMode.auto
   - ExposureMode.auto
   - FlashMode.off
3. Capture recovery:
   - If capture fails, app retries after auto-downgrading to a lower preset.
4. Session diagnostics shown in UI:
   - Active camera name
   - Active preset
   - Initialization failure trace

## Important Reality
No mobile app can guarantee 100% support on every Android model due to vendor HAL differences, sensor behavior, and OEM camera firmware quirks.

## Coverage Plan for Thesis Deployment
1. Set practical support baseline (Android 7+ recommended).
2. Validate on a device matrix covering at least:
   - Samsung, Xiaomi/Redmi, Oppo/Realme, Vivo, Huawei, Motorola, Infinix/Tecno
3. For each device, test:
   - Camera initialization
   - 30 sequential captures
   - Export session CSV/ZIP
4. Track failures by category:
   - Init fail
   - Capture fail
   - Wrong orientation
   - Inconsistent exposure

## Success Criteria
- >=95% successful camera init across test matrix
- >=98% successful capture events once initialized
- No data loss in CSV/image logging and export

## Next Improvements (Planned)
1. Optional manual exposure compensation controls.
2. Fixed frame guidance overlay to reduce perspective variation.
3. Device-profile presets for known problematic models.
