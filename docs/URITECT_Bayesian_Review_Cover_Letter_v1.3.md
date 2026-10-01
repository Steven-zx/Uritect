# Request for Expert Content Review

**Krizzler Faith M. Montaño, RMT**  

Registered Medical Technologist

**Dear Ms. Montaño:**

Greetings!

We are fourth-year Bachelor of Science in Computer Science students from West
Visayas State University. As part of our undergraduate thesis, we developed
**URITECT**, an offline smartphone-based urinalysis dipstick screening and
clinical decision-support application.

We respectfully request your professional review of the proposed urinalysis
dipstick mappings and literature-derived likelihood-ratio parameters used in
URITECT's sex-specific Bayesian urinary tract infection (UTI) research
component.

URITECT serves eligible male and female adult users for ten-analyte strip
scanning, safety assessment, and renal follow-up. Its UTI research component
uses separate evidence pathways because the available studies differ by sex:

- The female candidate model uses evidence derived principally from
  symptomatic, nonpregnant women.
- The male candidate model uses culture-referenced evidence from symptomatic
  men and is limited to nitrite and leukocyte esterase. Female blood and
  symptom likelihood ratios are not applied to men.

A likelihood ratio describes how a finding changes the evidence supporting
UTI. A value greater than 1 increases the evidence, a value below 1 decreases
it, and a value of 1 produces no update. An LR is not itself a percentage.

The attached form shows every candidate value, its source, the exact strip
mapping, and how URITECT prevents correlated findings from being counted more
than once. The resulting estimates are provisional, literature-derived, and
not locally calibrated. They do not diagnose UTI, recommend treatment, replace
urine culture, or replace professional judgment. URITECT does not convert the
estimates into Low, Moderate, or High categories.

We ask you to assess whether the laboratory mappings, candidate parameters,
handling of missing or unreliable results, and screening workflow are relevant
and acceptable for the stated research purpose. Further physician, clinical,
statistical, and culture-confirmed patient-level validation is required before
the estimates can be described as clinically validated probabilities.

Thank you for sharing your professional time and expertise.

Respectfully,

The URITECT Research Team

Bachelor of Science in Computer Science  
West Visayas State University
