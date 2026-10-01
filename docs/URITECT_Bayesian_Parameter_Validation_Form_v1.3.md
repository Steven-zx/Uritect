# URITECT Sex-Specific Bayesian UTI Parameter Review Form v1.3

**Female model:** `uti_bayesian_female_v1_1_20260926`  
**Male candidate:** `uti_bayesian_male_v0_1_20261001`  
**Purpose:** Expert content review, not clinical validation

## Reviewer Brief

URITECT is an offline smartphone urinalysis screening and decision-support
application. It uses separate literature-derived female and male research
models. Please review whether the proposed laboratory mappings, evidence
parameters, and limitations are relevant and clearly implemented.

The output is not a diagnosis, treatment recommendation, or replacement for
urine culture or professional judgment. Further clinical and statistical
validation is required before the percentages can be interpreted as
clinically validated estimates.

## Female Parameters

| ID | Finding or pattern | Candidate value | Source |
| --- | --- | ---: | --- |
| F01 | Starting prior in eligible symptomatic women | 50% | Bent 2002; Kurotschka 2024 |
| F02 | Nitrite positive | LR 5.50 | Kurotschka 2024 |
| F03 | Leukocyte esterase positive | LR 1.40 | Kurotschka 2024 |
| F04 | Dipstick blood positive | LR 1.70 | Kurotschka 2024 |
| F05 | Nitrite plus leukocytes or blood | LR 7.20 | Little 2006 |
| F06 | Nitrite, leukocytes, and blood all negative | LR 0.22 | Little 2006 |
| F07 | Dysuria and urgency | LR 1.50 | Kurotschka 2024 |
| F08 | Dysuria | LR 1.30 | Kurotschka 2024 |
| F09 | Urgency | LR 1.20 | Kurotschka 2024 |
| F10 | Frequency | LR 1.10 | Kurotschka 2024 |

## Male Candidate Parameters

| ID | Finding or pattern | Candidate value | Source |
| --- | --- | ---: | --- |
| M01 | Younger male subgroup starting prior | 52.2% | Derived from den Heijer 2012 Table 3 |
| M02 | Nitrite and leukocyte esterase positive | LR 5.14 | den Heijer 2012 Table 2 |
| M03 | Nitrite-positive threshold | LR 4.87 | den Heijer 2012 Table 2 |
| M04 | Leukocyte-est-positive threshold | LR 1.65 | den Heijer 2012 Table 2 |
| M05 | Nitrite and leukocyte esterase both negative | LR 0.35 | den Heijer 2012 Table 2 |

The male values are applied in an ordered hierarchy, with one LR only. The
source reports overlapping score thresholds rather than exact mutually
exclusive pattern LRs. M03 and M04 are therefore a documented URITECT research
approximation requiring statistical and culture-confirmed validation.

## Mapping and Use Statements

Rate each statement: `4 = highly relevant/acceptable`, `3 = minor revision`,
`2 = major revision`, `1 = not acceptable`.

| ID | Review statement | 1 | 2 | 3 | 4 | Comment |
| --- | --- | --- | --- | --- | --- | --- |
| C01 | Female nitrite, LE, and blood mappings match the stated source thresholds. | [ ] | [ ] | [ ] | [ ] | |
| C02 | Female Trace 15 LE is neutral because the female source threshold is `+` or greater. | [ ] | [ ] | [ ] | [ ] | |
| C03 | Male Trace 15 LE is positive because the male study counted any color change. | [ ] | [ ] | [ ] | [ ] | |
| C04 | Nitrite requires the strip category `Positive` in both models. | [ ] | [ ] | [ ] | [ ] | |
| C05 | Blood is appropriately omitted from the male numerical model. | [ ] | [ ] | [ ] | [ ] | |
| C06 | One mutually exclusive factor prevents duplicate multiplication of correlated dipstick evidence. | [ ] | [ ] | [ ] | [ ] | |
| C07 | Missing and unreliable results correctly receive no update. | [ ] | [ ] | [ ] | [ ] | |
| C08 | The female and male eligibility restrictions are understandable. | [ ] | [ ] | [ ] | [ ] | |
| C09 | Safety and alternate-cause findings are appropriately handled outside the equation. | [ ] | [ ] | [ ] | [ ] | |
| C10 | The lack of local calibration and culture-confirmed validation is stated clearly. | [ ] | [ ] | [ ] | [ ] | |

## Parameter Ratings

Please separately rate each parameter listed as F01-F10 and M01-M05.

| Parameter ID | 1 | 2 | 3 | 4 | Recommended revision or comment |
| --- | --- | --- | --- | --- | --- |
| F01 | [ ] | [ ] | [ ] | [ ] | |
| F02 | [ ] | [ ] | [ ] | [ ] | |
| F03 | [ ] | [ ] | [ ] | [ ] | |
| F04 | [ ] | [ ] | [ ] | [ ] | |
| F05 | [ ] | [ ] | [ ] | [ ] | |
| F06 | [ ] | [ ] | [ ] | [ ] | |
| F07 | [ ] | [ ] | [ ] | [ ] | |
| F08 | [ ] | [ ] | [ ] | [ ] | |
| F09 | [ ] | [ ] | [ ] | [ ] | |
| F10 | [ ] | [ ] | [ ] | [ ] | |
| M01 | [ ] | [ ] | [ ] | [ ] | |
| M02 | [ ] | [ ] | [ ] | [ ] | |
| M03 | [ ] | [ ] | [ ] | [ ] | |
| M04 | [ ] | [ ] | [ ] | [ ] | |
| M05 | [ ] | [ ] | [ ] | [ ] | |

## Overall Decision

[ ] Acceptable as provisional literature-derived research parameters  
[ ] Acceptable with minor revisions  
[ ] Major revision required before research use  
[ ] Unable to assess

Comments:  
________________________________________________________________________  
________________________________________________________________________  
________________________________________________________________________

## Acknowledgment

I reviewed the proposed literature-derived parameters, strip mappings, and
screening logic for their stated research purpose. I understand that this
expert content review does not independently establish diagnostic accuracy,
clinical calibration, sensitivity, specificity, or clinical validity of the
complete URITECT models.

Reviewer name: _________________________________________________  
Professional position: _________________________________________  
PRC license number: ____________________________________________  
Institution: ___________________________________________________  
Signature: ______________________________ Date: _________________

## References

1. den Heijer CDJ, et al. *Br J Gen Pract*. 2012;62:e780-e786.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC3481519/
2. Koeijers JJ, et al. *Clin Infect Dis*. 2007;45:894-896.
   https://pubmed.ncbi.nlm.nih.gov/17806056/
3. Kurotschka PK, et al. *Am Fam Physician*. 2024;109:167-174.
4. Little P, et al. *Br J Gen Pract*. 2006;56:606-612.
5. Bent S, et al. *JAMA*. 2002;287:2701-2710.

