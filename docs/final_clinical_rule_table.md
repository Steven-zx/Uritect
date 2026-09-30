# Final Clinical Interpretation Table

This document summarizes the frozen clinical interpretation implemented in
URITECT 1.3.0. Ten semiquantitative strip results remain visible. UTI screening
and renal follow-up are calculated separately and are never merged into one
risk score.

## Bayesian UTI Pathway

The ordinary estimate is available only for symptomatic, nonpregnant women
aged 18 to 64 with all six eligibility confirmations and no alternate-cause or
systemic warning finding.

| Group | First matching evidence pattern | LR |
| --- | --- | ---: |
| Dipstick A1 | Nitrite positive plus leukocytes or blood positive at the source-matched threshold | 7.20 |
| Dipstick A2 | Nitrite positive without either additional positive finding | 5.50 |
| Dipstick A3 | Nitrite not positive or unavailable; blood positive | 1.70 |
| Dipstick A4 | Nitrite and blood not positive; leukocytes positive | 1.40 |
| Dipstick A5 | Nitrite, leukocytes, and blood all confirmed negative | 0.22 |
| Symptom B1 | Dysuria and urgency present | 1.50 |
| Symptom B2 | Dysuria present | 1.30 |
| Symptom B3 | Urgency present | 1.20 |
| Symptom B4 | Frequency present | 1.10 |

Only one dipstick LR and one symptom LR can be applied. Unknown, unchecked,
unavailable, and unreliable inputs receive no update. Visible hematuria is
context only and does not add an LR. Vaginal discharge or irritation stops the
ordinary calculation and routes to consultation.

The calculation is:

```text
prior odds = 0.50 / (1 - 0.50) = 1.00
posterior odds = prior odds x selected dipstick LR x selected symptom LR
posterior = posterior odds / (1 + posterior odds)
```

For an eligible result, the app displays the provisional posterior, the 50%
prior, and every applied factor. It does not assign Low, Moderate, or High
probability bands and does not recommend treatment.

## Safety And Alternate-Cause Pathways

| Trigger | Output |
| --- | --- |
| Eligibility not confirmed or outside intended population | Consultation suggested; no ordinary UTI estimate |
| Vaginal discharge or irritation | Alternate-cause consultation message; no ordinary UTI estimate |
| Visible hematuria | Consultation context; no hematuria LR |
| Fever with flank pain | Prompt medical consultation suggested |
| Nausea/vomiting with fever or flank pain | Prompt medical consultation suggested |
| Inability to maintain hydration or oral medication | Prompt medical consultation suggested |
| Confusion, fainting, or severe weakness with a urinary finding | Prompt medical consultation suggested |

## Renal Follow-Up Pathway

The separate `RenalFollowupEngine` uses reliable protein and blood categories,
renal safety symptoms, interference questions, and explicit repeat-test history.
It stores all triggered rule IDs and selects the highest-priority final action:
`RETAKE`, `PROMPT_CONSULT`, `CONSULT`, `REPEAT_CONFIRM`, or `OBSERVE`.

This pathway does not calculate a kidney-disease probability and does not infer
possible or managed UTI from the Bayesian percentage.

## Excluded Methods

The production app does not use binary normal/abnormal classifiers, unsupported
weights, invented probability thresholds, a Bayesian renal score, or one merged
disease-risk score.
