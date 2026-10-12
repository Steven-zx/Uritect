# Poppins typography — 1.5.14+31

The app now uses one bundled Poppins family: headings Bold (700), section headings SemiBold (600), body Regular (400). Buttons and compact labels use SemiBold; existing emphasis may use Medium (500). Native font registration covers the complete Material theme, including inherited text, dialogs and form fields. Explicit section-weight overrides were aligned with the hierarchy. Screen content, color palette and navigation are retained.

Poppins Regular was added from the official Google Fonts repository; source URL, SHA-256, size and the existing SIL Open Font License are in assets/fonts. No runtime font download is needed. Legacy bundled Inter files are retained but no longer used by the app theme.

All 148 Flutter tests and static analysis passed. Phone goldens explicitly loaded the real bundled font faces; readings, Bayesian summary and actual-photo overlay were visually inspected. Small-screen and reduced-motion checks passed. This is automated layout evidence; the new APK still needs real-device acceptance. Classifier assets, pad orientation, timing schedule and Bayesian parameters were not modified by this typography change.

Earlier APKs and source archives remain preserved. The current identity is in CURRENT_EVALUATION_RELEASE.json; signed review and clinical evidence remain pending.
