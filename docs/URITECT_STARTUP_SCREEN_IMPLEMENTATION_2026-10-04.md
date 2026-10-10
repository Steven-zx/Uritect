# Startup splash implementation — 2026-10-04

Implemented from Uritect Proposed Loading Screen.md, the attached Dart reference, and the research team's supplied palette. The user's implementation request authorizes replacing the manual welcome route with the proposal's recommended automatic route.

Cold app startup now opens AppSplashPage and replaces it with the existing RootPage after 2.2 seconds, using a 300 ms fade. Resuming an existing app session preserves its current screen. LandingPage remains in source for reference but is no longer the launch route. Scan analysis, camera/upload flows, history and clinical logic are preserved.

The splash uses the exact four-stop gradient, original logo, dark teal scanner corners, a 550 ms fade-in, a 2.5% frame-only pulse and a compact determinate progress line. The line measures the visual startup interval; it is not medical-analysis progress. Preparing offline screening is branding copy, not a claim that patient data or a model is being loaded. No preparation task, network request, analytics or data mutation was added. The optional supporting line was omitted to keep the layout quiet.

Reduced-motion or accessible-navigation settings show the completed static layout immediately. Navigation uses an independent cancellable timer so it cannot stall when animations are disabled. Responsive sizing and a scroll fallback accommodate small screens and large text. The existing theme typography is reused.

Android day/night launch backgrounds use #22A9BF, with explicit Android 12+ splash background and existing launcher icon resources. No native splash dependency or launcher-icon redesign was added. Platform-controlled launch animations are still controlled by Android.

Tests cover automatic entry, reduced-motion visibility and timing, replacement-route back behavior, disposal before the timer fires, small screen/large text layout, and a rendered phone reference. The golden uses Flutter test fonts; real-device typography must also be inspected. Samsung Galaxy A23 and an additional physical phone have not been tested in this session; the connected test device is the RMX3933.

Pilot build 1.4.0+10 and verification records are kept in output/device_pilot/2026-10-04. Physical camera parity from the preceding build remains a separate pending test; startup acceptance does not establish scan accuracy.
