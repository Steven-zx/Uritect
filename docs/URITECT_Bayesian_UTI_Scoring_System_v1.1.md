# URITECT Bayesian UTI Scoring System v1.1

**Implemented model:** `uti_bayesian_lr_v1_1_20260926`  
**Method:** Provisional grouped likelihood-ratio Bayesian research estimate  
**Prior:** 50% for the narrowly gated population only  
**Status:** Frozen app implementation; literature-derived and not clinically calibrated

> Plain explanation: URITECT can calculate a research estimate only for a
> narrowly defined group of symptomatic women. For an eligible calculation,
> the app shows the provisional percentage, the starting prior, and the exact
> evidence factors used. It is not a diagnosis, treatment recommendation, or
> Low/Moderate/High UTI category.

## 1. What Changed From Version 1.0

| Review finding | Version 1.1 correction |
| --- | --- |
| Combined model was not validated as one probability model | Calls it provisional and literature-derived; explicitly states the independence assumption and validation requirement. |
| Visible hematuria could duplicate dipstick blood | Removed its LR from the equation; retained it as consultation context. |
| Vaginal findings came from a different population | Removed their LRs from the equation; either finding stops ordinary calculation and routes to consultation. |
| The 50% prior was too broadly applicable | Added six required population confirmations and an acute urinary-symptom gate. |
| Analyte positivity was too broad | Added exact URITECT-to-study threshold mapping. |
| 20% and 80% bands were invented | Removed every probability band and UTI likelihood label. |
| Unknown could be interpreted as absent | Defined unchecked, unknown, unavailable, and unreliable as no update. |
| Nausea alone triggered an urgent pathway | Prompt action now requires an approved combination or serious safety condition. |

## 2. Intended Population Gate

The estimate is calculated only when **all six confirmations** and at least one
acute urinary symptom are present.

| Gate ID | Required confirmation |
| --- | --- |
| E1 | Patient is a woman. |
| E2 | Patient is 18 to 64 years old. |
| E3 | Patient is confirmed not pregnant. |
| E4 | Patient does not have a urinary catheter. |
| E5 | Patient has no known urinary tract abnormality. |
| E6 | Patient is not immunocompromised. |
| E7 | At least one acute urinary symptom is reported: dysuria, urgency, frequency, suprapubic pain, or visible hematuria. |

The ordinary calculation is stopped when vaginal discharge, vaginal
irritation, fever/chills, flank pain, or nausea/vomiting is reported. The app
then shows a consultation action instead of an ordinary lower-UTI estimate.

If a required confirmation is unchecked, its state is **not confirmed or
unknown**. It is not assumed to be false. The app displays:

> This UTI screening estimate is not designed for your reported situation.
> Consultation with a healthcare professional is suggested.

## 3. Exact Dipstick Mapping

The frozen ten-analyte k-NN model uses the labels below. Source-study
positivity follows Little et al.: leukocyte esterase `+` or greater and blood
`haemolysed trace` or greater.

| Analyte | URITECT label | Treatment in Group A |
| --- | --- | --- |
| Nitrite | `Positive` | Positive |
| Nitrite | `Neg` / `Negative` | Confirmed negative |
| Leukocytes | `Small 70`, `Moderate 125`, `Large 500` | Positive (`+` or greater) |
| Leukocytes | `Trace 15` | No source-matched update; not positive and not negative |
| Leukocytes | `Neg` / `Negative` | Confirmed negative |
| Blood | `Hemolyzed 10`, `Small 25`, `Moderate 80`, `Large 200` | Positive (hemolyzed trace or greater) |
| Blood | `Non-hemolyzed 10` | No source-matched update; not used as the Little threshold |
| Blood | `Neg` / `Negative` | Confirmed negative |
| Any | `Unavailable`, invalid, or unreliable | LR 1.00; no update |

**Strip profile used in software:** URS-10T. The study threshold mapping above
is frozen in the implementation. The physical product's exact manufacturer,
lot, IFU revision, and reaction-time instructions must still be recorded for
each validation run; they must not be inferred from the generic URS-10T name.

## 4. Evidence Library

These values are retained to show the cited evidence. Not every value is used
in the implemented equation.

| Finding | LR+ / present | LR- / absent | Population and reference standard | Implemented? |
| --- | ---: | ---: | --- | --- |
| Nitrite | 5.50 | 0.56 | Symptomatic women; review table based on culture-referenced evidence | LR+ only through Group A hierarchy |
| Leukocyte esterase | 1.40 | 0.40 | Symptomatic women; review table based on culture-referenced evidence | LR+ only through Group A hierarchy |
| Dipstick blood | 1.70 | 0.89 | Symptomatic women; review table based on culture-referenced evidence | LR+ only through Group A hierarchy |
| Dysuria | 1.30 | 0.67 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Urgency | 1.20 | 0.75 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Frequency | 1.10 | 0.71 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Dysuria with urgency | 1.50 | 0.44 | Symptomatic women; culture-referenced evidence review | Present LR only |
| Visible hematuria | 2.00 (95% CI 1.3-2.9) | Not assigned | Meta-analysis of signs/symptoms in women with acute uncomplicated UTI | No; context only |
| Vaginal discharge | 0.30 (95% CI 0.1-0.9) | Not assigned | Same Bent review | No; alternate-cause route |
| Vaginal irritation | 0.20 (95% CI 0.1-0.9) | Not assigned | Same Bent review | No; alternate-cause route |
| Nitrite plus leukocytes or blood | 7.20 | Not assigned | 427 women with suspected UTI; laboratory diagnosis using European urinalysis guideline | Yes |
| Nitrite, leukocytes, and blood all negative | Not assigned | 0.22 | Same Little validation study | Yes |

The AAFP table's displayed post-test probabilities assume a 50% pretest
probability. Bent et al. reports an approximate 50% probability among women
presenting with one or more UTI symptoms. This supports 50% only as a
provisional starting assumption for the gated study-like population.

## 5. Exact Implemented Scoring Hierarchy

### 5.1 Group A - Dipstick Pattern

Apply the first matching rule only.

| Rule | Pattern | Candidate LR |
| --- | --- | ---: |
| A1 | Nitrite positive plus source-threshold leukocytes or blood positive | 7.20 |
| A2 | Nitrite positive without either additional source-threshold positive finding | 5.50 |
| A3 | Nitrite not positive or unavailable; source-threshold blood positive | 1.70 |
| A4 | Nitrite and blood not positive; source-threshold leukocytes positive | 1.40 |
| A5 | Nitrite, leukocytes, and blood all confirmed negative | 0.22 |
| A6 | No rule above matches | 1.00; no update |

### 5.2 Group B - Urinary Symptom Pattern

Apply the first matching rule only.

| Rule | Pattern | Candidate LR |
| --- | --- | ---: |
| B1 | Dysuria and urgency present | 1.50 |
| B2 | Dysuria present | 1.30 |
| B3 | Urgency present | 1.20 |
| B4 | Frequency present | 1.10 |
| B5 | None of the weighted symptoms is reported | 1.00; no update |

Visible hematuria and suprapubic pain can satisfy the symptomatic eligibility
gate but have no numerical factor in v1.1. Visible hematuria triggers a
separate consultation-context message.

### 5.3 State Handling

| Input state | Numerical treatment |
| --- | --- |
| Present | Apply the approved present LR if the variable is in Groups A or B. |
| Confirmed absent | No symptom-negative LR is used in v1.1. Exact dipstick negatives may satisfy A5. |
| Not selected / not asked / unknown | LR 1.00; no update. |
| Unavailable / unreliable | LR 1.00; no update. |
| Not applicable or outside population | Do not calculate. |

## 6. Equation

```text
prior probability = 0.50
prior odds = 0.50 / (1 - 0.50) = 1.00

posterior odds = prior odds x selected Group A LR x selected Group B LR
posterior probability = posterior odds / (1 + posterior odds)
```

Example for an eligible patient with nitrite plus leukocytes positive and both
dysuria and urgency:

```text
posterior odds = 1.00 x 7.20 x 1.50 = 10.80
research posterior = 10.80 / 11.80 = 0.915 or 91.5%
```

This arithmetic is correct, but the combined equation is a **URITECT design
assumption**. The cited sources do not validate the exact multiplication of
Group A and Group B as a single calibrated clinical model. Dependency,
transportability, and calibration require culture-confirmed patient-level
validation and statistical review.

## 7. Separate Action Pathways

| Trigger | App action |
| --- | --- |
| Eligibility incomplete or outside intended population | Consultation with a healthcare professional is suggested. |
| Vaginal discharge or irritation | Other conditions may cause similar symptoms. Consultation is suggested; no ordinary posterior. |
| Visible hematuria | Consultation is suggested; no hematuria LR is added. |
| Fever with flank pain | Prompt medical consultation is suggested. |
| Nausea/vomiting with fever or flank pain | Prompt medical consultation is suggested. |
| Vomiting prevents hydration or oral medication | Prompt medical consultation is suggested. |
| Confusion, fainting, or severe weakness with a urinary finding | Prompt medical consultation is suggested. |
| Nausea/vomiting alone | Consultation is suggested; it does not independently activate the prompt pathway. |
| No usable source-matched evidence | Insufficient evidence. The 50% prior is not shown as a patient result. |

The UTI pathway is separate from the renal follow-up engine. Neither pathway
recommends antibiotics or diagnoses disease.

## 8. Display and Audit Rules

- No 20%/80% thresholds exist in v1.1.
- No Lower, Intermediate, or Higher UTI probability label is produced.
- An eligible calculation displays the provisional percentage, 50% prior, and each applied LR.
- The display label is: **Bayesian UTI screening estimate - screening support only, not a diagnosis or treatment recommendation.**
- The calculated posterior and factors are also stored in the local scan audit record.
- The model version and calculation status are stored with the result.
- A blocked or insufficient case stores no patient-specific posterior.

## 9. Validation Boundaries

Two registered medical technologists may assess relevance, clarity,
manufacturer-label mapping, workflow feasibility, missing-result handling, and
laboratory limitations. Content Validity Index agreement does **not** establish
diagnostic accuracy or probability calibration.

Before any clinical probability claim, the complete model requires:

- Physician review of population gates, symptom meaning, actions, and safety wording.
- Statistician or clinical prediction-model review of priors, dependence, calibration, and reporting.
- Prospective culture-confirmed patient-level validation, including calibration assessment and confidence intervals.
- Validation of the exact supported strip product, IFU revision, reading times, phone/camera workflow, and classifier errors.

## 10. Medical Technologist Review Checklist

Rate each item: `4 = highly relevant/clear`, `3 = relevant/clear with minor
revision`, `2 = major revision needed`, `1 = not relevant/unclear`.

| ID | Review statement | 1 | 2 | 3 | 4 | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | The intended population gate is understandable. | [ ] | [ ] | [ ] | [ ] | |
| C2 | Unchecked eligibility items are clearly treated as unknown. | [ ] | [ ] | [ ] | [ ] | |
| C3 | Nitrite positive mapping is appropriate for the supported strip. | [ ] | [ ] | [ ] | [ ] | |
| C4 | Leukocyte `+` threshold mapping is clear. | [ ] | [ ] | [ ] | [ ] | |
| C5 | `Trace 15` leukocytes are correctly excluded from source-threshold positivity. | [ ] | [ ] | [ ] | [ ] | |
| C6 | Hemolyzed-trace blood mapping is clear. | [ ] | [ ] | [ ] | [ ] | |
| C7 | Non-hemolyzed trace blood is appropriately excluded from the Little threshold. | [ ] | [ ] | [ ] | [ ] | |
| C8 | Missing, unreliable, and negative results are clearly distinguished. | [ ] | [ ] | [ ] | [ ] | |
| C9 | One mutually exclusive dipstick factor reduces duplicate counting. | [ ] | [ ] | [ ] | [ ] | |
| C10 | Visible hematuria is appropriately retained as context without a numerical LR. | [ ] | [ ] | [ ] | [ ] | |
| C11 | Vaginal symptoms are appropriately routed to consultation. | [ ] | [ ] | [ ] | [ ] | |
| C12 | The systemic-symptom action wording is clear and safe. | [ ] | [ ] | [ ] | [ ] | |
| C13 | The 50% prior limitation is stated clearly. | [ ] | [ ] | [ ] | [ ] | |
| C14 | The lack of local calibration is stated clearly. | [ ] | [ ] | [ ] | [ ] | |
| C15 | The distinction between CVI and clinical validation is clear. | [ ] | [ ] | [ ] | [ ] | |
| C16 | The workflow is feasible for intended rural/offline use. | [ ] | [ ] | [ ] | [ ] | |

**Overall decision:** [ ] Accept as written  [ ] Accept with minor revisions  [ ] Major revision required  [ ] Reject

Reviewer name and credentials: ______________________________  
Registration/license number: ________________________________  
Institution: ________________________________________________  
Signature: __________________________  Date: _________________

## 11. Required Product and Validation Record

| Field | Entry |
| --- | --- |
| Strip manufacturer | ______________________________ |
| Exact product/catalog number | ______________________________ |
| Lot number and expiry | ______________________________ |
| IFU revision/date | ______________________________ |
| Nitrite reaction time | ______________________________ |
| Leukocyte reaction time | ______________________________ |
| Blood reaction time | ______________________________ |
| Phone model / Android version | ______________________________ |
| App version / model version | `1.3.0+4` / `uti_bayesian_lr_v1_1_20260926` |

## 12. References

1. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults: Rapid Evidence Review. *American Family Physician*. 2024;109(2):167-174. https://www.aafp.org/afp/2024/0200/acute-uncomplicated-utis-adults
2. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict urinary tract infection in primary care settings. *British Journal of General Practice*. 2006;56(529):606-612. https://pmc.ncbi.nlm.nih.gov/articles/PMC1874525/
3. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does this woman have an acute uncomplicated urinary tract infection? *JAMA*. 2002;287(20):2701-2710. https://pubmed.ncbi.nlm.nih.gov/12020306/

## 13. Final Reviewer Acknowledgment

I understand that this review evaluates content and implementation clarity. It
does not establish that the combined posterior is calibrated or clinically
valid, and it does not replace physician, statistical, or culture-confirmed
validation.

Reviewer signature: __________________________  Date: _________________
