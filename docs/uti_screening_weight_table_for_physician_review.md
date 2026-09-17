# Bayesian UTI Screening Candidate for Physician Review

## Status and Intended Use

The Android app implements this specification as
`uti_bayesian_lr_candidate_v1_20260917`. It is a research candidate pending
physician review, local calibration, and validation against urine culture. It
must not be described as clinically validated or used as a standalone
diagnosis.

The evidence base applies primarily to nonpregnant adult women presenting in
primary care with symptoms of acute uncomplicated lower urinary tract
infection. It must not be generalized without separate validation to children,
pregnant patients, catheterized patients, men, or patients with known urologic
abnormalities, immunocompromise, or systemic illness.

The ten-analyte KNN classification and the Bayesian UTI estimate are separate:
the KNN predicts reagent-pad classes; this module interprets the resulting
nitrite, leukocyte esterase, and blood findings together with reported symptoms.

## Frozen Candidate Parameters

- Prior probability: 0.50.
- Prior basis: the AAFP 2024 evidence table reports post-test probabilities
  using 50% prevalence; the same review reports 45% to 65% culture-confirmed
  prevalence among symptomatic women.
- Lower estimated likelihood: less than 20%.
- Intermediate estimated likelihood: 20% to less than 80%.
- Higher estimated likelihood: 80% or greater.
- Threshold status: provisional engineering bands, not treatment thresholds.
- Systemic warnings: handled separately and always raise clinical-review
  priority; they do not enter the lower-UTI probability calculation.

## Mutually Exclusive Evidence Groups

Only one factor from each group is applied. This prevents the app from
multiplying correlated findings within the same group.

### Group 1: Dipstick Pattern

The first matching row is used.

| Priority | Observed pattern | LR | Evidence basis |
| ---: | --- | ---: | --- |
| 1 | Nitrite positive and either leukocyte esterase or blood positive | 7.2 | Little et al.: nitrite plus either blood or leukocyte esterase |
| 2 | Nitrite positive without either additional positive finding | 5.5 | Kurotschka et al. 2024, Table 4 |
| 3 | Blood positive, with nitrite negative | 1.7 | Kurotschka et al. 2024, Table 4 |
| 4 | Leukocyte esterase positive, with nitrite and blood negative | 1.4 | Kurotschka et al. 2024, Table 4 |
| 5 | Nitrite, leukocyte esterase, and blood all negative | 0.22 | Little et al.: none of the three dipstick findings |
| - | One or more required results unavailable | No negative factor | Missing data are not interpreted as negative |

### Group 2: Localized Urinary Symptoms

Only the strongest first-matching supported factor is used. Absence of symptoms
does not apply an LR because the checklist does not yet distinguish a confirmed
negative response from an omitted answer.

| Priority | Reported finding | LR | Evidence basis |
| ---: | --- | ---: | --- |
| 1 | Visible hematuria | 2.0 | Bent et al. 2002 |
| 2 | Dysuria and urgency together | 1.5 | Kurotschka et al. 2024, Table 4 |
| 3 | Dysuria | 1.3 | Kurotschka et al. 2024, Table 4 |
| 4 | Urgency | 1.2 | Kurotschka et al. 2024, Table 4 |
| 5 | Frequency | 1.1 | Kurotschka et al. 2024, Table 4 |

Lower abdominal/suprapubic pain remains visible to the clinician but has no LR
in this version because no numerical value was frozen from the selected source
table.

### Group 3: Symptoms Suggesting Another Cause

Only the stronger first-matching negative predictor is used.

| Priority | Reported finding | LR | Evidence basis |
| ---: | --- | ---: | --- |
| 1 | Vaginal irritation | 0.2 | Bent et al. 2002 |
| 2 | Vaginal discharge | 0.3 | Bent et al. 2002 |

## Bayesian Calculation

```text
prior odds = 0.50 / (1 - 0.50) = 1.0
posterior odds = prior odds * dipstick-group LR * symptom-group LR * alternate-cause-group LR
posterior probability = posterior odds / (1 + posterior odds)
```

Groups without an applicable or available factor contribute no multiplier
(equivalent to LR 1.0). The app displays the factors actually applied, stores
the model version and posterior estimate with new scan-history records, and
keeps systemic warning outputs separate.

## Separate Systemic Warning Pathway

Fever/chills, flank/back pain, and nausea/vomiting trigger high-priority
clinical review for possible upper UTI, pyelonephritis, or complicated
infection. They do not increase the lower uncomplicated UTI posterior.

## Required Validation Before Clinical Claims

1. A physician must approve the population, variables, LR sources, grouping,
   wording, exclusions, and action recommendations.
2. A prospective or retrospective cohort must include the same symptom fields,
   app scan results, and an independent urine-culture reference standard.
3. Report discrimination and calibration: sensitivity, specificity, predictive
   values, ROC AUC, Brier score, calibration intercept/slope, and a calibration
   plot with confidence intervals.
4. Re-estimate or recalibrate the prior for the actual RHU population.
5. Choose clinical action thresholds using harms, benefits, referral capacity,
   and physician approval; do not adopt the provisional 20%/80% display bands
   as treatment thresholds without validation.
6. Freeze a new production version after approval and validation. Preserve this
   candidate version for reproducibility.

## Physician Approval Table

| Question | Physician response/sign-off |
| --- | --- |
| Is the target population restricted to nonpregnant adult women with urinary symptoms? |  |
| Is culture-confirmed acute uncomplicated lower UTI the target outcome? |  |
| Is the 50% development prior acceptable pending local recalibration? |  |
| Are the grouped LR values and correlation safeguards acceptable? |  |
| Should any absent symptom receive an LR-, and how will confirmed absence be recorded? |  |
| Are the exclusion criteria complete? |  |
| Are systemic warning triggers and wording appropriate? |  |
| What locally validated thresholds should trigger reassurance, culture, referral, or treatment review? |  |
| Is the patient-facing disclaimer acceptable? |  |
| Physician name, license, signature, and date |  |

## Sources

- Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults:
  Rapid Evidence Review. American Family Physician. 2024;109(2):167-174.
  https://www.aafp.org/pubs/afp/issues/2024/0200/acute-uncomplicated-utis-adults.html
- Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does This Woman Have an
  Acute Uncomplicated Urinary Tract Infection? JAMA. 2002;287(20):2701-2710.
  https://pubmed.ncbi.nlm.nih.gov/12020306/
- Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict
  urinary tract infection in primary care settings. Br J Gen Pract.
  2006;56(529):606-612.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC1874525/
- Giesen LGM, Cousins G, Dimitrov BD, van de Laar FA, Fahey T. Predicting acute
  uncomplicated urinary tract infection in women: a systematic review.
  BMC Fam Pract. 2010;11:78.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC2987910/
