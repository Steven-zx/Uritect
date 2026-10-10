# Camera versus photo upload investigation — 2026-10-04

## Report and evidence

User reports that URITECT camera captures fail strip detection while a separate photo taken with the phone Camera app, at a similar angle, succeeds when uploaded. These are different image files; an identical-byte comparison has not been performed. Device: RMX3933; installed baseline pilot versionCode 8.

Both inputs already call the same AnalyzingPage and LocalScanAnalysisService. The shared analyzer decodes images, bakes EXIF orientation, limits the analysis image to 1100 pixels on its longest side, and tries four orientations. There is no separate gallery classifier.

Confirmed acquisition defects/differences:

- Capture requested ResolutionPreset.high. The installed camera_android 0.10.10+17 ResolutionFeature maps this to the available 720p CamcorderProfile, falling back to lower profiles on unsupported hardware. This is not the phone's native full-resolution camera pipeline.
- Live preview used BoxFit.cover inside a differently shaped frame. Parts of the source image were hidden although the full source was sent to analysis. The captured/uploaded confirmation image was also cropped visually.
- Camera selection assumed the first enumerated lens; no explicit rear-lens preference or user-selected focus/exposure point existed.

These defects are corrected, but their contribution to the particular failed scan needs a paired phone retest. No failing camera file and successful upload file were available for pixel-level comparison.

## Implementation

- Request ResolutionPreset.max, the highest profile supported by the existing plugin, without a plugin/SDK upgrade.
- Prefer a rear camera, retaining a fallback when none is exposed.
- Let CameraPreview handle orientation/aspect ratio inside a centered, fully visible view; show confirmation images with BoxFit.contain.
- Start with automatic center focus/exposure; tapping the visible camera view sets normalized focus/exposure points. Unsupported optional controls retain device defaults individually.
- Prevent overlapping capture requests.
- Log the actual rejection reason with the URITECT scan rejected prefix so a future phone failure can be distinguished as localization, blur/exposure or classification confidence.

The detector, features, frozen model asset, confidence thresholds, clinical parameters and saved history are unchanged. Camera photos and native-camera uploads can still differ in focus, exposure, processing and sensor resolution. The preview stream may have a different resolution from still capture.

## Verification and next test

Two widget regressions cover portrait and landscape framing, preservation of aspect ratio inside the available viewport, and focus-point coordinates relative to the visible image. Automated results and APK installation are recorded in output/device_pilot/2026-10-04/SESSION.md.

Repeat the same strip/setup on the RMX3933: tap the pads to focus, wait for a sharp preview, capture and confirm that the whole strip remains visible in the photo, then submit. Compare with a separate native-camera photo uploaded through the gallery under the same lighting/distance. Record both outcomes and any app-scoped rejection reason. Also repeat a no-strip capture to confirm rejection remains intact. Do not equate successful detection with correct analyte labels.
