# Pad-orientation incident and correction - 1.5.8+25

Final physical pad-order confirmation: On 2026-10-11 the owner confirmed the corrected preview as the final, MedTech-verified orientation for all supported scans. See [the final orientation contract](URITECT_FINAL_PAD_ORIENTATION.md) and [machine-readable pad order](URITECT_FINAL_PAD_ORDER.json). No further pad-order approval is pending; classifier performance is a separate issue.

Current status (2026-10-11): The owner reaffirmed the already established physical pad order and explicitly authorized installation of the corrected experimental classifier for supervised research testing, after disclosure of 79.92% per-analyte and 13.56% all-ten exploratory accuracy. The historical containment notes below describe 1.5.7+24; 1.5.8+25 restores classification using the re-extracted v3 candidate, regenerated model-bound distance policy, and an engineering pad-order verification flag. No new clinical/reference-label sign-off or calibration is claimed. Previous records remain unverified.

Physical order from tip toward handle is LEU, NIT, URO, PRO, pH, BLD, SG, KET, BIL, GLU. Handle at bottom: this is top to bottom. Handle at top: spatial order is GLU, BIL, KET, SG, BLD, pH, PRO, URO, NIT, LEU. The app normalizes the image internally to tip above handle and labels/classifies the corresponding physical ROIs. Each ROI goes to its own classifier; finished numeric readings are never blindly reversed.

Another MedTech evaluation is not a prerequisite for this established-order engineering correction. Independent clinical validation, reference-label quality, IFU timing, and final performance claims remain separate unresolved research tasks. Release evidence for the experimental build: output/device_pilot/2026-10-11/1.5.8+25.

Verified experimental-build checks: 134 Flutter tests passed; static analysis found no issues. The 18 selected development photos produced one accepted scan (five previously accepted photos are now rejected, and the retained scan has changed readings). This is not a representative retake-rate or accuracy estimate. The exact Messenger photo localizes all ten physical pads, but is rejected for low pH confidence. These limitations are not fixed by the orientation correction, and the confidence threshold was not lowered. The annotated actual-photo preview is output/device_pilot/2026-10-11/1.5.8+25/CORRECTED_PAD_IDENTIFICATION.png.

## Historical containment evidence (1.5.7+24)

The supplied screenshot assigns LEU to the handle-adjacent teal pad and GLU to the physical tip. The prior classifier uses the same labeled ROI coordinates, so this is a classifier-input defect, not just animation text.

Confirmed findings:
- Legacy/background/local-contrast extraction could choose 180-degree inversion by geometry quality without physical direction evidence. Only the later backing fallback had a direction check.
- The stored features for LAUAAN-P005-L4000 exactly match an unchecked raw extraction whose handle is at the top. The 180-degree extraction differs. This confirms at least one reversed training input.
- The old Cabatuan regression fixture can also select background as an endpoint and miss a physical pad. Consistency tests did not establish physical correctness.

Containment:
- All app and markerless Python extraction branches require measurable shaft extension beyond GLU, independently of classifier votes. Local-background interpolation and continuity reduce lighting-gradient false positives. Uncertain direction is rejected, never guessed by pad color category.
- The exact supplied Messenger photo now returns upright measured regions (LEU crop y=114, GLU y=814 in the 1100-pixel prepared image). The exact physical teal handle-adjacent pad is checked in four rotations. The previous pale-pad phone fixture is checked against independently observed endpoint color, rather than its old predictions.
- The old production model is suspended in app and live Python scanning. Current scans can display actual localized regions, but no analyte readings or dipstick-dependent estimates are returned. Symptom safety checks remain available.
- Saved records are preserved. Direction and model-review evidence must both be explicitly present for a new interpretation; missing evidence fails closed. The affected model is blacklisted, with visible archive warnings, and its stored Bayesian estimate is not displayed as an actionable result.
- Candidate models require an explicit completed physical-pad review flag and a new direction_verified_ version before live classification can resume. Engineering audit acceptance alone does not set that flag.

Data work:
- Final audit: pipeline/output/orientation_audit_2026-10-11_v3/SUMMARY.json and EVENT_AUDIT.json.
- 784 existing events audited; 565 satisfy the engineering direction/localization checks, 219 remain excluded/unresolved. Twenty-two previous feature vectors are flagged as likely reversed by forward/reversed feature-distance comparison; these flags are review leads, not individual clinical-label confirmation.
- Candidate features: 5,650 rows, preserving existing reference labels. Historical input CSVs and gold labels are not overwritten.
- A separate k-NN review candidate retains the existing hyperparameter configuration. Its exploratory grouped evaluation is 79.92% individual-analyte and 13.56% all-ten accuracy on the changed retained subset. These are not directly comparable to the old evaluation and are not final clinical validation. This candidate is NOT deployed.
- Earlier contrast-only/signed-brightness audits and candidates are superseded engineering experiments, retained for traceability; only v3 is the current review packet.
- Historical model card and five-metric report now carry orientation alerts. App performance notes disclose the suspension. Old percentages must not be claimed as current physically verified scanner performance.

Required next review:
1. A medical technologist verifies physical strip manufacturer/IFU pad order and checks actual tip/handle and all ten boxes against representative raw photographs, including the 219 unresolved events and 22 suspected reversals.
2. Confirm reference labels and reaction timing. Do not reverse already-classified result labels: each analyte classifier has distinct category semantics. Re-extract and reclassify source images after correction.
3. Improve and evaluate the corrected development candidate with participant/specimen grouping, rare-abnormal analysis and retake coverage. Its present all-ten performance is insufficient for dependable complete-strip claims. Obtain a fresh untouched confirmation set.
4. Only then approve a newly versioned model and regenerated training-support policy. Expert content review still does not calibrate Bayesian percentages against clinical outcomes.

Release evidence: output/device_pilot/2026-10-11/1.5.7+24. This is a containment/geometry pilot, not a completed validated classifier release. Historical encrypted records, keys, APKs and release archives are preserved.
