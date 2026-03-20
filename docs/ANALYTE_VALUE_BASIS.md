# 10-Parameter Value Basis (Defense Notes)

## Why this file exists
This document explains the source and basis of the 10 urinalysis parameter values shown in the app.

## Current profile in app
- **Profile version**: `baseline_v1`
- **Code source**: `uritect_app/lib/src/analysis/analyte_value_basis.dart`
- **Display use**: Debug Verification Dashboard and History detail cards

## Basis hierarchy used
1. **Thesis priors and requirements** in `THESIS_PROJECT_BRIEF.md` (for example: protein and glucose risk anchors at 1+ thresholds).
2. **Standard semiquant urinalysis strip conventions** used as baseline bins for level-to-value mapping.
3. **Project calibration data** (AWB-corrected colors + labeled levels) used for nearest-level matching.

## Important scope note
- `baseline_v1` is a **defense/development baseline profile**, not a final clinical calibration card.
- Before clinical validation, map values must be aligned to the **exact strip manufacturer IFU and strip lot card** used in deployment.

## Baseline level-to-value table

| Parameter | Unit | Baseline mapping (level -> value) |
|---|---|---|
| Leukocytes | Leu/µL | Negative->0, Trace->~15, 1+->~70, 2+->~125, 3+->~500 |
| Nitrite | qualitative | Negative->Negative, Trace->Equivocal, 1+/Positive->Positive |
| Urobilinogen | mg/dL | Negative->0.2, Trace->0.2-1.0, 1+->1, 2+->2, 3+->4, 4+->8 |
| Protein | mg/dL | Negative-><15, Trace->~15, 1+->~30, 2+->~100, 3+->~300, 4+->>=1000 |
| pH | pH | Negative->5.0-6.0, Trace->6.5-7.0, 1+->7.5-8.0, 2+->8.5, 3+->>=9.0 |
| Blood | RBC/µL | Negative->0, Trace->~10, 1+->~25, 2+->~80, 3+->~200 |
| Specific Gravity | SG | Negative->1.000-1.010, Trace->1.015-1.020, 1+->1.025-1.030, 2+->>1.030 |
| Ketone | mg/dL | Negative-><5, Trace->~5, 1+->~15, 2+->~40, 3+->~80, 4+->~160 |
| Bilirubin | mg/dL | Negative->0, Trace->~0.5, 1+->~1, 2+->~2, 3+->~4 |
| Glucose | mg/dL | Negative-><100, Trace->100-249, 1+->250-499, 2+->500-999, 3+->1000-1999, 4+->>=2000 |

## How to answer panelist questions

### Q: “Where did you get the basis for these values?”
Use this structure:

1. **Classification first**: The app first predicts pad level by nearest color from calibrated references (AWB-corrected RGB/HSV).
2. **Value mapping second**: The predicted level is translated using a versioned profile (`baseline_v1`) for each analyte.
3. **Evidence basis**: That profile is based on thesis clinical anchors plus standard semiquant strip bins.
4. **Validation stance**: Final deployment values are locked to the exact strip IFU + lot card and then re-validated.

### Q: “Is this diagnostic?”
- No. The app is for **screening/risk stratification decision support** and requires confirmatory clinical testing.

## Recommended next step for thesis rigor
Create and freeze an **IFU-aligned profile** (for example `ifu_<brand>_<model>_<lot>_v1`) and log it in every capture/analysis export.
