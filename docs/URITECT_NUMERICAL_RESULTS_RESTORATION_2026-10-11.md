# Numerical results restoration - 1.5.9+26

The owner requested restoration of all numerical outputs after the pad-locator correction and installation of the updated APK. The final MedTech-verified physical order remains LEU, NIT, URO, PRO, pH, BLD, SG, KET, BIL, GLU from tip toward handle.

Previous behavior discarded every classified value when any one pad failed the model vote-confidence threshold. This made a weak pH classification suppress even unrelated UTI-input readings.

Updated behavior:
- After verified geometry and the model-bound training-support check pass, all ten classifier outputs are retained and displayed. A low-confidence pad is visibly provisional, with its vote-confidence percentage. Vote confidence is not a probability of correctness.
- Whole-strip reliability still fails when a pad fails confidence. The result is stored as review_required with LOW_CONFIDENCE and the warning, not silently upgraded to complete.
- Bayesian female calculation requires adequate LEU/NIT/BLD confidence; the male calculation requires LEU/NIT. Renal rules require adequate PRO/BLD. Irrelevant low pH or SG confidence no longer disables these independent calculations.
- The existing 0.55 experimental-model vote threshold, absolute-distance support rejection, exact ten-pad safety metadata, provenance/specimen checks, eligibility exclusions, quality/timing confirmations and safety overrides remain. Invalid geometry, unsupported inputs, and missing dependent evidence do not receive fabricated numerical outputs.
- All existing Bayesian priors, likelihood ratios, formulae and research framing are retained. Calculable percentages and calculation details remain visible on Overall Results after the checklist; unavailable calculations explain why.
- Encrypted storage and keys, old-record quarantine, patient names, capture/grid, orientation-normalized ROI animation and navigation are preserved. The classifier assets and support policy are identical to 1.5.8+25; this is a results-retention and dependency-gating fix, not another model training change or accuracy improvement.

Verification includes a real-photo reproduction, full Flutter tests and static analysis. Targeted cases verify low pH retains readings without changing the Bayesian percentage, low LEU blocks UTI only, low protein blocks renal only, low blood blocks both female UTI and renal, missing metadata/provenance fail closed, and the provisional numerical value plus confidence appears in the results UI.

Release evidence: output/device_pilot/2026-10-11/1.5.9+26. Numerical outputs remain experimental research results; classifier performance and Bayesian calibration limitations are unchanged.
