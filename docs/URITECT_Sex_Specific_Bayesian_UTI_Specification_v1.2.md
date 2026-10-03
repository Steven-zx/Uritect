# URITECT Sex-Specific Bayesian UTI Research Specification v1.2

**Female model:** `uti_bayesian_female_v1_1_20260926`  
**Male candidate model:** `uti_bayesian_male_v0_1_20261001`  
**Status:** Implemented research models; literature-derived and not locally calibrated  
**Reference standard in principal studies:** Urine culture / microbiologically confirmed UTI

## 1. Intended Use

URITECT provides offline ten-analyte strip classification, safety assessment,
renal follow-up, and a sex-specific Bayesian UTI research estimate for eligible
symptomatic adults aged 18-64. Neither estimate diagnoses UTI, recommends
antibiotics, replaces urine culture, or represents a locally calibrated
probability.

Female and male calculations are separate. Female values are never applied to
male users. The male model uses only nitrite and leukocyte esterase because no
adequate male-specific blood LR was identified.

## 2. Eligibility

Both models require confirmed age 18-64, no urinary catheter, no known urinary
tract abnormality, no immunocompromise, at least one qualifying acute urinary
symptom, and no systemic finding that moves the user to the safety pathway.

Female calculations additionally require confirmed nonpregnancy. Dysuria,
frequency, urgency, suprapubic pain, or visible hematuria can satisfy the
female symptom gate. Vaginal discharge or irritation stops the calculation and
activates alternate-cause consultation guidance.

Male calculations additionally require no diabetes and no suspected sexually
transmitted infection, matching the principal male study exclusions. Dysuria,
frequency, or urgency must be present. The study included men aged 18 years and
older; use in URITECT's narrower 18-64 population remains a transportability
limitation.

## 3. Female Model

The female v1.1 model is unchanged. It uses a provisional prior of 0.50, one
mutually exclusive dipstick LR, and one mutually exclusive symptom LR.

| Female dipstick pattern | LR |
| --- | ---: |
| Nitrite positive plus source-threshold leukocytes or blood | 7.20 |
| Nitrite positive without the stronger grouped pattern | 5.50 |
| Blood positive when nitrite is not positive | 1.70 |
| Leukocytes positive when nitrite and blood are not positive | 1.40 |
| Nitrite, leukocytes, and blood all confirmed negative | 0.22 |

| Female symptom pattern | LR |
| --- | ---: |
| Dysuria and urgency | 1.50 |
| Dysuria | 1.30 |
| Urgency | 1.20 |
| Frequency | 1.10 |

See `URITECT_Bayesian_UTI_Scoring_System_v1.1.md` for the complete female
threshold mapping, evidence, and limitations.

## 4. Male Evidence and Prior Derivation

Den Heijer et al. enrolled 603 symptomatic men from Dutch general practices.
Complete data were available for 490; 321 had microbiologically confirmed UTI
at at least 10^3 CFU/mL. The median age was 65 years (range 18-97). The study
excluded relevant urological or nephrological comorbidity other than benign
prostatic hypertrophy, diabetes, immunocompromising disease, catheterization,
and suspected sexually transmitted infection.

The full cohort prevalence was 321/490 = 65.5%, but URITECT does not use that
as its prior because the cohort was older than the app population. Table 3
reported 224 culture-positive and 80 culture-negative participants in its
older-age category. Therefore, in the complementary younger subgroup:

```text
culture positive = 321 - 224 = 97
culture negative = 169 - 80 = 89
candidate prior = 97 / (97 + 89) = 0.521505... (52.2%)
candidate prior odds = 97 / 89 = 1.089888...
```

This is a transparent subgroup derivation, not a published Filipino prevalence
estimate. The article describes the age boundary as both `>=60` in narrative
text and `>60` in a table, so URITECT does not claim an exact birthday boundary
for this derived subgroup. It does not exactly represent the app's 18-64
population and is frozen only as a provisional research prior pending local
culture-confirmed calibration.

The dipstick LRs below were estimated in the broader complete-data cohort,
not specifically in this derived younger subgroup. Combining this subgroup prior
with broader-cohort LRs assumes transportability across age and setting; this
requires statistical review in addition to prior calibration.

## 5. Male Ordered-Threshold Model

Den Heijer et al. assigned one point to positive leukocyte esterase and two
points to positive nitrite. Table 2 reported the following thresholds:

| Published threshold | LR+ | LR- | 95% CI for LR+ / LR- |
| --- | ---: | ---: | --- |
| Score at least 1: LE or nitrite positive | 1.65 | 0.35 | 1.41-1.94 / 0.28-0.45 |
| Score at least 2: nitrite positive | 4.87 | 0.48 | 3.19-7.43 / 0.42-0.55 |
| Score 3: nitrite and LE positive | 5.14 | 0.54 | 3.24-8.17 / 0.48-0.60 |

URITECT applies the first matching row below and never multiplies these
correlated thresholds:

| Male rule | Pattern | Candidate LR |
| --- | --- | ---: |
| M1 | Nitrite positive and LE positive | 5.14 |
| M2 | Nitrite-positive threshold met without M1 | 4.87 |
| M3 | LE-positive threshold met without M1 or M2 | 1.65 |
| M4 | Nitrite and LE both confirmed negative | 0.35 |
| M5 | Missing, unreliable, or unmatched | 1.00; no calculation |

M2 and M3 use an ordered-threshold approximation: the publication reports
threshold LRs, not mutually exclusive exact-pattern LRs. Applying them only
after excluding stronger branches changes their original conditioning. Selecting
one LR prevents duplicate multiplication but does not validate that conditioning
change. This is an explicit
URITECT design assumption requiring statistical review and prospective
validation. It is not hidden as a published clinical rule.

The male study treated any LE color change as positive. URITECT therefore maps
`Trace 15`, `Small 70`, `Moderate 125`, and `Large 500` to male LE-positive.
Nitrite requires `Positive`. Blood is not numerically weighted in the male UTI
model.

## 6. Equation

```text
prior odds = prior probability / (1 - prior probability)
posterior odds = prior odds x the one selected LR
posterior probability = posterior odds / (1 + posterior odds)
```

Female calculations multiply at most one dipstick LR and at most one symptom LR.
This cross-group multiplication assumes a statistical relationship that has not
been established; within-group selection does not prove conditional independence
between dipstick and symptoms. It remains a URITECT design assumption pending
statistical review. Male
calculations use one ordered dipstick-threshold LR only.

## 7. Safety and Display Rules

- Fever/chills, flank pain, significant nausea/vomiting, inability to maintain
  hydration or medication, severe weakness, confusion, or fainting remain
  outside the ordinary posterior and enter the safety pathway.
- Visible hematuria is consultation context and is not numerically weighted.
- No Low/Moderate/High probability bands or treatment thresholds are used.
- The app displays the sex-specific model version, starting prior, selected LR,
  and provisional posterior with a screening-only warning.
- Local records store calculation status, prior, posterior, factors, and model
  version.

## 8. Validation Boundary

The calculations are mathematically reproducible, but neither complete model
is clinically calibrated for the local population. Expert content review can
assess relevance and implementation clarity. Clinical validity requires
physician and statistical review plus prospective culture-confirmed
patient-level validation, including calibration, discrimination, confidence
intervals, and subgroup performance.

## 9. References

1. den Heijer CDJ, van Dongen MCJM, Donker GA, Stobberingh EE. Diagnostic
   approach to urinary tract infections in male general practice patients: a
   national surveillance study. *Br J Gen Pract*. 2012;62:e780-e786.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC3481519/
2. Koeijers JJ, Kessels AGH, Nys S, et al. Evaluation of the nitrite and
   leukocyte esterase activity tests for the diagnosis of acute symptomatic
   urinary tract infection in men. *Clin Infect Dis*. 2007;45:894-896.
   https://pubmed.ncbi.nlm.nih.gov/17806056/
3. Kurotschka PK, Gagyor I, Ebell MH. Acute Uncomplicated UTIs in Adults:
   Rapid Evidence Review. *Am Fam Physician*. 2024;109:167-174.
4. Little P, Turner S, Rumsby K, et al. Developing clinical rules to predict
   urinary tract infection in primary care settings. *Br J Gen Pract*.
   2006;56:606-612.
5. Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does this woman have an
   acute uncomplicated urinary tract infection? *JAMA*. 2002;287:2701-2710.

## Implementation audit addendum — 2026-10-03

See URITECT_UTI_Eligibility_Authority.md for the shared eligibility contract and
URITECT_Methodology_Implementation_Audit_2026-10-03.md for pending review gates.
Invalid/low-confidence/technically unreliable scans do not produce a posterior,
even from symptoms alone; symptom-based safety guidance remains available.
Serious systemic findings and existing renal PROMPT_CONSULT safety rules stop
the ordinary UTI estimate; renal findings are never numerical Bayesian factors.
Parameter values remain unchanged. These source changes are not yet in the
installed 1.4.0+6 retake-only pilot APK.

Parameter form IDs M01–M05 are not branch IDs M1–M5. Form M01 is the prior;
M02/M03/M04/M05 correspond to specification M1/M2/M3/M4 respectively.
Specification M5 is no calculation and has no parameter-form LR entry.
