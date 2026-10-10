# RMX3933 camera parity pilot — 2026-10-04

User reports failure for in-app camera captures and successful upload of a separate native-camera photo of the same scene. Exact image pair not available. Wireless ADB authorized; baseline package versionCode 8.

Source fixes: rear-camera preference; highest supported capture profile; full-view camera and photo previews; automatic center focus/exposure and tap metering; overlapping shutter-request guard. Rejection diagnostic log added. Classifier, feature extraction, model asset and clinical thresholds untouched.

Validation: both new preview regression tests passed; full Flutter suite 71 tests passed; flutter analyze --no-pub returned no issues. Portrait and landscape aspect ratio, containment and normalized focus coordinates tested. Native sensor/auto-focus performance and strip detection on this phone are not established by widget tests.

Pilot versionCode 9 build/install and paired physical retest pending. Do not mark detection parity passed without observed results.

See docs/URITECT_CAMERA_UPLOAD_PARITY_FIX_2026-10-04.md for evidence, limits and retest protocol.

Release build completed successfully (248.9 s). Archived APK SHA-256 BABC92FAD7B2C1CAE06ADFAB58F49869D39935CE64E772D89037E9A902D0C5AF. ADB installation returned Success. Device reports versionCode 9/versionName 1.4.0. Cold launch Status ok, TotalTime 1059 ms (not scan-analysis latency). Paired strip test and blank-image rejection remain pending user observation.
Visible URITECT landing screen verified in pilot9_launch.png.

## Startup splash pilot

User authorized the proposed startup UI from docs/Uritect Proposed Loading Screen.md, the attached reference Dart text and supplied palette. Implemented AppSplashPage as the launch route, replacing manual ENTER with automatic 2.2-second entry to existing RootPage. Scan-analysis UI and workflow remain unchanged. Native day/night launch backgrounds match the top teal; Android 12+ launch attributes explicitly set.

Static analysis clean. Final full suite: 74 tests passed, recorded in splash_tests.log. Reduced-motion, timed replacement/back behavior, small screen/large text and phone golden checked. Rendered app_splash_phone.png inspected; synthetic test-font text differs from actual device typography. Build 1.4.0+10 and physical launch verification pending. No Samsung A23 or second physical device acceptance claimed.

Startup release build successful (205.6 s). Archived Uritect_v1.4.0+10_startup_splash_pilot.apk, SHA-256 4EEA19252264233AE1CC5D22424371DDA87573DB8BF86D4879080511447CBB59. Installed via ADB successfully; device package versionCode 10 verified. Phone asleep; user asked to unlock for physical visual check. No phone startup or native-flash acceptance claimed yet.
