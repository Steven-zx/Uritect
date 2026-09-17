# Bayesian UTI Candidate Table

This document summarizes the app's current UTI-only interpretation.
The app no longer claims renal, metabolic, or hepatic risk stratification. The
ten-analyte scan table is still displayed, but clinical interpretation is limited
to UTI screening support and systemic warning flags.

The app calculates a candidate Bayesian estimate but does not diagnose. The
frozen numerical specification and physician sign-off table are in
`docs/uti_screening_weight_table_for_physician_review.md`.

## Inputs

Dipstick inputs used by the rule engine:

- Leukocyte esterase
- Nitrite
- Blood

Checklist inputs used by the rule engine:

- Dysuria
- Frequency
- Urgency
- Visible hematuria
- Lower abdominal pain
- Vaginal discharge
- Vaginal irritation
- Fever/chills
- Back/flank pain
- Nausea/vomiting

## Output Rules

| Output category | Trigger | Severity | Message intent |
| --- | --- | --- | --- |
| Bayesian UTI estimate | At least one supported dipstick-pattern, urinary-symptom, or alternate-cause factor is available | Lower, intermediate, or higher estimated likelihood | Display the posterior and factors as an unvalidated research estimate |
| Alternate-cause symptoms | Vaginal discharge or vaginal irritation is selected | Caution | Flag symptoms that can lower the likelihood of uncomplicated UTI or suggest another cause |
| Systemic warning symptoms | Fever/chills, back/flank pain, or nausea/vomiting is selected | High | Flag symptoms that need clinical review for possible upper UTI, pyelonephritis, or complicated infection |

## Review Priority

The top-level review priority is selected from the most serious active category:

| Active category severity | Review priority |
| --- | --- |
| Any high category | High |
| Otherwise any moderate category | Moderate |
| Otherwise any caution category | Caution |
| Otherwise | Low |

## Conflict Flag

If UTI-related dipstick evidence is present but no symptom is selected, the app
shows a conflict message recommending repeat scanning or professional review.

## Excluded Methods

The app no longer contains or uses:

- Binary normal/abnormal classifiers
- Renal or metabolic risk scores
- A single merged disease-risk score

The provisional Bayesian display bands are not treatment thresholds. Systemic
warning symptoms remain outside the lower-UTI posterior and can independently
set the review priority to High.
