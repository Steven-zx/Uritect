# Uritect Bayesian UTI Screening Physician Review Packet

## Document Control

| Field | Value |
| --- | --- |
| System | Uritect offline Android urine dipstick application |
| Bayesian model version | `uti_bayesian_lr_candidate_v1_20260917` |
| Review purpose | Clinical-content review before thesis use |
| Target condition | Acute uncomplicated lower urinary tract infection |
| Intended population | Nonpregnant adult women younger than 65 years presenting with acute urinary symptoms |
| Fixed development prior | 50% |
| Reference basis | Published diagnostic evidence listed below |
| Current status | Literature-derived research candidate; not locally calibrated or culture-validated |

Physician review may establish that the variables, evidence sources, warnings,
wording, and proposed workflow are clinically acceptable. It does not establish
that the displayed probability is locally calibrated or diagnostically
validated.

## Part A: User Eligibility and Safety Checklist

The health worker must ask every question. Do not leave an item blank. Use the
Bayesian percentage only when all eligibility items are satisfied and no
systemic warning is present.

=[]
| No. | Question | Yes | No |
| ---: | --- | :---: | :---: |
| 1 | Is the patient an adult aged 18 to 64 years? | [ ] | [ ] |
| 2 | Is the patient within the intended adult-woman population for this evidence model? | [ ] | [ ] |
| 3 | Is the patient currently experiencing at least one acute urinary symptom? | [ ] | [ ] |
| 4 | Has the patient confirmed that she is not pregnant? | [ ] | [ ] |
| 5 | Is the patient currently without an indwelling urinary catheter and without catheter use during the previous two weeks? | [ ] | [ ] |
| 6 | Is there no known relevant structural or functional urinary-tract abnormality? | [ ] | [ ] |
| 7 | Is there no known immunocompromising condition or treatment? | [ ] | [ ] |

Eligibility decision:

- [ ] Eligible for the literature-derived uncomplicated-UTI Bayesian estimate.
- [ ] Not eligible. Display the ten-analyte strip results, but do not interpret
  the Bayesian percentage as applicable; obtain clinical review.

### A2. Localized Urinary Symptoms

| Symptom | Present | Absent |
| --- | :---: | :---: |
| Burning or pain during urination (dysuria) | [ ] | [ ] |
| Urinating more often than usual (frequency) | [ ] | [ ] |
| Sudden or difficult-to-defer need to urinate (urgency) | [ ] | [ ] |
| Visible blood in urine (visible hematuria) | [ ] | [ ] |
| Lower abdominal or suprapubic pain | [ ] | [ ] |

Implementation note: only present findings are numerically weighted in the
current symptom group. Suprapubic pain is displayed but has no frozen LR.

### A3. Symptoms Suggesting Another Cause

| Symptom | Present | Absent |
| --- | :---: | :---: |
| Vaginal discharge | [ ] | [ ] |
| Vaginal irritation | [ ] | [ ] |

These findings lower the likelihood of uncomplicated UTI and may indicate an
alternate diagnosis requiring clinical assessment.

### A4. Systemic Warning Symptoms

| Warning symptom | Present | Absent |
| --- | :---: | :---: |
| Fever or chills | [ ] | [ ] |
| Back or flank pain | [ ] | [ ] |
| Nausea or vomiting | [ ] | [ ] |

If any systemic warning is present:

- assign High clinical-review priority;
- consider possible upper UTI, pyelonephritis, or complicated infection;
- do not use the uncomplicated lower-UTI percentage as a referral or treatment
  decision; and
- follow the reviewing physician's approved referral protocol.

### A5. Dipstick Results Supplied by Uritect

| Analyte | Negative | Positive/abnormal | Unavailable/uncertain |
| --- | :---: | :---: | :---: |
| Nitrite | [ ] | [ ] | [ ] |
| Leukocyte esterase | [ ] | [ ] | [ ] |
| Blood | [ ] | [ ] | [ ] |

Unavailable or uncertain results are never treated as negative. The remaining
seven semiquantitative analytes stay visible in the result table but do not
enter this UTI probability calculation.

## Part B: Complete Evidence Table

### B1. Published Individual Findings

This table gives the published LR+ and LR- values considered during model
design. "Not assigned" means that the selected source did not provide a value
frozen for this implementation.

| Finding | Positive/present condition | LR+ or presence LR | Negative/absent condition | LR- | Primary source used |
| --- | --- | ---: | --- | ---: | --- |
| Nitrite dipstick | Positive | 5.50 | Negative | 0.56 | Kurotschka et al. 2024, Table 4 |
| Leukocyte esterase | Positive | 1.40 | Negative | 0.40 | Kurotschka et al. 2024, Table 4 |
| Dipstick blood | Positive | 1.70 | Negative | 0.89 | Kurotschka et al. 2024, Table 4 |
| Dysuria | Present | 1.30 | Absent | 0.67 | Kurotschka et al. 2024, Table 4 |
| Urgency | Present | 1.20 | Absent | 0.75 | Kurotschka et al. 2024, Table 4 |
| Frequency | Present | 1.10 | Absent | 0.71 | Kurotschka et al. 2024, Table 4 |
| Urgency with dysuria | Both present | 1.50 | Combination absent | 0.44 | Kurotschka et al. 2024, Table 4 |
| Visible hematuria | Present | 2.00 | Absent | Not assigned | Bent et al. 2002 |
| Vaginal discharge | Present | 0.30 | Absent | Not assigned | Bent et al. 2002 |
| Vaginal irritation | Present | 0.20 | Absent | Not assigned | Bent et al. 2002 |

An LR below 1.0 lowers the posterior odds. Therefore, the presence LRs for
vaginal discharge and vaginal irritation act as negative evidence for acute
uncomplicated UTI.

### B2. Implemented Mutually Exclusive Groups

The app does not multiply every row in Part B1. Only one factor from each group
is applied to reduce double-counting of correlated findings.

#### Dipstick Group

Use the first matching row.

| Priority | Pattern | Implemented LR | Source |
| ---: | --- | ---: | --- |
| 1 | Nitrite positive and either leukocyte esterase or blood positive | 7.20 | Little et al. |
| 2 | Nitrite positive without either additional positive finding | 5.50 | Kurotschka et al. 2024 |
| 3 | Nitrite negative and blood positive | 1.70 | Kurotschka et al. 2024 |
| 4 | Nitrite and blood negative; leukocyte esterase positive | 1.40 | Kurotschka et al. 2024 |
| 5 | Nitrite, leukocyte esterase, and blood all negative | 0.22 | Little et al. |
| 6 | Any required result unavailable | 1.00/no update | Uritect missing-data rule |

#### Localized Urinary-Symptom Group

Use the first matching row. Confirmed absence is recorded but does not receive
an LR- in the current grouped implementation.

| Priority | Pattern | Implemented LR | Source |
| ---: | --- | ---: | --- |
| 1 | Visible hematuria present | 2.00 | Bent et al. 2002 |
| 2 | Dysuria and urgency both present | 1.50 | Kurotschka et al. 2024 |
| 3 | Dysuria present | 1.30 | Kurotschka et al. 2024 |
| 4 | Urgency present | 1.20 | Kurotschka et al. 2024 |
| 5 | Frequency present | 1.10 | Kurotschka et al. 2024 |
| 6 | None of the weighted symptoms present | 1.00/no update | Conservative implementation rule |

#### Alternate-Cause Group

Use the first matching row.

| Priority | Pattern | Implemented LR | Source |
| ---: | --- | ---: | --- |
| 1 | Vaginal irritation present | 0.20 | Bent et al. 2002 |
| 2 | Vaginal discharge present | 0.30 | Bent et al. 2002 |
| 3 | Neither present | 1.00/no update | Conservative implementation rule |

## Part C: Fixed Bayesian Equation

```text
prior probability = 0.50

prior odds = prior probability / (1 - prior probability)
           = 0.50 / 0.50
           = 1.00

posterior odds = prior odds
                 * selected dipstick-group LR
                 * selected urinary-symptom-group LR
                 * selected alternate-cause-group LR

posterior probability = posterior odds / (1 + posterior odds)
```

Example: nitrite and leukocyte esterase positive, with dysuria and urgency,
without vaginal discharge or irritation:

```text
posterior odds = 1.00 * 7.20 * 1.50 * 1.00 = 10.80
posterior probability = 10.80 / 11.80 = 0.9153 = 91.5%
```

## Part D: Proposed Display Bands

| Posterior result | Display | Intended meaning |
| ---: | --- | --- |
| Less than 20% | Lower estimated likelihood | UTI is less supported by the entered evidence; does not independently exclude UTI |
| 20% to less than 80% | Intermediate estimated likelihood | Clinical review and context are required |
| 80% or greater | Higher estimated likelihood | Evidence more strongly supports UTI; not a standalone diagnosis or antibiotic instruction |
| No usable weighted evidence | Insufficient evidence | Do not expose the 50% prior as an individual result |

The 20% and 80% boundaries are provisional display bands. They are not
published treatment thresholds and must be approved, revised, or rejected by
the reviewing physician.

## Part E: Physician Review Checklist

For every row, select Approve, Revise, or Reject and record comments where
needed.

| No. | Review item | Approve | Revise | Reject | Physician comments/replacement |
| ---: | --- | :---: | :---: | :---: | --- |
| 1 | Target condition: acute uncomplicated lower UTI | [ ] | [ ] | [ ] | |
| 2 | Intended population and age range | [ ] | [ ] | [ ] | |
| 3 | Pregnancy exclusion | [ ] | [ ] | [ ] | |
| 4 | Catheter, urinary-abnormality, and immunocompromise exclusions | [ ] | [ ] | [ ] | |
| 5 | Fixed literature-based prior of 50% | [ ] | [ ] | [ ] | |
| 6 | Nitrite LR+ 5.50 and LR- 0.56 | [ ] | [ ] | [ ] | |
| 7 | Leukocyte esterase LR+ 1.40 and LR- 0.40 | [ ] | [ ] | [ ] | |
| 8 | Dipstick blood LR+ 1.70 and LR- 0.89 | [ ] | [ ] | [ ] | |
| 9 | Combined positive dipstick LR 7.20 | [ ] | [ ] | [ ] | |
| 10 | All-three-negative dipstick LR 0.22 | [ ] | [ ] | [ ] | |
| 11 | Dysuria LR+ 1.30 and LR- 0.67 | [ ] | [ ] | [ ] | |
| 12 | Urgency LR+ 1.20 and LR- 0.75 | [ ] | [ ] | [ ] | |
| 13 | Frequency LR+ 1.10 and LR- 0.71 | [ ] | [ ] | [ ] | |
| 14 | Dysuria-with-urgency LR+ 1.50 and LR- 0.44 | [ ] | [ ] | [ ] | |
| 15 | Visible hematuria presence LR 2.00 | [ ] | [ ] | [ ] | |
| 16 | Vaginal discharge presence LR 0.30 | [ ] | [ ] | [ ] | |
| 17 | Vaginal irritation presence LR 0.20 | [ ] | [ ] | [ ] | |
| 18 | One-factor-per-group correlation safeguard | [ ] | [ ] | [ ] | |
| 19 | Do not apply individual symptom LR- values in this version | [ ] | [ ] | [ ] | |
| 20 | Missing or uncertain results receive no multiplier | [ ] | [ ] | [ ] | |
| 21 | Fever/chills systemic-warning pathway | [ ] | [ ] | [ ] | |
| 22 | Flank/back-pain systemic-warning pathway | [ ] | [ ] | [ ] | |
| 23 | Nausea/vomiting systemic-warning pathway | [ ] | [ ] | [ ] | |
| 24 | Systemic warnings excluded from lower-UTI posterior | [ ] | [ ] | [ ] | |
| 25 | Lower display band: below 20% | [ ] | [ ] | [ ] | |
| 26 | Intermediate display band: 20% to below 80% | [ ] | [ ] | [ ] | |
| 27 | Higher display band: 80% or greater | [ ] | [ ] | [ ] | |
| 28 | Patient/user checklist wording | [ ] | [ ] | [ ] | |
| 29 | Result wording and non-diagnostic disclaimer | [ ] | [ ] | [ ] | |
| 30 | Proposed referral/escalation instruction | [ ] | [ ] | [ ] | |

## Part F: Physician Decision and Attestation

Overall decision:

- [ ] Approved without changes for thesis research use as a screening-support
  candidate.
- [ ] Approved with the revisions written in this packet.
- [ ] Not approved; revision and repeat review required.

Suggested limitations statement for approval:

> I have reviewed the intended population, evidence variables, published
> likelihood ratios, fixed 50% literature-based prior, grouped calculation,
> warning pathway, output wording, and exclusions. My review concerns clinical
> reasonableness for thesis research and screening support. It does not certify
> Uritect as a diagnostic device and does not establish local calibration or
> diagnostic accuracy of its posterior percentages.

| Attestation field | Entry |
| --- | --- |
| Physician full name | |
| Specialty/role | |
| Professional license number | |
| Institution/clinic | |
| Signature | |
| Date | |
| Contact information, if institutionally permitted | |

## References

1. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults:
   Rapid Evidence Review. American Family Physician. 2024;109(2):167-174.
   https://www.aafp.org/pubs/afp/issues/2024/0200/acute-uncomplicated-utis-adults.html
2. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does This Woman Have an
   Acute Uncomplicated Urinary Tract Infection? JAMA. 2002;287(20):2701-2710.
   https://pubmed.ncbi.nlm.nih.gov/12020306/
3. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict
   urinary tract infection in primary care settings. Br J Gen Pract.
   2006;56(529):606-612.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC1874525/
4. Giesen LGM, Cousins G, Dimitrov BD, van de Laar FA, Fahey T. Predicting acute
   uncomplicated urinary tract infection in women: a systematic review.
   BMC Fam Pract. 2010;11:78.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC2987910/
