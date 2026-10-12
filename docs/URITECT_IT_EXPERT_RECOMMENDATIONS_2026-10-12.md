# IT expert recommendations — 1.5.15+33

The owner supplied three recommendations: reduce scan processing time and provide progress, detect poor lighting/blur before pad analysis, and simplify screens with consistent navigation. Reviewers' names, signatures and exact earlier reviewed version were not supplied; no formal review completion is inferred.

## Processing and quality

Photo quality now runs once on the decoded, resized image before model parsing, image rotations, strip localization or classification. The old detector repeated the quality pass across up to 24 detector/orientation attempts. Mean/variance/saturation and the focus proxy are computed in one streaming pass instead of allocating sample lists and HSV arrays. Existing darkness, overexposure, blank and blur thresholds are retained. Geometry, orientation, per-pad readability, confidence, distance-support and timing checks remain in place.

Worker events now report decoding, quality screening and localization. The UI shows monotonic milestone progress and four named steps. Percentages describe pipeline milestones, not elapsed-time predictions or diagnostic confidence. Actual measured photo overlays remain; the pad reveal interval is 90 ms instead of 180 ms, with immediate/static presentation for reduced motion.

On the same fixed deidentified strip fixture, warm host Flutter-test runs were 2529/2275/2386 ms before and 2383/2141/2128 ms after. Median changed from 2386 to 2141 ms (10.27% shorter). This small non-isolated host benchmark is not a guarantee for Android hardware, a production benchmark, or evidence of improved classifier accuracy. Test the signed APK on real devices before claiming device speed.

Quality checks identify gross exposure/focus problems; a sharp background does not prove a sharp pad, and passing a global quality check does not validate the specimen or every reagent color. No clinically validated new quality cutoff is claimed.

## Professional UI

The dashboard has a single primary Start Scan card, a consistent welcome header, protected Recent Scans and a collapsible preparation checklist. Text wraps on small screens and large text; fixed manual line breaks were removed from the primary card. The root no longer nests redundant scaffolds.

Analyte values remain visible in a compact list. Unmatched timing, absent confidence and low confidence are visible review notices; timing, vote confidence and references expand per analyte. Bayesian values and serious safety warnings remain accessible, with actionable warnings kept visible. Existing Home/New Scan/checklist routes and protected-history update behavior remain covered by tests. No classifier, pad order, Bayesian LR/prior or interpretation threshold was changed.

## Reviewed version and handoff

[The review form](DEVELOPER_EVALUATION_REVIEW_FORM.md) now includes **Repository commit, release tag, or version reviewed** and an APK checksum field. The expert packet, pending-review records and statistical decision CSV also include source identity. Evaluators fill these fields; software approval is distinct from clinical validation.

The app suite passed 156 tests. Dashboard, compact readings and overlay screenshots were inspected with real bundled Poppins fonts; 280-pixel phone width/180% text, uncertainty expansion, progressive measured regions and Home navigation were checked. Frozen-source and signed-APK evidence are recorded separately. This build's real-device acceptance remains pending.
