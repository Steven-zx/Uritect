# Uritect Clinical Interpretation Evidence

The scan model remains a 10-parameter semiquant classifier. Clinical
interpretation is a separate UTI-focused Bayesian research candidate intended
for review by a qualified health worker. The app does not claim renal,
metabolic, or hepatic screening interpretation.

## Evidence Rules

- Nitrite, leukocyte esterase, and blood are the dipstick analytes used for the
  UTI screening findings category.
- Dysuria, frequency, urgency, and visible hematuria can contribute one grouped
  urinary-symptom likelihood ratio. Suprapubic pain is displayed but unweighted.
- Vaginal discharge and vaginal irritation are shown as alternate-cause
  symptoms because published reviews report that they lower the likelihood of
  uncomplicated UTI.
- Fever/chills, flank or back pain, and nausea/vomiting are shown separately as
  systemic warning symptoms.
- Protein, glucose, ketones, bilirubin, urobilinogen, pH, and specific gravity
  remain visible in the ten-analyte dipstick table but are not used for UTI
  screening interpretation.
- A 50% development prior is used for the source population.
- Posterior display bands are provisional at less than 20%, 20% to less than
  80%, and 80% or greater.
- Systemic warning findings are not included in the lower-UTI posterior.

## Numeric Model

The app applies one mutually exclusive LR from each of three groups: dipstick
pattern, localized urinary symptoms, and alternate-cause symptoms. New history
records store the candidate version and posterior estimate.

The frozen specification is documented in
`docs/uti_screening_weight_table_for_physician_review.md`. It must not be
described as clinically validated until physician review, local calibration,
and outcome validation against urine culture are complete.

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
