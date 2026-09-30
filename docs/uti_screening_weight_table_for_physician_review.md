# Superseded UTI Weight Table

This filename is retained only so old links do not silently open obsolete
guidance. The earlier version contained unsupported 20%/80% bands, numerical
visible-hematuria weighting, and numerical vaginal-symptom weighting. Those
features are **not part of the final implementation**.

Use these authoritative documents instead:

- Technical specification: `docs/URITECT_Bayesian_UTI_Scoring_System_v1.1.md`
- Two-medtech parameter review form:
  `docs/URITECT_Bayesian_Parameter_Validation_Form_v1.2.md`
- Implemented engine: `uritect_app/lib/models/screening_fusion.dart`

The implemented version is `uti_bayesian_lr_v1_1_20260926`.
It has a strict population gate, exact source-threshold analyte mapping, one
mutually exclusive dipstick factor, one mutually exclusive urinary-symptom
factor, no UTI probability bands, an explicitly provisional posterior display, and separate
alternate-cause and systemic-warning pathways.
