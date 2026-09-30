# URITECT Bayesian UTI Scoring System v1.0

**Model version:** `uti_bayesian_lr_candidate_v1_20260917`  
**Method:** Grouped likelihood-ratio Bayesian screening estimate  
**Target:** Acute uncomplicated lower urinary tract infection (UTI)  
**Fixed starting probability (prior):** 50%  
**Review panel:** Ten registered medical technologists  
**Status:** Literature-derived candidate for content validation

> **In simple terms:** Uritect starts at 50%, then adjusts that estimate using
> the urine-strip pattern and reported symptoms. Evidence supporting UTI raises
> the estimate; evidence suggesting another cause lowers it.

## 1. Intended Use

This module estimates how strongly the available findings support **acute
uncomplicated lower UTI**. It is intended for nonpregnant adult women aged 18
to 64 years with acute urinary symptoms and without a catheter, known urinary
tract abnormality, immunocompromise, or systemic signs suggesting complicated
infection.

The result is screening support only. It is **not** a diagnosis, treatment or
antibiotic recommendation, locally calibrated probability, proof that UTI is
present or absent, or a substitute for professional assessment and urine
culture when indicated.

The ten-analyte k-NN image classifier and this Bayesian module must be evaluated
separately. An incorrect strip classification can affect the Bayesian result.

> **For reviewers:** Judge whether the inputs, evidence use, wording, and
> safeguards are appropriate. This review does not measure diagnostic
> sensitivity, specificity, or calibration against urine culture.

## 2. Terms Used in This Document

| Technical term | Simple explanation |
| --- | --- |
| Prior probability | Starting estimate before the current findings are considered. |
| Odds | A mathematical form of probability that allows evidence to be multiplied. |
| Likelihood ratio (LR) | A number showing how much a finding changes the odds of UTI. |
| LR greater than 1 | Raises the estimated likelihood of UTI. |
| LR less than 1 | Lowers the estimated likelihood of UTI. |
| LR equal to 1 | Makes no change. |
| Posterior probability | Final estimate after applying the selected evidence. |
| Correlated findings | Findings that overlap and should not all be counted independently. |
| Content validation | Expert review of relevance, clarity, and appropriateness; not a clinical accuracy study. |

## 3. Information Used by the App

### 3.1 Dipstick Findings

| Analyte | Negative | Positive |
| --- | --- | --- |
| Nitrite | `Neg` or `Negative` | Any validated non-negative category |
| Leukocyte esterase | `Neg` or `Negative` | Any validated non-negative category |
| Blood | `Neg` or `Negative` | Trace or any higher validated category |

If a result is missing, invalid, or below the app's confidence requirement, it
is **unavailable**, not negative.

### 3.2 Symptoms Used in the Estimate

- Dysuria or burning during urination
- Urinary urgency
- Urinary frequency
- Visible hematuria
- Vaginal discharge
- Vaginal irritation

Suprapubic or lower abdominal pain may be displayed as clinical context, but
it has no numerical LR in this version.

### 3.3 Systemic Warning Symptoms

- Fever or chills
- Back or flank pain
- Nausea or vomiting

These warnings are **not multiplied into the lower-UTI probability**. They
activate a separate high-priority clinical-review message because they may
indicate upper UTI, pyelonephritis, systemic illness, or complicated infection.

> **In simple terms:** The calculator estimates lower UTI. Warning symptoms
> follow a separate safety pathway and can override the ordinary screen message.

## 4. Published Evidence

These are the literature-derived LRs considered when the model was designed.
The evidence is divided into short tables so it remains readable on screen and
when printed.

### 4.1 Dipstick Findings

| Finding | LR positive | LR negative |
| --- | ---: | ---: |
| Nitrite | 5.50 | 0.56 |
| Leukocyte esterase | 1.40 | 0.40 |
| Dipstick blood | 1.70 | 0.89 |

**Source:** Kurotschka et al. (2024), Table 4.

### 4.2 Urinary Symptoms

| Finding | LR present | LR absent |
| --- | ---: | ---: |
| Dysuria | 1.30 | 0.67 |
| Urgency | 1.20 | 0.75 |
| Frequency | 1.10 | 0.71 |
| Dysuria and urgency together | 1.50 | 0.44 |
| Visible hematuria | 2.00 | Not assigned |

**Sources:** Kurotschka et al. (2024) for dysuria, urgency, frequency, and the
combined pattern; Bent et al. (2002) for visible hematuria.

### 4.3 Findings Suggesting Another Cause

| Finding when present | LR |
| --- | ---: |
| Vaginal discharge | 0.30 |
| Vaginal irritation | 0.20 |

**Source:** Bent et al. (2002).

These values are below 1, so their presence lowers the UTI estimate. Their
absence has no assigned LR in this model.

### 4.4 Combined Dipstick Patterns

| Pattern | LR |
| --- | ---: |
| Nitrite positive plus leukocytes or blood positive | 7.20 |
| Nitrite, leukocytes, and blood all negative | 0.22 |

**Source:** Little et al. (2006).

> **Important:** Section 4 is the evidence library. The app does not multiply
> every row. The exact rules used by the app are in Section 5.

## 5. Exact Scoring Rules Used by the App

The app uses three evidence groups. It selects **one factor only from each
group**, then multiplies the selected factors. This reduces double counting
among related strip findings and symptoms.

### 5.1 Group A: Dipstick Pattern

Start at A1 and stop at the first matching rule.

| Rule | Pattern | LR |
| --- | --- | ---: |
| A1 | Nitrite positive, plus leukocytes or blood positive | 7.20 |
| A2 | Nitrite positive, without either additional positive finding | 5.50 |
| A3 | Nitrite not positive; blood positive | 1.70 |
| A4 | Nitrite and blood not positive; leukocytes positive | 1.40 |
| A5 | Nitrite, leukocytes, and blood all confirmed negative | 0.22 |
| A6 | No positive rule matches and one or more results are unavailable | 1.00 |

**Plain explanation:** Only the strongest matching dipstick pattern is counted.
For A1, the app uses 7.20; it does not also multiply 5.50, 1.40, or 1.70.

### 5.2 Group B: Urinary Symptom Pattern

Start at B1 and stop at the first matching rule.

| Rule | Pattern | LR |
| --- | --- | ---: |
| B1 | Visible hematuria present | 2.00 |
| B2 | Dysuria and urgency both present | 1.50 |
| B3 | Dysuria present | 1.30 |
| B4 | Urgency present | 1.20 |
| B5 | Frequency present | 1.10 |
| B6 | No supported weighted symptom is present | 1.00 |

**Plain explanation:** Only one symptom factor is counted. An unchecked symptom
is not assumed to be a reliably confirmed negative, so individual symptom LR-
values are not used in this version.

### 5.3 Group C: Possible Alternate Cause

Start at C1 and stop at the first matching rule.

| Rule | Pattern | LR |
| --- | --- | ---: |
| C1 | Vaginal irritation present | 0.20 |
| C2 | Vaginal discharge present | 0.30 |
| C3 | Neither finding is present | 1.00 |

**Plain explanation:** These symptoms can suggest a cause other than UTI, so
they lower the estimate. If both are reported, 0.20 is used once.

## 6. Bayesian Equation

### Step 1: Convert Starting Probability to Odds

```text
prior probability = 0.50

prior odds = prior probability / (1 - prior probability)
           = 0.50 / 0.50
           = 1.00
```

### Step 2: Apply One LR From Each Group

```text
posterior odds = prior odds
                 x Group A dipstick LR
                 x Group B symptom LR
                 x Group C alternate-cause LR
```

### Step 3: Convert Final Odds Back to Probability

```text
posterior probability = posterior odds / (1 + posterior odds)
```

Because the prior odds are 1.00, the posterior odds equal the product of the
three selected group factors.

> **In simple terms:** Choose one number from A, one from B, and one from C.
> Multiply them. Divide the answer by one plus the answer.

## 7. Worked Examples

### Example 1: Stronger Support for UTI

**Findings:** Nitrite and leukocytes positive; dysuria and urgency present; no
vaginal discharge or irritation.

```text
Group A = 7.20
Group B = 1.50
Group C = 1.00

posterior odds = 1.00 x 7.20 x 1.50 x 1.00 = 10.80
posterior probability = 10.80 / (1 + 10.80) = 91.5%
```

### Example 2: Mixed Evidence

**Findings:** Nitrite positive; dysuria present; vaginal irritation present.

```text
Group A = 5.50
Group B = 1.30
Group C = 0.20

posterior odds = 1.00 x 5.50 x 1.30 x 0.20 = 1.43
posterior probability = 1.43 / (1 + 1.43) = 58.9%
```

### Example 3: Less Support for UTI

**Findings:** Nitrite, leukocytes, and blood all confirmed negative; no
weighted symptom or alternate-cause symptom recorded.

```text
Group A = 0.22
Group B = 1.00
Group C = 1.00

posterior odds = 1.00 x 0.22 x 1.00 x 1.00 = 0.22
posterior probability = 0.22 / (1 + 0.22) = 18.0%
```

### Example 4: Insufficient Evidence

If all three relevant dipstick results are unavailable and no supported
weighted symptom is recorded, the internal prior remains 50%. The app must not
present that starting value as a patient-specific result. It displays
**Insufficient evidence** instead.

## 8. Display Bands

| Result | App label | Plain meaning |
| --- | --- | --- |
| Below 20% | Lower | Less support for lower UTI, but UTI is not ruled out. |
| 20% to below 80% | Intermediate | Evidence is mixed; clinical review is needed. |
| 80% or above | Higher | Stronger support for lower UTI; this is not a diagnosis. |
| No usable evidence | Insufficient | No patient-specific estimate can be calculated. |

The 20% and 80% boundaries are **provisional display bands created for the
Uritect interface**. They are not published treatment or antibiotic thresholds.
Review them separately from the published LR values.

## 9. Reviewer Instructions

### 9.1 Reviewer Information

- Reviewer name or code: __________________________________________
- Professional license number, if permitted: ______________________
- Position and institution: ______________________________________
- Years of urinalysis experience: _________________________________
- Urine reagent-strip experience: _________________________________
- Laboratory quality-assurance experience: ________________________
- Date reviewed: _________________________________________________
- Version reviewed: `URITECT Bayesian UTI Scoring System v1.0`

### 9.2 Rating Scale

| Rating | Meaning |
| ---: | --- |
| 1 | Not relevant or acceptable; major revision required |
| 2 | Somewhat relevant; substantial revision required |
| 3 | Relevant and acceptable with minor revision |
| 4 | Highly relevant, clear, and acceptable as written |

Ratings of 3 or 4 count as expert agreement for the Content Validity Index
(CVI). Add a comment whenever the rating is 1 or 2.

## 10. Content Validation Checklist

Write one rating from 1 to 4 on each line.

### A. Scope and Intended Use

1. Target condition is clearly limited to acute uncomplicated lower UTI. **Rating:** ____
2. Intended population and exclusions are appropriate and clear. **Rating:** ____
3. Limitations clearly identify screening support, not diagnosis. **Rating:** ____

**Comments for Items 1-3:**

____________________________________________________________________________

____________________________________________________________________________

### B. Dipstick Evidence

4. Nitrite is an appropriate UTI-screening input. **Rating:** ____
5. Leukocyte esterase is an appropriate UTI-screening input. **Rating:** ____
6. Blood is appropriately supportive rather than diagnostic. **Rating:** ____
7. Missing, invalid, or low-confidence results are not treated as negative. **Rating:** ____
8. Individual dipstick LR values and cited basis are acceptable. **Rating:** ____
9. Combined-positive LR 7.20 is appropriate for Rule A1. **Rating:** ____
10. All-three-negative LR 0.22 is appropriate for Rule A5. **Rating:** ____

**Comments for Items 4-10:**

____________________________________________________________________________

____________________________________________________________________________

### C. Symptom Evidence

11. Selected urinary symptoms are relevant to lower-UTI screening. **Rating:** ____
12. Vaginal findings are appropriately treated as alternate-cause evidence. **Rating:** ____
13. Symptom LR values and cited basis are acceptable. **Rating:** ____
14. One factor per group appropriately reduces double counting. **Rating:** ____

**Comments for Items 11-14:**

____________________________________________________________________________

____________________________________________________________________________

### D. Mathematics and Output

15. The literature-based 50% prior is clearly explained. **Rating:** ____
16. The Bayesian equations are mathematically correct. **Rating:** ____
17. Worked examples are correct and reproducible. **Rating:** ____
18. Output labels are understandable. **Rating:** ____
19. The 20% and 80% bands are clearly identified as provisional. **Rating:** ____

**Comments for Items 15-19:**

____________________________________________________________________________

____________________________________________________________________________

### E. Safety and Overall Acceptability

20. Systemic warnings are appropriately separated from the estimate. **Rating:** ____
21. Wording avoids unsupported diagnosis and treatment claims. **Rating:** ____
22. Module is feasible for trained health workers in an RHU. **Rating:** ____
23. Limitations and safety messages are complete and understandable. **Rating:** ____
24. Specification is acceptable for thesis research use with stated limits. **Rating:** ____

**Comments for Items 20-24:**

____________________________________________________________________________

____________________________________________________________________________

### Overall Decision

- [ ] Accept without revision
- [ ] Accept after minor revision
- [ ] Major revision and repeat review required
- [ ] Reject for the stated intended use

Reviewer signature: ____________________________________  
Date: ____________________

## 11. Summarizing the Ten Reviews

For each item:

```text
I-CVI = number of reviewers giving rating 3 or 4 / 10
```

Example with 8 agreeing reviewers:

```text
I-CVI = 8 / 10 = 0.80
```

For the whole checklist:

```text
S-CVI/Ave = sum of the 24 item I-CVI values / 24
```

| Result | Planned action |
| --- | --- |
| I-CVI 0.80 or above | Retain; apply minor wording revision if needed |
| I-CVI 0.70 | Revise and return for expert review |
| I-CVI below 0.70 | Replace or remove unless a rationale supports repeat review |
| S-CVI/Ave 0.90 or above | Target for strong overall content agreement |

Reviewer comments must still be examined when the target is met. A safety
objection must not be dismissed by averaging scores.

### Results Worksheet

| Item | Reviewers rating 3 or 4 | I-CVI | Decision |
| ---: | ---: | ---: | --- |
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |
| 7 | | | |
| 8 | | | |
| 9 | | | |
| 10 | | | |
| 11 | | | |
| 12 | | | |
| 13 | | | |
| 14 | | | |
| 15 | | | |
| 16 | | | |
| 17 | | | |
| 18 | | | |
| 19 | | | |
| 20 | | | |
| 21 | | | |
| 22 | | | |
| 23 | | | |
| 24 | | | |

**S-CVI/Ave:** ____________________

> **Reporting limitation:** CVI shows expert agreement about content and
> presentation. It is not diagnostic sensitivity, specificity, predictive
> value, calibration, or validation against culture.

## 12. References

1. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults:
   Rapid Evidence Review. *American Family Physician*. 2024;109(2):167-174.
   <https://www.aafp.org/pubs/afp/issues/2024/0200/acute-uncomplicated-utis-adults.html>
2. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does This Woman Have an
   Acute Uncomplicated Urinary Tract Infection? *JAMA*. 2002;287(20):2701-2710.
   <https://pubmed.ncbi.nlm.nih.gov/12020306/>
3. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict
   urinary tract infection in primary care settings. *Br J Gen Pract*.
   2006;56(529):606-612. <https://pmc.ncbi.nlm.nih.gov/articles/PMC1874525/>
4. Giesen LGM, Cousins G, Dimitrov BD, van de Laar FA, Fahey T. Predicting acute
   uncomplicated urinary tract infection in women: a systematic review.
   *BMC Fam Pract*. 2010;11:78.
   <https://pmc.ncbi.nlm.nih.gov/articles/PMC2987910/>
5. Lynn MR. Determination and quantification of content validity. *Nurs Res*.
   1986;35(6):382-385. <https://pubmed.ncbi.nlm.nih.gov/3640358/>
6. Polit DF, Beck CT, Owen SV. Is the CVI an acceptable indicator of content
   validity? *Res Nurs Health*. 2007;30(4):459-467.
   <https://pubmed.ncbi.nlm.nih.gov/17654487/>
