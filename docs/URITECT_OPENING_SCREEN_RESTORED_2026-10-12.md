# Opening screen restored — 1.5.12+29

The owner requested restoration of the gradient URITECT launch screen shown in the reference screenshot. The app now opens with the existing logo, dark teal scanner corners, teal-to-aqua-to-white gradient, “Preparing offline screening…” and a compact progress indicator. After 2.2 seconds it replaces the launch route with the dashboard using a 300 ms fade. Returning home does not reopen the splash.

Android's mandatory native launch stage uses the matching teal background and a transparent icon; the earlier standalone logo stage is removed. Android 12+ controls the timing of its native launch surface. The Flutter screen provides the full layout and progress indicator.

The indicator is launch presentation, not measured model-loading progress or a medical analysis. Reduced-motion mode uses a static indicator and immediate route transition. Disposal cancels pending navigation. The classifier, physical analyte order, safety gates, Bayesian values and history security are unchanged.

Files: `lib/pages/app_splash_page.dart`, `lib/main.dart`, Android launch resources and startup navigation tests. This version supersedes 1.5.11+28 for the requested UI change; older frozen artifacts remain historical evidence. Installation requires a connected phone.
