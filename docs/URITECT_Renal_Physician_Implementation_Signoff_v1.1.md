# URITECT Renal Follow-up Implementation Comparison and Sign-off

**Clinical specification:** `URITECT Renal-Related Follow-up Rule Specification v1.1`  
**Implemented rule set:** `renal_followup_rules_v1.1_20260919`  
**Message version:** `renal_messages_v1.1_20260919`  
**Android app version:** `1.3.0` (`versionCode 4`)  
**Android application ID:** `ph.edu.wvsu.uritect`  
**Production visual model:** `production_semiquant_knn_markerless_roi_topfix_v3_20260908`  
**Supported software strip profile:** `urs10t_protein_blood_60s_v1`  
**Date prepared:** 20 September 2026

## 1. Purpose of This Review

This packet allows the reviewing physician to compare the physician-reviewed renal follow-up specification with the exact software implementation included in the release APK.

The module recommends follow-up action. It does not diagnose kidney disease, calculate renal-disease probability, stage chronic kidney disease, or confirm hematuria.

## 2. Frozen Artifact Identity

| Artifact | SHA-256 |
|---|---|
| Release APK `Uritect_v1.3.0_bayesian_v1.1_renal_v1.1_release.apk` | `F68A88D576BCF34FBB83502564512E86F4E28C0CEA71C4FAF752427EBF4F975E` |
| Implemented engine `renal_followup.dart` | `11260233ABCDDD9886733F86DFD03A1C0484DE8ED849F5A245846A55EEE072CE` |
| Clinical specification `v1.1` | `8B462633B3B47E0C3877A4133A8A7600892B18B464100CF36C9BC765809E173A` |

Any change to these files changes the checksum and requires a new implementation comparison.

## 3. Final Action Priority

```text
PROMPT_CONSULT > RETAKE > CONSULT > REPEAT_CONFIRM > OBSERVE
```

Every matching rule is stored in the local audit record. The app displays the action with the highest priority.

An invalid scan does not suppress serious symptom advice. When an invalid scan and a safety rule occur together, `PROMPT_CONSULT` is displayed and no analyte value is interpreted.

## 4. URS-10T Protein and Blood Mapping

| Item | Exact implementation |
|---|---|
| Protein read time | 60 seconds |
| Blood read time | 60 seconds |
| Protein negative | `Neg`, `Negative` |
| Protein trace | `Trace` |
| Protein positive | `0.3`, `1.0`, `3.0`, `>=20.0` g/L |
| Blood negative | `Neg`, `Negative` |
| Blood positive | `Non-hemolyzed 10`, `Hemolyzed 10`, `Small 25`, `Moderate 80`, `Large 200` cells/uL |
| Combined-rule protein threshold | `0.3 g/L` or higher; trace is excluded |

### Physical Product Confirmation Required

`URS-10T` is not a unique manufacturer identifier. Current dataset metadata contains `GenericStrip`, `ModelX`, and `LOT-TBD`. Before external release, complete these fields directly from the physical bottle, box, and IFU used for final testing:

- Manufacturer: ______________________________________________
- Legal manufacturer address: _________________________________
- Product/catalog number: _____________________________________
- Lot number: _________________________________________________
- Expiration date: ____________________________________________
- IFU document identifier and revision: ________________________
- Protein reaction time printed on product chart: ______________
- Blood reaction time printed on product chart: _________________
- Does the physical chart exactly match Section 4?  [ ] Yes  [ ] No

If the physical chart does not match, the current strip profile must not be approved.

## 5. Implemented Checklist Inputs

### Urinary, Alternate-cause, and Systemic Inputs

- Dysuria or burning during urination
- Urinary frequency
- Urinary urgency
- Lower abdominal or suprapubic pain
- Visible blood in urine
- Vaginal discharge
- Vaginal irritation
- Back or flank pain
- Fever or chills
- Nausea or vomiting

### Renal Follow-up and Safety Inputs

- Blood clots in urine
- Difficulty or inability to urinate
- Markedly reduced or absent urine output
- Edema or unusual swelling
- Persistent or unexplained swelling
- Shortness of breath
- Vomiting prevents fluids or oral medication
- Confusion, fainting, or severe weakness
- Severe flank or abdominal pain

### Interference and Temporary-cause Inputs

- Menstruation or vaginal bleeding
- Possible specimen contamination
- Recent strenuous exercise
- Possible dehydration
- Current acute illness
- Possible or clinically managed UTI

### Repeat-test and Technical Inputs

- Protein remained present on a properly collected repeat test
- Blood remained present on a properly collected repeat test
- Blood was confirmed by urine microscopy
- A previous protein finding became negative on repeat
- Strip was expired
- Strip or reagent pads were damaged
- Protein or blood was scanned outside 60 seconds
- Strip was not the supported URS-10T profile

The possible/managed UTI input is entered explicitly. It is not inferred from the Bayesian UTI percentage. Persistence is entered explicitly and is never inferred from one scan.

## 6. Exact Implemented Rule Comparison

### Technical Rules

| ID | Implemented condition | Action |
|---|---|---|
| TECH-01 | Invalid scan, fewer than ten result rows, unknown protein category, or unknown blood category | RETAKE |
| TECH-02 | Expired strip, damaged strip, outside 60-second timing, or unsupported strip profile | RETAKE |

### Safety Rules

| ID | Implemented condition | Action |
|---|---|---|
| SAFE-01 | Visible blood with clots or inability to urinate | PROMPT_CONSULT |
| SAFE-02 | Markedly reduced or absent urine output | PROMPT_CONSULT |
| SAFE-03 | Edema with shortness of breath | PROMPT_CONSULT |
| SAFE-04 | Fever/chills with flank or back pain | PROMPT_CONSULT |
| SAFE-05 | Fever or flank/back pain with nausea/vomiting | PROMPT_CONSULT |
| SAFE-06 | Nausea/vomiting plus inability to maintain fluids or oral medication | PROMPT_CONSULT |
| SAFE-07 | Severe flank/abdominal pain with visible or reliable dipstick blood | PROMPT_CONSULT |
| SAFE-08 | Confusion, fainting, or severe weakness with a urinary finding | PROMPT_CONSULT |

### Interference Rules

| ID | Implemented condition | Action |
|---|---|---|
| INT-01 | Menstruation/vaginal bleeding or possible contamination with reliable positive dipstick blood | REPEAT_CONFIRM |
| INT-02 | Exercise, fever, dehydration, or acute illness with trace-or-higher protein | REPEAT_CONFIRM |
| INT-03 | Explicit possible/managed UTI with trace-or-higher protein | CONSULT |

### Protein Rules

| ID | Implemented condition | Action |
|---|---|---|
| PRO-01 | Reliable negative protein and blood; no edema, visible blood, or safety trigger | OBSERVE |
| PRO-02 | Trace protein; negative blood; no edema or safety trigger | REPEAT_CONFIRM |
| PRO-03 | Protein `0.3 g/L` or higher | CONSULT |
| PRO-04 | User explicitly confirms protein remains present on a properly collected repeat | CONSULT |
| PRO-05 | Protein is currently negative and a previous positive became negative on repeat, without warning findings | OBSERVE |

### Blood Rules

| ID | Implemented condition | Action |
|---|---|---|
| BLD-01 | Reliable non-negative dipstick blood without visible blood or safety trigger | REPEAT_CONFIRM |
| BLD-02 | Visible blood without a safety-rule combination | CONSULT |
| BLD-03 | User confirms blood persists on repeat or was confirmed by microscopy | CONSULT |

### Combined and Edema Rules

| ID | Implemented condition | Action |
|---|---|---|
| COMB-01 | Protein `0.3 g/L` or higher plus reliable non-negative dipstick blood | CONSULT |
| COMB-02 | Protein `0.3 g/L` or higher plus edema | CONSULT |
| COMB-03 | Persistent or unexplained edema explicitly reported | CONSULT |

## 7. User-facing Action Messages

### OBSERVE - Observe for symptoms

No renal-related follow-up trigger was identified from the available reliable results and reported symptoms. This does not rule out a kidney or urinary tract condition. Consult a healthcare professional if symptoms appear, continue, or worsen.

### REPEAT_CONFIRM - Repeat or confirm the test

A finding was detected that may be affected by sample collection or a temporary condition. A properly collected repeat urine test or professional consultation for confirmatory testing may be appropriate.

### CONSULT - Consultation suggested

A urine-strip finding or related symptom was reported. These findings can have several causes and cannot diagnose kidney disease. Consultation with a healthcare professional and confirmatory laboratory testing are suggested.

### PROMPT_CONSULT - Seek prompt medical consultation

A warning symptom or finding was reported. Please seek prompt medical consultation. If you feel severely unwell or symptoms rapidly worsen, seek emergency medical assistance. This result is not a diagnosis.

### RETAKE - Unable to interpret; retake the scan

The relevant urine-strip result could not be interpreted reliably. Repeat the test using the supported strip, collection method, timing, and scanning procedure. Seek professional care based on symptoms even if scanning is unsuccessful.

## 8. Verification Evidence

| Verification | Result |
|---|---|
| Specification rule IDs represented in code | 24 of 24 |
| Specification rule IDs represented in tests | 24 of 24 |
| Focused renal tests | 31 passed |
| Complete Flutter test suite | 44 passed |
| Invalid scan plus serious symptoms | Passed; safety action overrides retake |
| Static analysis | No issues found |
| Android release build | Successful |

## 9. Physician Final Comparison Checklist

Rate each statement as **Agree**, **Revise**, or **Not applicable**.

| Item | Agree | Revise | N/A | Required change or comment |
|---|:---:|:---:|:---:|---|
| Intended use and non-diagnostic limitation are accurate | [ ] | [ ] | [ ] | |
| Final action priority is clinically appropriate | [ ] | [ ] | [ ] | |
| Safety-rule combinations are implemented as approved | [ ] | [ ] | [ ] | |
| Invalid-scan safety behavior is appropriate | [ ] | [ ] | [ ] | |
| Interference and temporary-cause rules are appropriate | [ ] | [ ] | [ ] | |
| Protein trace and positive thresholds are appropriate for the confirmed strip | [ ] | [ ] | [ ] | |
| Dipstick blood is not presented as confirmed hematuria | [ ] | [ ] | [ ] | |
| Persistence requires an explicit repeat result | [ ] | [ ] | [ ] | |
| Possible/managed UTI is not inferred from Bayesian output | [ ] | [ ] | [ ] | |
| Combined protein, blood, and edema rules are appropriate | [ ] | [ ] | [ ] | |
| User-facing action messages are clear and safe | [ ] | [ ] | [ ] | |
| The separate renal results screen avoids diagnosis and risk-probability claims | [ ] | [ ] | [ ] | |
| The implemented `v1.1` behavior matches the physician-reviewed specification | [ ] | [ ] | [ ] | |

## 10. Final Decision and Sign-off

- [ ] Approved as implemented for the stated thesis research purpose.
- [ ] Approved after the documented minor revisions are completed.
- [ ] Major revision and repeat comparison required.
- [ ] Not approved for the stated use.

Conditions or required revisions:

____________________________________________________________________________

____________________________________________________________________________

____________________________________________________________________________

Physician name: _____________________________________________________________

Credentials and license number: _____________________________________________

Institution: ________________________________________________________________

Signature: ___________________________________  Date: _______________________

Exact specification reviewed: `URITECT Renal-Related Follow-up Rule Specification v1.1`

Exact app reviewed: `Uritect 1.3.0 (versionCode 4)`

APK SHA-256 verified by reviewer or project representative:  
`F68A88D576BCF34FBB83502564512E86F4E28C0CEA71C4FAF752427EBF4F975E`
