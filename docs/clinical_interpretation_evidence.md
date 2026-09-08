# Uritect Clinical Interpretation Evidence

This app does not calculate a combined disease probability from symptoms and
dipstick results. The scan model remains a 10-parameter semiquant classifier.
Clinical interpretation is a separate evidence display intended for review by a
qualified health worker.

## Evidence Rules

- Nitrite and leukocyte esterase are the only dipstick analytes used for the
  localized UTI-related findings category.
- Dysuria, frequency, urgency, visible hematuria, and suprapubic pain are shown
  as localized urinary findings, but they are not converted into numeric
  likelihood-ratio weights.
- Fever/chills, flank or back pain, and nausea/vomiting are shown separately as
  systemic warning symptoms.
- Protein is handled as a renal follow-up flag.
- Glucose is handled as a metabolic follow-up flag.
- Protein and glucose are not averaged into a UTI score.
- No fixed prior probability is used.
- No posterior thresholds are used.
- No single combined disease probability is calculated.

## Numeric Weights

The app intentionally does not store or apply LR+, LR-, priors, odds-space
updates, or posterior probability thresholds. Published symptom studies are used
only to justify which symptoms are clinically relevant enough to display as
separate rule-based flags. Exact numeric weighting requires a validated target
population and clinical signoff, so it is outside the current implementation.

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
