# URITECT Bayesian UTI Literature-Derived Parameter Review Form v1.2

**Model reviewed:** `uti_bayesian_lr_v1_1_20260926`  
**Reviewers for this form:** Two registered medical technologists  
**Separate final-app validation:** Ten registered medical technologists  
**Purpose:** Expert content review of proposed literature-derived parameters and their implementation

## 1. Purpose of This Review

URITECT uses urine-strip findings and selected urinary symptoms to produce a
provisional research estimate for uncomplicated lower urinary tract infection
(UTI). This form asks you to review two separate matters:

- Whether each proposed literature-derived value is relevant and acceptable as a **candidate parameter** for the research model.
- Whether URITECT's rules for applying those values are understandable and appropriate for the stated research purpose.

This is an expert content review. It does not prove that the final percentage
is clinically accurate, locally calibrated, or diagnostic. It does not ask the
reviewer to recommend antibiotics or treatment.

## 2. Short Explanation of the Terms

| Term | Plain-language meaning |
| --- | --- |
| Likelihood ratio (LR) | A number used to adjust how strongly the available evidence supports UTI. |
| LR greater than 1 | The finding increases support for UTI. |
| LR less than 1 | The finding decreases support for UTI. |
| Prior probability | The starting assumption before the current strip and symptom findings are applied. |
| Literature-derived candidate | A value taken from published evidence and proposed for research use; it is not yet locally calibrated. |
| No update / neutral | The finding does not change the calculation; mathematically, LR = 1.00. |

## 3. Intended Use and Limits

The calculation is limited to symptomatic, nonpregnant women aged 18 to 64
without a urinary catheter, known urinary tract abnormality,
immunocompromise, or systemic warning findings. Vaginal discharge or
irritation activates a separate consultation pathway instead of the ordinary
calculation.

For an eligible calculation, the app shows the provisional percentage, prior,
and applied evidence factors. It does not present the number as a diagnosis or
as a Low, Moderate, or High UTI category. Culture-confirmed patient-level
validation is required before any claim of clinical calibration.

## 4. How to Rate Each Statement

Please place one check mark in each row.

| Rating | Meaning |
| --- | --- |
| 4 | Highly relevant and acceptable as written |
| 3 | Relevant, but a minor revision is suggested |
| 2 | Major revision is needed |
| 1 | Not relevant or not acceptable for the stated research purpose |

Use the comment column whenever you select 1, 2, or 3, or when a threshold,
source, or wording should be changed.

## 5. Evidence Summary

| Finding or starting assumption | Candidate value | Main source used by URITECT | How URITECT uses it |
| --- | ---: | --- | --- |
| Nitrite positive | LR 5.50 | Kurotschka et al. (2024), Table 4 | Used when nitrite is positive without the stronger grouped pattern |
| Leukocyte esterase positive | LR 1.40 | Kurotschka et al. (2024), Table 4 | Used when source-threshold leukocytes are the strongest dipstick evidence |
| Dipstick blood positive | LR 1.70 | Kurotschka et al. (2024), Table 4 | Used when source-threshold blood is the strongest dipstick evidence |
| Nitrite positive plus leukocytes or blood positive | LR 7.20 | Little et al. (2006) | Used once as a grouped dipstick pattern |
| Nitrite, leukocytes, and blood all confirmed negative | LR 0.22 | Little et al. (2006) | Used once as the grouped negative pattern |
| Dysuria present | LR 1.30 | Kurotschka et al. (2024), Table 4 | Used when it is the strongest matching symptom rule |
| Urgency present | LR 1.20 | Kurotschka et al. (2024), Table 4 | Used when no stronger symptom rule matches |
| Frequency present | LR 1.10 | Kurotschka et al. (2024), Table 4 | Used when no stronger symptom rule matches |
| Dysuria and urgency both present | LR 1.50 | Kurotschka et al. (2024), Table 4 | Used once instead of multiplying the individual symptom LRs |
| Starting prior for the narrowly gated population | 50% | Bent et al. (2002); Kurotschka et al. (2024) | Provisional starting assumption; not locally calibrated |

Little et al. studied 427 women with suspected UTI and used laboratory
diagnosis based on European urinalysis guidance. Its dipstick definitions
included leukocyte esterase at `+` or greater and blood at haemolysed trace or
greater. The 50% starting value is limited to a study-like population of
symptomatic women; it is not a general-population prevalence.

## 6. Part A - Evidence and Parameter Review

Please rate whether each value is relevant and acceptable **as a
literature-derived candidate parameter** in the stated URITECT research model.

| ID | Statement | 1 | 2 | 3 | 4 | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | LR 5.50 for a positive nitrite result | [ ] | [ ] | [ ] | [ ] | |
| P2 | LR 1.40 for a positive leukocyte esterase result | [ ] | [ ] | [ ] | [ ] | |
| P3 | LR 1.70 for a positive dipstick blood result | [ ] | [ ] | [ ] | [ ] | |
| P4 | LR 7.20 for nitrite positive plus leukocytes or blood positive | [ ] | [ ] | [ ] | [ ] | |
| P5 | LR 0.22 when nitrite, leukocytes, and blood are all confirmed negative | [ ] | [ ] | [ ] | [ ] | |
| P6 | LR 1.30 when dysuria is present | [ ] | [ ] | [ ] | [ ] | |
| P7 | LR 1.20 when urgency is present | [ ] | [ ] | [ ] | [ ] | |
| P8 | LR 1.10 when urinary frequency is present | [ ] | [ ] | [ ] | [ ] | |
| P9 | LR 1.50 when dysuria and urgency are both present | [ ] | [ ] | [ ] | [ ] | |
| P10 | A provisional 50% prior is adequately explained and restricted to the intended study-like population | [ ] | [ ] | [ ] | [ ] | |

### Part A Comments

Parameters that should be retained without revision:  
________________________________________________________________________  
________________________________________________________________________

Parameters that require revision, with the recommended change and reason:  
________________________________________________________________________  
________________________________________________________________________  
________________________________________________________________________

## 7. How URITECT Applies the Values

URITECT does not multiply every available number. It selects only one
dipstick-pattern LR and one urinary-symptom LR. This is intended to reduce
double-counting among related findings.

### Dipstick Rules

| Order | First matching pattern | LR used |
| --- | --- | ---: |
| A1 | Nitrite positive plus source-threshold leukocytes or blood positive | 7.20 |
| A2 | Nitrite positive without that grouped pattern | 5.50 |
| A3 | Source-threshold blood positive | 1.70 |
| A4 | Source-threshold leukocytes positive | 1.40 |
| A5 | Nitrite, leukocytes, and blood all confirmed negative | 0.22 |
| A6 | No source-matched rule | 1.00; no update |

### Symptom Rules

| Order | First matching symptom pattern | LR used |
| --- | --- | ---: |
| B1 | Dysuria and urgency both present | 1.50 |
| B2 | Dysuria present | 1.30 |
| B3 | Urgency present | 1.20 |
| B4 | Frequency present | 1.10 |
| B5 | No weighted symptom is reported | 1.00; no update |

### Exact Category Mapping

| URITECT result | Treatment in this candidate model |
| --- | --- |
| Nitrite `Positive` | Positive |
| Leukocytes `Small 70`, `Moderate 125`, or `Large 500` | Positive; corresponds to `+` or greater |
| Leukocytes `Trace 15` | Neutral; no update |
| Blood `Hemolyzed 10`, `Small 25`, `Moderate 80`, or `Large 200` | Positive; haemolysed trace or greater |
| Blood `Non-hemolyzed 10` | Neutral; not used as the Little et al. blood threshold |
| Exact `Neg` or `Negative` | Confirmed negative |
| Missing, invalid, unavailable, or unreliable | Neutral; no update, not treated as negative |

Visible hematuria is recorded as consultation context and is not numerically
weighted when dipstick blood can contribute. Vaginal discharge or irritation
stops the ordinary calculation and routes to consultation.

## 8. Part B - Implementation and Content Review

| ID | Statement | 1 | 2 | 3 | 4 | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| I1 | Treating leukocyte `Trace 15` as neutral rather than positive is appropriate for the cited threshold | [ ] | [ ] | [ ] | [ ] | |
| I2 | Treating leukocytes `Small 70` or greater as positive is appropriate | [ ] | [ ] | [ ] | [ ] | |
| I3 | Treating `Hemolyzed 10` blood or greater as positive is appropriate for the cited threshold | [ ] | [ ] | [ ] | [ ] | |
| I4 | Treating `Non-hemolyzed 10` blood as neutral is appropriate for this evidence mapping | [ ] | [ ] | [ ] | [ ] | |
| I5 | Missing, invalid, unavailable, and unreliable results should receive no update and should not be treated as negative | [ ] | [ ] | [ ] | [ ] | |
| I6 | Using only one mutually exclusive dipstick LR is appropriate for reducing duplicate counting | [ ] | [ ] | [ ] | [ ] | |
| I7 | Using the combined dysuria-and-urgency LR instead of multiplying their individual LRs is appropriate | [ ] | [ ] | [ ] | [ ] | |
| I8 | Recording visible hematuria as consultation context without adding another numerical LR is appropriate | [ ] | [ ] | [ ] | [ ] | |
| I9 | Routing vaginal discharge or irritation to consultation instead of multiplying a numerical factor is appropriate | [ ] | [ ] | [ ] | [ ] | |
| I10 | The intended-population gate and the handling of unknown information are understandable and appropriate | [ ] | [ ] | [ ] | [ ] | |
| I11 | The model's non-diagnostic and non-calibrated limitations are stated clearly | [ ] | [ ] | [ ] | [ ] | |
| I12 | The proposed workflow is understandable and feasible for the stated offline screening research purpose | [ ] | [ ] | [ ] | [ ] | |

### Part B Comments

Rules or mappings that should be changed, with the recommended change:  
________________________________________________________________________  
________________________________________________________________________  
________________________________________________________________________

## 9. Overall Expert Decision

Please select one:

- [ ] Accept the proposed literature-derived parameters and implementation as written for the stated thesis research purpose.
- [ ] Accept after the minor revisions described in this form.
- [ ] Major revision and repeat expert review are required.
- [ ] Do not accept for the stated research purpose.

This decision concerns expert content review only. It does not certify clinical
diagnostic accuracy, probability calibration, or treatment suitability.

## 10. Reviewer Information and Declaration

| Reviewer detail | Entry |
| --- | --- |
| Reviewer code | [ ] MT-01    [ ] MT-02 |
| Reviewer name | ________________________________________________ |
| Professional title | ________________________________________________ |
| PRC registration/license number | ________________________________________________ |
| Years of professional practice | ________________________________________________ |
| Current institution | ________________________________________________ |

I confirm that I reviewed the proposed literature-derived parameters, cited
evidence summary, category mappings, and implementation rules. I understand
that this is content review of a thesis screening model and is not clinical
validation against urine culture.

| Confirmation | Entry |
| --- | --- |
| Signature | ________________________________________________ |
| Date | ________________________________________________ |

## 11. For the Researchers Only

Calculate and report the parameter-review and implementation-review results
separately. Do not combine this two-medtech parameter review with the planned
ten-medtech final-app usability, functionality, or ISO/IEC 25010 evaluation.

Recommended reporting language:

> The proposed literature-derived Bayesian parameters and their implementation
> underwent expert content review by two registered medical technologists.
> This review assessed relevance, clarity, and appropriateness for the stated
> research purpose; it did not establish clinical diagnostic accuracy or
> probability calibration.

### 12. References

1. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults: Rapid Evidence Review. *American Family Physician*. 2024;109(2):167-174. https://www.aafp.org/afp/2024/0200/acute-uncomplicated-utis-adults
2. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict urinary tract infection in primary care settings. *British Journal of General Practice*. 2006;56(529):606-612. https://pmc.ncbi.nlm.nih.gov/articles/PMC1874525/
3. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does this woman have an acute uncomplicated urinary tract infection? *JAMA*. 2002;287(20):2701-2710. https://pubmed.ncbi.nlm.nih.gov/12020306/
