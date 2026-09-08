# Final Clinical Rule Table

This table documents the app's current clinical interpretation rules after
removing Bayesian fusion, likelihood-ratio weights, unsupported priors, and
posterior thresholds. These rules are decision-support flags only. They do not
calculate disease probability and do not diagnose.

## Inputs

Dipstick inputs used by the rule engine:

- Leukocyte esterase
- Nitrite
- Protein
- Glucose

Checklist inputs used by the rule engine:

- Dysuria
- Frequency
- Urgency
- Visible hematuria
- Lower abdominal pain
- Fever/chills
- Back/flank pain
- Nausea/vomiting
- Peripheral edema

## Output Rules

| Output category | Trigger | Severity | Message intent |
| --- | --- | --- | --- |
| Localized UTI-related findings | Leukocyte esterase is abnormal, nitrite is abnormal, or at least two of dysuria, frequency, urgency, and visible hematuria are selected | Caution to moderate | Flag possible localized UTI findings for clinical context and confirmatory testing when needed |
| Systemic warning symptoms | Fever/chills, back/flank pain, or nausea/vomiting is selected | High | Flag warning symptoms that need clinical review rather than treating symptoms as validated probability multipliers |
| Renal-related follow-up | Protein is abnormal or peripheral edema is selected | Moderate | Flag renal-related follow-up; this is not a renal disease probability |
| Metabolic follow-up | Glucose is abnormal | Moderate | Flag metabolic follow-up separately from UTI findings |

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

## Removed Methods

The app no longer contains or uses:

- LR+ or LR- values
- Prior probability
- Odds-space Bayesian updating
- Posterior probability
- Binary normal/abnormal classifiers
- UTI probability thresholds
- A single merged disease-risk score
