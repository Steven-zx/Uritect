# Laua-an Markerless Scan Method

For the Laua-an dataset and the current app validation path, Uritect does not
require the older black/white macro-marker.

## Current Runtime Method

1. The app sends a single captured dipstick image to `pipeline/scan_dipstick.py`
   through the local scan server.
2. The scanner tests EXIF/raw and rotated image orientations.
3. For each orientation, markerless localization is attempted first.
4. The markerless detector finds the visible dipstick strip using vertical edge
   structure and horizontal reagent-pad edge structure.
5. The detector estimates a 10-pad ROI grid across the detected reactive pad
   stack.
6. White balance is performed with gray-world correction using low-saturation
   neutral pixels near the detected strip/plastic area.
7. Mean HSV values are extracted for each of the 10 pads and normalized into
   the `normalized_hsv` feature space.
8. The optimized per-analyte semiquant KNN models classify all 10 parameters.

## Legacy Fallback

The old macro-marker pipeline remains as a fallback for older marker-based
images only. It should not be described as the primary method for Laua-an
validation.

## Manuscript Alignment

Chapter 1 should describe the markerless method above if the validation study
uses the Laua-an dataset and current app scanner. Avoid claiming that AWB uses
only unreacted white plastic or that ROI detection is only adaptive
thresholding/contours, because the implemented runtime method now uses detected
strip geometry and neutral strip/plastic pixels.

