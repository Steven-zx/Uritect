# Strip-analysis explanation animation - 2026-10-11

Candidate: **1.5.5+21**, following the single startup/results/navigation release 1.5.4+20.

## Experience

The Analyzing screen now centers a small vector illustration titled How the strip is read. It shows an example strip, a scanner sweep, ten pad outlines, moving color samples, and a labeled reference-color panel. The four captions explain finding the strip, locating pad regions, sampling colors and comparing references. Styling uses the existing teal palette and a quiet grid background.

The actual status sits below the illustration and uses the analyzer's real reported stage names, including loading_production_model and locating_markerless_strip. Current native/local analysis reports strip detection and classification as one combined stage: the four-step illustration loops during that stage rather than pretending to expose verified per-pad detections. The visible label says Illustration: not an overlay on your photo. No diagnostic values, measured colors, confidence claims, detection counts or success badges are inferred from the drawing.

The simulated percentage counter and forced finish-progress delay were removed. A compact indeterminate indicator is displayed during normal-motion analysis; analysis completion, rejection and retake routing are still driven by the real service future. There is no artificial minimum wait to finish the educational loop.

## Accessibility and behavior

The illustration is drawn with Flutter Canvas, with no video, external assets, new dependencies or network access. Only its widget repaints during the animation. It pauses when the app backgrounds; Flutter's route ticker handling mutes it when covered. Reduced-motion or accessible-navigation settings show a static overview and remove the moving progress bar. An accessible description explains the strip, ten regions and reference comparison. The content scrolls on small screens with enlarged text.

The native single startup logo remains unchanged. The camera guide, Home navigation fix, reliability rules, detector/classifier/model assets, Bayesian values, encrypted history and editable names are unchanged. This is an explanatory UI feature, not a new detection algorithm or accuracy evaluation.

## Checks

Tests verify that an illustration cycle cannot complete a pending analysis or invent detection evidence; a real LOW_CONFIDENCE failure still leads to unreadable results and retake guidance. They check small-screen/large-text layout, a static reduced-motion view without ongoing animation, background pause/resume, disposal, and existing Home/New Scan paths. A bundled-font 360x800 visual reference is in uritect_app/test/goldens/strip_analysis_phone.png and was visually inspected.

Full tests, static analysis, signed APK build, source freeze and asset/signature checks are recorded under output/device_pilot/2026-10-11/1.5.5+21. Prior development image-regression evidence is explicitly retained because image-analysis code and model assets are unchanged. Actual phone acceptance of animation smoothness and clarity remains pending a scan walkthrough; install/launch status is recorded separately.
