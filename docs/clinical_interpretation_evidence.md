# Uritect Clinical Interpretation Evidence

This app does not calculate a combined disease probability from symptoms and
dipstick results. The scan model remains a 10-parameter semiquant classifier.
Clinical interpretation is a separate evidence display intended for review by a
qualified health worker.

## Evidence Rules

- Selected symptoms with supported likelihood ratios contribute only to the
  localized UTI interpretation.
- Unselected symptoms use LR 1.00. They do not lower risk, because the app does
  not know whether a symptom was truly absent, unasked, or unknown.
- Frequency and urgency are correlated symptoms. If both are selected, the app
  applies urgency LR+ 1.22 once instead of multiplying both values.
- Suprapubic pain, fever/chills, flank or back pain, nausea/vomiting, and edema
  are displayed as clinical flags only. They are not used as numeric
  multipliers in this app.
- Nitrite and leukocyte esterase are the only dipstick analytes used for the
  localized UTI interpretation.
- Protein is handled as a renal follow-up flag.
- Glucose is handled as a metabolic follow-up flag.
- Protein and glucose are not averaged into a UTI score.
- No fixed prior probability is used.
- No Low/Moderate/High posterior thresholds are used.

## Symptom LR Values

| Symptom | App handling | LR+ |
| --- | --- | --- |
| Dysuria | Localized UTI symptom | 1.30 |
| Frequency | Localized UTI symptom | 1.10 |
| Urgency | Localized UTI symptom | 1.22 |
| Visible hematuria | Localized UTI symptom | 1.72 |
| Suprapubic pain | Supporting symptom only | 1.00 |
| Fever/chills | Systemic warning flag | 1.00 |
| Flank/back pain | Systemic warning flag | 1.00 |
| Nausea/vomiting | Systemic warning flag | 1.00 |
| Peripheral edema | Follow-up flag | 1.00 |

## Sources

- Giesen LG, Cousins G, Dimitrov BD, van de Laar FA, Fahey T. Predicting acute
  uncomplicated urinary tract infection in women: a systematic review of the
  diagnostic accuracy of symptoms and signs. BMC Family Practice. 2010.
  https://pmc.ncbi.nlm.nih.gov/articles/PMC2987910/
- Bent S, Nallamothu BK, Simel DL, Fihn SD, Saint S. Does this woman have an
  acute uncomplicated urinary tract infection? JAMA. 2002.
  https://pubmed.ncbi.nlm.nih.gov/12020306/
- NICE Quality Standard QS90 update, urinary tract infections in women.
  https://www.nice.org.uk/news/articles/new-nice-quality-standard-identifies-improvements-in-uti-diagnosis-for-women

