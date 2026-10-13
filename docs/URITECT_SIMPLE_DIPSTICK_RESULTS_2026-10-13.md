# Simplified Dipstick Results

Source version: 1.5.19+37. APK installation is separate and not established by this note.

The Dipstick Results screen contains the expandable actual-photo pad preview, a plain analyte/value table, and Continue to Checklist, New Scan and Home actions. The summary/review banner, research details, category legend, save instruction, detection-count text, individual reading dropdowns and visible confidence/timing labels were removed from this screen at the owner's request. Preview captions are hidden here; the analysis animation retains its captions elsewhere. A scan without predictions shows a short no-readings/retake message rather than invented values.

This changes presentation only. Confidence, provenance, timing, support and rejection metadata are retained, and dependent Bayesian/renal calculation gates remain unchanged. Other screens retain their own details and safeguards. A plain displayed prediction is not newly validated by removal of its status label.

The Screening Summary also removes its top screening-status banner (including “Unable to complete screening” and the accompanying explanation) and the entire Research Details panel. Follow-up actions, missing-checklist messages, safety warnings, UTI/kidney guidance, checklist review, history protection and navigation remain intact. Saved estimates and calculation rules are unchanged.

For an undetected/incomplete strip, the retake card uses a prominent 24-point bold “Ten-pad dipstick not detected” heading. The checklist button is disabled unless a measured ten-pad count exists (or ten actual localization regions when the count is absent). An explicit zero/partial count cannot be overridden by a preview. New Scan and Home remain available. Ten pads located but no classification produces “Unable to read dipstick” instead; detection failure and unavailable readings are distinct. Research Details and Dataset Level Reference are absent from this retake screen.

The homepage uses “Scan your Dipstick” as its main heading, with “Start with a clear photo” beneath it. Live camera preview now covers the bordered viewport without distortion, cropping the displayed edges as needed. Focus coordinates account for the centered crop; the complete captured file remains unchanged for review and analysis. The alignment guide stays within the visible viewport. Gallery, Light and Grid have small visible captions and retain accessible action labels and disabled states.
