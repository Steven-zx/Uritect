# Device QA and pad-background guard — 2026-10-13

Version 1.5.18+36 adds a geometry guard after a real image reproduced a background box above the physical strip tip being assigned to leukocytes. This displaced the analyte assignments even though ten boxes had been found. The guard checks local background contrast, including illumination gradients. Backing-based candidates may instead supply persistent strip-edge evidence for genuinely pale pads. Unsupported layouts are rejected before localization events or classification are emitted. It can request more retakes; it does not establish clinical accuracy.

The regression uses a deidentified strip photograph and accepts either correct endpoint placement or rejection without reported pad regions. Other tests retain pale-strip, rotated-strip, missing-pad and multiple-strip coverage. The complete owner app suite passed 181 tests; static analysis reported no issues after removing one unused test import.

Camera actions now expose accessible labels and disable unavailable shutter/flash actions. Failed scans provide cause-specific retake guidance. A capture rejected before classification records `not_evaluated` rather than an obsolete model identifier. No classifier assets, reference labels, binary values, Bayesian formulas, history encryption or authentication rules changed.

## Actual baseline phone observations

RMX3933, Android 16, installed 1.5.17+35: startup reached the dashboard with saved history locked; camera opened without authentication. The owner submitted a blank camera photograph, which produced no readings. New Scan cleared the selected photo; Back returned to the dashboard. The owner then uploaded a strip photograph with unknown timing. Preliminary readings were displayed with unverified labels and a low-confidence pH label. The pad preview was inspected: placement was suspicious and was not accepted as correct localization. Home returned to the dashboard without a black screen. These observations belong to version 1.5.17+35 and must not be transferred automatically to the new APK.

The new signed APK and installation receipt are recorded separately. Repeat the same gallery image and a fresh blank capture on the new version. Unknown timing must remain unverified. Real-strip reference accuracy, multiple lighting conditions, permission denial/recovery, authenticated history, airplane-mode operation, a second phone and professional/clinical validation remain separate acceptance work.

## Dataset evidence

The earlier legacy audit remains historical, exploratory evidence. Its separate left/right background-reference check can miss smooth illumination gradients; the new app guard includes an interpolated reference. The legacy pool must pass the current guard before future model promotion. No new dataset or classifier has been promoted in this release.
