# URITECT Release 1.4.0 Clinical Sign-off Addendum

**Android release:** `1.4.0+5`  
**APK:** `Uritect_v1.4.0_sex_specific_bayesian_renal_v1.1_release.apk`  
**APK SHA-256:** `A244432523DE2ED8E33BC5D0F371EDD76450E1984AA1B76A3217038B5C1CF9A2`  
**Signing certificate SHA-256:** `15D1138DCE077ADA624A140B3A145343D1A48305FD0847E9002869E488F19D39`

## Clinical Components in This Build

| Component | Frozen version |
| --- | --- |
| Female Bayesian UTI research model | `uti_bayesian_female_v1_1_20260926` |
| Male Bayesian UTI research candidate | `uti_bayesian_male_v0_1_20261001` |
| Renal follow-up rules | `renal_followup_rules_v1.1_20260919` |
| Ten-analyte visual classifier | `production_semiquant_knn_markerless_roi_topfix_v3_20260908` |

Renal v1.1 rules and priority behavior are unchanged from the prior physician
packet. Release 1.4.0 changes the UTI module by adding explicit sex selection
and the separately sourced male candidate described in
`URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2`.

Final clinical comparison should use this APK checksum and the v1.2
sex-specific specification. Signing confirms review of implementation
alignment, not diagnostic calibration or clinical validation.

Reviewer name and credentials: __________________________________________  
Signature: ______________________________ Date: _________________________
