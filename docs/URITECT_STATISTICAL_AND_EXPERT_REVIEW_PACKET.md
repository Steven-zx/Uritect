# Statistical and expert content review packet — 1.4.1+14

Status: **prepared; all reviews pending**.
Review the sealed source and exact release APK identified in the release manifest.
The numerical parameters remain unchanged; no replacement values have been invented.

## Frozen calculations

Female model `uti_bayesian_female_v1_1_20260926`: prior 0.50.
Select only the first matching dipstick branch, then only the first matching symptom branch.

| Female dipstick branch | LR |
| --- | ---: |
| Nitrite positive and source-positive leukocytes or blood | 7.20 |
| Nitrite positive without the stronger pattern | 5.50 |
| Source-positive blood without positive nitrite | 1.70 |
| Source-positive leukocytes without positive nitrite/blood | 1.40 |
| Nitrite, leukocytes and blood all confirmed negative | 0.22 |

| Female symptom branch | LR |
| --- | ---: |
| Dysuria and urgency | 1.50 |
| Dysuria | 1.30 |
| Urgency | 1.20 |
| Frequency | 1.10 |

Female LE positive: Small 70, Moderate 125, Large 500 (not Trace 15).
Female blood source-positive: Hemolyzed 10, Small 25, Moderate 80, Large 200;
Non-hemolyzed 10 does not satisfy that evidence mapping.
Nitrite positive requires Positive. Unsupported/unmatched patterns do not silently become negative.
Visible hematuria is consultation context, not an additional numerical blood factor.
A symptom without a source-matched LR contributes no extra factor.

Male model `uti_bayesian_male_v0_1_20261001`: prior 97/186 = 0.521505...
Select exactly one first-matching branch:

| Male branch | LR |
| --- | ---: |
| Nitrite positive AND LE positive | 5.14 |
| Nitrite positive after excluding the stronger branch | 4.87 |
| LE positive after excluding stronger branches | 1.65 |
| Nitrite and LE both confirmed negative | 0.35 |
| Missing/unreliable/unmatched inputs | No calculation |

Male LE positive includes Trace 15, Small 70, Moderate 125, Large 500.
Male blood and symptoms are not multiplied as numerical factors.
The prior is derived from the den Heijer younger subgroup; the LRs came from broader
threshold analyses, not mutually exclusive pattern analyses in a Filipino cohort.

For both pathways:
prior odds = p/(1-p); posterior odds = prior odds × selected factors;
posterior = odds/(1+odds). Female uses at most one dipstick × one symptom factor.
Male uses one dipstick factor. No Low/Moderate/High posterior bands or treatment cutoff exist.
Clinical action depends on findings/safety rules, not an arbitrary posterior risk threshold.

## Gates and actual output

Both require age 18–64, symptomatic intended population, no catheter, urologic abnormality or
immunocompromise, reliable supported-strip results, confirmed quality and completed safety review.
Female requires nonpregnancy and excludes vaginal discharge/irritation from ordinary calculation.
Male additionally excludes diabetes and suspected STI.
Female qualifying symptoms: dysuria, frequency, urgency, suprapubic pain or visible hematuria.
Male qualifying symptoms: dysuria, frequency or urgency.
Systemic findings and renal prompt-consult overrides suppress ordinary UTI estimates.
Unknown/unanswered items are not confirmed absence. Invalid scans retain symptom-based safety advice.

Review exact flag IDs and precedence in
`uritect_app/lib/models/screening_fusion.dart`,
`uritect_app/lib/models/clinical_symptoms.dart`,
`uritect_app/lib/models/renal_followup.dart` and
`docs/URITECT_UTI_Eligibility_Authority.md`.
The results page displays a provisional literature-derived estimate, prior, applied LRs,
model version and unresolved assumptions. It does not diagnose UTI or recommend antibiotics.

## Questions for the statistician

1. Do female branch selection and symptom grouping match source evidence? Does conditional
   dependence prevent multiplying symptom and dipstick LRs as a coherent calibrated model?
2. Male 4.87 and 1.65 are threshold LRs: are they usable after stronger branches are excluded,
   or are mutually exclusive pattern likelihoods/patient-level data required?
3. Can the younger-subgroup 97/186 prior be combined with broader-cohort LRs and transported
   to local symptomatic adults aged 18–64? What age/source/setting uncertainty must be reported?
4. Which priors/LRs are defensible for research demonstration, and which claims must be withheld?
   Provide a rationale and source; do not approve by mathematical arithmetic alone.
5. Specify prospective culture-based design, sample size/event requirements, independence,
   missing-data/retake policy, calibration assessment, discrimination and confidence intervals.
   Separate strip-class evaluation from disease-outcome evaluation.
6. Review abnormal-class sensitivity/specificity, support and leakage in the historical scanner
   audit, plus prespecified acceptance criteria for a new independent validation set.

Record decisions as retain/revise/withhold with rationale, date, exact source/model versions,
APK checksum and signed evidence. A statistical review is not itself a prospective calibration study.

## Two MedTech and physician content reviews

Two MedTechs independently verify the physical IFU/pad/category mappings, reaction timing,
reference-label adjudication and laboratory capture workflow using the physical-strip protocol.
Use the existing Bayesian parameter form v1.3 for content review and this supplement for the
updated progressive checklist and on-screen disclosures. Sign-off must explicitly identify the
current build; older PDF/version approval does not automatically approve this APK.

The physician reviews eligibility/safety language, renal rule IDs/actions, visible hematuria,
systemic symptoms, dehydration and escalation advice against the actual app.
Use the renal v1.1 sign-off form and record any wording revisions before acceptance.
Do not describe pending expert review as "expert-reviewed" in the manuscript or app evaluation.

## Planned usability evaluation

Use the existing ISO/IEC 25010-guided ten-MedTech instrument and data template.
All evaluators use the same frozen APK. Record de-identified tasks, completion, defects, latency,
characteristic ratings, limitations and the instrument's ISO edition.
Run `pipeline/analyze_medtech_app_evaluation.py` only after actual responses are collected.
Report participants, missing data, descriptive results and comments transparently.
Do not change the planned participant count, invent responses/pass cutoffs, claim ISO certification,
or equate usability approval with clinical outcome validation.

## Evidence and boundaries

Authoritative source tables and derivations:
[sex-specific specification](URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.md)
and [female specification](URITECT_Bayesian_UTI_Scoring_System_v1.1.md).
Male study: [den Heijer et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC3481519/).
[PROBAST+AI](https://www.bmj.com/content/388/bmj-2024-082505) distinguishes evaluation of
model performance from content review. Culture-confirmed outcomes, predefined protocols and
appropriate validation are required for calibration/discrimination claims.
Current status is literature-derived, not locally clinically calibrated, and reviews are pending.
