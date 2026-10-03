# URITECT UTI eligibility authority

Audit date: 2026-10-03. Candidate model parameters have not changed.

The executable authority for required confirmations is ScreeningFusionEngine.commonEligibilityConfirmations, femaleEligibilityConfirmations and maleEligibilityConfirmations in uritect_app/lib/models/screening_fusion.dart. UI labels are defined by the same IDs in clinical_symptoms.dart. This document is the human-readable contract for manuscript, forms and diagrams; the actual editable manuscript/diagrams must be checked by the research team.

| Requirement | Female v1.1 | Male v0.1 |
| --- | --- | --- |
| Exactly one sex selected | Female only | Male only |
| Confirmed age | 18–64 | 18–64 |
| No urinary catheter | Required | Required |
| No known urinary tract abnormality | Required | Required |
| Not immunocompromised | Required | Required |
| Confirmed nonpregnancy | Required | Not a male confirmation |
| No diabetes | Not a female confirmation | Required |
| No suspected STI | Not a female confirmation | Required |
| At least one acute qualifying symptom | Dysuria, frequency, urgency, suprapubic pain or visible hematuria | Dysuria, frequency or urgency |

Unchecked eligibility means unconfirmed/unknown and blocks calculation. Symptoms not selected receive no numerical absent-symptom LR. Both-sex/neither-sex selection blocks calculation. Pregnancy is outside the female calculation; the checkbox does not diagnose pregnancy or infer status.

Vaginal discharge/irritation routes away from the ordinary estimate. The male UI clears/hides those female pathway inputs when male is selected; malformed imported checklist flags remain conservatively blocking. Fever/chills, flank/back pain, nausea/vomiting, inability to hydrate/medicate, or confusion/fainting/severe weakness stop the ordinary estimate. Existing renal PROMPT_CONSULT safety triggers also stop it in the full scan workflow without combining renal findings into posterior arithmetic.

Invalid/partial/low-confidence scans and declared strip-quality failures block numerical estimates, including symptom-only estimates. Symptom-based safety and follow-up guidance remain available. Renal actions keep the frozen priority PROMPT_CONSULT > RETAKE > CONSULT > REPEAT_CONFIRM > OBSERVE.

The model-specific starting prior and factors remain provisional. Issues of source-population transportability, conditioning and cross-group multiplication require statistician review; eligibility gates do not validate the model.

For clinical review: the physical strip IFU/timing identity remains unconfirmed. The app's 60-second protein/blood timing is a frozen software profile, not a verified manufacturer identity. Do not change timing, thresholds or eligibility from assumption alone.
