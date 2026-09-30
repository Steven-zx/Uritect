# URITECT Renal-Related Follow-up Rule Specification v1.1

**Status:** Physician-reviewed, guideline-checked, and implementation-frozen for final comparison  
**Date:** 19 September 2026  
**Module type:** Deterministic referral and follow-up rules  
**Not a:** diagnostic system, kidney-disease detector, CKD staging system, or renal probability calculator

## 1. Intended use

This module evaluates selected urine-strip findings, reported symptoms, possible interferences, and result reliability to provide only one of the following actions:

1. Observe for symptoms;
2. Repeat or confirm the urine test;
3. Consultation with a healthcare professional is suggested;
4. Prompt medical consultation is suggested; or
5. The scan cannot be interpreted and should be repeated.

The module must never state or imply:

- “You have kidney disease”;
- “CKD detected”;
- “Renal disease probability”;
- “Normal kidneys”;
- “No kidney disease”;
- Low, Moderate, or High renal risk.

## 2. Inputs

The rules may execute only when the corresponding input is collected reliably.

### Dipstick and scan inputs

- Protein category reported by the validated strip;
- Blood category reported by the validated strip;
- Protein-result reliability;
- Blood-result reliability;
- Overall scan validity.

### User-reported inputs

- Visible blood in urine;
- Blood clots;
- Difficulty or inability to urinate;
- Markedly reduced urine output;
- Edema or unusual swelling;
- Shortness of breath;
- Fever or chills;
- Flank or back pain;
- Nausea or vomiting;
- Inability to maintain hydration or take oral medication;
- Confusion, fainting, or severe weakness;
- Severe flank or abdominal pain;
- Menstruation or vaginal bleeding;
- Possible specimen contamination;
- Recent strenuous exercise;
- Dehydration;
- Current acute illness;
- Possible or clinically managed UTI;
- Whether an abnormal finding remains present on a properly collected repeat test.

If the application does not collect an input, the associated rule must not be represented as implemented.

## 3. User-facing outputs

| Internal code | User-facing heading | Meaning |
|---|---|---|
| OBSERVE | Observe for symptoms | No follow-up trigger was identified from the available reliable inputs. This does not rule out disease. |
| REPEAT_CONFIRM | Repeat or confirm the test | A finding may require a properly collected repeat sample or laboratory confirmation. |
| CONSULT | Consultation suggested | A healthcare professional should interpret the finding and decide on confirmation or assessment. |
| PROMPT_CONSULT | Seek prompt medical consultation | Reported warning findings require timely professional assessment. This is an action instruction, not a risk level. |
| RETAKE | Unable to interpret—retake the scan | The relevant scan or analyte result is unreliable. |

The internal codes may be stored for programming and audit purposes, but the application must display the action wording, not a severity label.

## 4. Rule priority

Rules are evaluated in this order:

1. **Safety symptoms:** PROMPT_CONSULT overrides all other outputs, including an invalid scan.
2. **Technical validity:** If no safety trigger is present and the relevant result is unreliable, use RETAKE.
3. **Visible blood and combined findings:** Apply consultation rules.
4. **Possible contamination or temporary causes:** Use REPEAT_CONFIRM unless another finding independently requires consultation.
5. **Isolated protein or blood:** Apply the confirmation rules below.
6. **No trigger:** Use OBSERVE with a safety-net message.

An invalid scan must never suppress advice based on serious symptoms reported by the user.

### 4.1 Frozen implementation clarifications

- Action priority is fixed as `PROMPT_CONSULT > RETAKE > CONSULT > REPEAT_CONFIRM > OBSERVE`.
- Protein `Trace` activates the trace repeat rule but is not positive for combined protein-and-blood or protein-and-edema rules.
- Protein `0.3 g/L` or higher is manufacturer-positive for these referral-support rules.
- Persistence is used only when the user explicitly confirms an appropriate repeat result. A single scan never creates a persistence label.
- Possible or clinically managed UTI is an explicit checklist input. It is not inferred from the Bayesian UTI percentage.
- Systemic safety symptoms may override an invalid scan, but unreliable protein and blood values are never interpreted.

### 4.2 Supported URS-10T profile

| Field | Frozen value |
|---|---|
| Product designation | URS-10T reagent strip, ten parameters |
| Software profile | `urs10t_protein_blood_60s_v1` |
| Protein reaction time | 60 seconds |
| Blood reaction time | 60 seconds |
| Protein categories | `Neg`, `Trace`, `0.3`, `1.0`, `3.0`, `>=20.0` g/L |
| Blood categories | `Neg`, `Non-hemolyzed 10`, `Hemolyzed 10`, `Small 25`, `Moderate 80`, `Large 200` cells/uL |
| Protein positive threshold | `0.3 g/L` or higher |
| Blood positive threshold | Any supported non-negative blood category |

The category labels and 60-second protein/blood timing match the frozen model and an available URS-10T product chart. However, `URS-10T` is not a unique manufacturer identifier. Current project records contain placeholders (`GenericStrip`, `ModelX`, `LOT-TBD`) instead of a physical-bottle manufacturer and IFU revision.

Before external release, transcribe the manufacturer, legal manufacturer address, catalog number, lot number, and IFU revision from the physical bottle, box, and insert used for final testing. Do not infer a manufacturer from an online manual. A strip that does not match this frozen category order, chart, and timing is unsupported and activates `TECH-02`.

Category/timing cross-check: *Urine Testing Series Catalogue 2025*, product `UT-008`, URS-10T. This cross-check does not establish that UT-008 is the physical product used by the project.

## 5. Final rules

### 5.1 Technical validity

| Rule | Condition | Output and action |
|---|---|---|
| TECH-01 | Invalid image, uncertain strip, implausible strip geometry/color, or fewer than ten reliable pad regions | RETAKE. Do not interpret the protein or blood result. |
| TECH-02 | Strip is expired, damaged, read outside the manufacturer’s reaction time, or not supported by the application | RETAKE using the validated strip and procedure. |

The application must not claim that it can identify the wrong strip brand unless brand identification has been implemented and validated.

### 5.2 Safety overrides

| Rule | Condition | Output and action |
|---|---|---|
| SAFE-01 | Visible blood with clots or inability to urinate | PROMPT_CONSULT. |
| SAFE-02 | Markedly reduced or absent urine output | PROMPT_CONSULT. |
| SAFE-03 | Edema or unusual swelling with shortness of breath | PROMPT_CONSULT. |
| SAFE-04 | Fever/chills together with flank or back pain | PROMPT_CONSULT. |
| SAFE-05 | Fever or flank/back pain accompanied by nausea or vomiting | PROMPT_CONSULT. |
| SAFE-06 | Vomiting prevents drinking fluids or taking oral medication | PROMPT_CONSULT. |
| SAFE-07 | Severe flank or abdominal pain with visible or dipstick-detected blood | PROMPT_CONSULT. |
| SAFE-08 | Confusion, fainting, severe weakness, or signs of serious illness with urinary findings | PROMPT_CONSULT and show the application’s emergency safety-net instruction. |

Nausea or vomiting alone does not activate SAFE-05. Without the listed associated findings, the application should advise observation and consultation if the symptom persists, worsens, or prevents hydration.

### 5.3 Interference and temporary-cause rules

| Rule | Condition | Output and action |
|---|---|---|
| INT-01 | Menstruation, vaginal bleeding, or suspected contamination with a blood-positive dipstick result | REPEAT_CONFIRM. Do not treat dipstick blood as urinary or renal evidence. Recommend a properly collected repeat specimen after the interference resolves. |
| INT-02 | Recent strenuous exercise, fever, dehydration, or acute illness with protein detected | REPEAT_CONFIRM and explain that temporary conditions may affect urine protein. |
| INT-03 | Possible active UTI with protein detected | Do not describe the result as kidney disease or persistent proteinuria. Suggest professional consultation and reassessment after the infection is clinically addressed. |

Interference rules do not override safety rules or an independent reason for consultation.

### 5.4 Protein rules

| Rule | Condition | Output and action |
|---|---|---|
| PRO-01 | Protein negative; blood negative; no edema, visible blood, or safety trigger | OBSERVE. |
| PRO-02 | Trace protein only; blood negative; no edema or safety trigger | REPEAT_CONFIRM using a properly collected sample. Professional consultation may be suggested if it continues. |
| PRO-03 | Protein 1+ or higher, or manufacturer-defined positive when no trace category exists | CONSULT. Suggest professional interpretation and quantitative confirmation using urine ACR or PCR where clinically appropriate. |
| PRO-04 | Protein remains present on an appropriate repeat test after temporary causes are addressed | CONSULT. |
| PRO-05 | A previously positive result becomes negative on repeat, with no symptoms or warning findings | OBSERVE, while retaining any follow-up already advised by a healthcare professional. |

A single protein result must never be labelled “persistent.” The software mapping used for implementation is frozen in Section 4.2. Physical manufacturer and IFU identity must still be copied from the bottle and insert before external release.

### 5.5 Blood rules

| Rule | Condition | Output and action |
|---|---|---|
| BLD-01 | Trace or greater dipstick blood without visible blood or safety findings | REPEAT_CONFIRM. Explain that a dipstick alone does not confirm microhematuria; properly collected repeat urinalysis and/or microscopy may be recommended. |
| BLD-02 | Visible blood without clots, urinary obstruction, severe pain, or other safety findings | CONSULT. |
| BLD-03 | Blood remains present on an appropriate repeat test or is confirmed microscopically | CONSULT. |

The application must not label dipstick blood alone as confirmed hematuria or kidney disease.

### 5.6 Combined and edema rules

| Rule | Condition | Output and action |
|---|---|---|
| COMB-01 | Protein is positive and dipstick blood is trace or greater | CONSULT. Suggest professional interpretation, quantitative urine protein/albumin testing, and microscopy as clinically appropriate. |
| COMB-02 | Protein is positive and edema or unusual swelling is reported | CONSULT. |
| COMB-03 | Persistent or unexplained edema is reported, even when protein and blood are negative | CONSULT for assessment of renal and non-renal causes. |

These combinations are consultation triggers. They must not be converted into a kidney-disease diagnosis or probability.

## 6. Approved user messages

### OBSERVE — Observe for symptoms

> No renal-related follow-up trigger was identified from the available results and reported symptoms. This does not rule out a kidney or urinary tract condition. Consult a healthcare professional if symptoms appear, continue, or worsen.

### REPEAT_CONFIRM — Repeat or confirm the test

> A finding was detected that may be affected by sample collection or a temporary condition. A properly collected repeat urine test or professional consultation for confirmatory testing may be appropriate.

### CONSULT — Consultation suggested

> A urine-strip finding or related symptom was reported. These findings can have several causes and cannot diagnose kidney disease. Consultation with a healthcare professional and confirmatory laboratory testing are suggested.

### PROMPT_CONSULT — Seek prompt medical consultation

> A warning symptom or finding was reported. Please seek prompt medical consultation. If you feel severely unwell or symptoms rapidly worsen, seek emergency medical assistance. This result is not a diagnosis.

### RETAKE — Unable to interpret

> The relevant urine-strip result could not be interpreted reliably. Please repeat the test using the correct strip, collection method, timing, and scanning procedure. Seek professional care based on your symptoms even if the scan is unsuccessful.

## 7. Implementation pseudocode

```text
evaluate safety symptoms independently

if any prompt-consultation condition is present:
    output PROMPT_CONSULT
else if scan, protein, or blood result needed by the rule is unreliable:
    output RETAKE
else if visible blood is reported:
    output CONSULT
else if protein is positive and blood is trace-or-greater:
    output CONSULT
else if protein is positive and edema is reported:
    output CONSULT
else if persistent or unexplained edema is reported:
    output CONSULT
else if menstruation, vaginal bleeding, or contamination affects blood:
    output REPEAT_CONFIRM and do not interpret blood
else if a temporary condition may affect protein:
    output REPEAT_CONFIRM
else if possible active UTI and protein is detected:
    output CONSULT and recommend reassessment after clinical management
else if protein is manufacturer-positive:
    output CONSULT
else if protein is trace only:
    output REPEAT_CONFIRM
else if blood is trace-or-greater:
    output REPEAT_CONFIRM
else:
    output OBSERVE
```

When more than one rule fires, store every triggered rule for the audit trail and display the action with the highest priority. The explanation may list all relevant findings without using diagnostic language.

## 8. Required audit trace

For each evaluation, store locally:

- Rule-set version;
- Strip/model version;
- Scan-validity result;
- Protein and blood categories and reliability;
- User-reported inputs used;
- Interference flags;
- Every triggered rule identifier;
- Final internal action code;
- Exact message version shown;
- Date and time.

Do not store more personally identifiable or health information than the approved research and privacy protocol permits.

## 9. Guideline basis and limitations

1. **Philippine Clinical Practice Guidelines on UTI, 2015 Update, Part 2:** Supports professional evaluation for complicated or recurrent UTI situations, gross hematuria or persistent microscopic hematuria, failure or rapid relapse, possible obstruction or structural abnormality, pyelonephritis/systemic illness, and inability to maintain oral hydration or medication. It does not validate a general renal-disease algorithm based on protein and edema.
2. **KDIGO 2024 CKD Guideline:** Supports confirmation of reagent-strip-positive protein/albumin findings using quantitative laboratory measurements such as ACR or PCR, with attention to collection and temporary/interfering factors.
3. **AUA/SUFU Microhematuria Guideline:** A positive dipstick blood result alone does not define microhematuria and should prompt formal microscopic evaluation where clinically appropriate.
4. **Validated strip manufacturer’s instructions:** Must supply the pad order, reaction time, negative/trace/positive categories, units, reference colors, storage conditions, and known interferences used by the application.

The guideline cross-check supports the wording and referral logic; it does not establish diagnostic accuracy, clinical effectiveness, or population-wide validation.

## 10. Documentation of expert review

The project may state:

> The clinical content and referral-support rules were reviewed by a Family Medicine physician for scope, wording, referral recommendations, and safety considerations, and were cross-checked against applicable UTI, kidney-health, and hematuria guidelines.

The project must not state that physician review alone clinically validated the application.

Record the following before final physician comparison and external release:

- Physician reviewer name and credentials;
- Review date;
- Exact specification version reviewed (`v1.1`);
- Approved revisions or conditions;
- Signature or documented confirmation;
- Manufacturer, catalog number, lot, and exact strip product copied from the physical packaging;
- Final manufacturer-category mapping;
- Corresponding implemented software version and checksum.

## 11. Release conditions

The module is ready for programming only when:

- Every required user input exists in the application;
- The physical strip manufacturer, catalog number, lot, and IFU revision are recorded and checked against the frozen software profile;
- Safety rules override scan failure and lower-priority rules;
- No Low/Moderate/High renal-risk label remains;
- No diagnostic wording remains;
- Unit tests cover every rule and priority conflict;
- The physician confirms that the implemented wording matches this reviewed version;
- The app displays its screening/referral-support limitation.
