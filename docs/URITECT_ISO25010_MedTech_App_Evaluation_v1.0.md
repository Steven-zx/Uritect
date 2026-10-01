# URITECT Final App Evaluation Form v1.0

**For:** 10 registered medical technologists  
**Build:** URITECT Android 1.4.0+5

**Purpose:** Final application usability, functionality, and observed
performance evaluation guided by ISO/IEC 25010. This is separate from the
two-medtech review of Bayesian parameter values.

## Important Boundary

This questionnaire evaluates the implemented software and workflow. It does
not clinically validate the Bayesian posterior, establish diagnostic accuracy,
approve antibiotic treatment, or replace comparison with laboratory reference
methods.

## Evaluator Information

| Field | Response |
| --- | --- |
| Evaluator code | |
| Years of urinalysis experience | |
| Workplace/role | |
| Phone model and Android version | |
| Strip manufacturer/catalog/lot | |
| Test date | |
| App version shown | |

Do not write a patient name or other direct identifier on this form.

## Required Task Check

Mark `Pass`, `Fail`, or `Not tested`, then note any issue.

| ID | Task | Pass | Fail | Not tested | Comment |
| --- | --- | --- | --- | --- | --- |
| T1 | Install and open the release APK. | [ ] | [ ] | [ ] | |
| T2 | Complete a valid scan while airplane mode is enabled. | [ ] | [ ] | [ ] | |
| T3 | Confirm exactly ten analyte results are shown. | [ ] | [ ] | [ ] | |
| T4 | Confirm a blank or no-strip image is rejected. | [ ] | [ ] | [ ] | |
| T5 | Confirm a blurred image is rejected. | [ ] | [ ] | [ ] | |
| T6 | Confirm a partial/wrongly framed strip is rejected. | [ ] | [ ] | [ ] | |
| T7 | Confirm a low-confidence scan requests a retake. | [ ] | [ ] | [ ] | |
| T8 | Complete the eligibility and symptom checklist. | [ ] | [ ] | [ ] | |
| T9 | Confirm an eligible UTI result shows its provisional posterior, prior, and applied factors separately from warnings and renal follow-up. | [ ] | [ ] | [ ] | |
| T10 | Save, reopen, and delete a scan-history record. | [ ] | [ ] | [ ] | |

## Rating Scale

`4 = Strongly agree` | `3 = Agree` | `2 = Disagree` | `1 = Strongly disagree`

Select one response for every item. Use `N/O` only when the behavior was not
observed; do not convert `N/O` into a numerical score.

### A. Functional Suitability

| ID | Statement | 1 | 2 | 3 | 4 | N/O |
| --- | --- | --- | --- | --- | --- | --- |
| F1 | The app supports the complete capture-to-results workflow. | [ ] | [ ] | [ ] | [ ] | [ ] |
| F2 | The app displays all ten URS-10T analyte results clearly. | [ ] | [ ] | [ ] | [ ] | [ ] |
| F3 | Invalid or uncertain scans lead to a retake instead of fabricated results. | [ ] | [ ] | [ ] | [ ] | [ ] |
| F4 | UTI findings, systemic warnings, and renal follow-up are clearly separated. | [ ] | [ ] | [ ] | [ ] | [ ] |
| F5 | The UTI estimate transparently shows its prior and applied factors, and the displayed actions match the findings entered or observed. | [ ] | [ ] | [ ] | [ ] | [ ] |

### B. Interaction Capability and Usability

| ID | Statement | 1 | 2 | 3 | 4 | N/O |
| --- | --- | --- | --- | --- | --- | --- |
| U1 | The scan instructions are easy to understand. | [ ] | [ ] | [ ] | [ ] | [ ] |
| U2 | The capture controls and progress feedback are easy to follow. | [ ] | [ ] | [ ] | [ ] | [ ] |
| U3 | The symptom and safety questions are understandable. | [ ] | [ ] | [ ] | [ ] | [ ] |
| U4 | Results can be read without confusing them with a diagnosis. | [ ] | [ ] | [ ] | [ ] | [ ] |
| U5 | Retake and consultation messages tell the user what to do next. | [ ] | [ ] | [ ] | [ ] | [ ] |
| U6 | Text, controls, and result tables remain readable on the test phone. | [ ] | [ ] | [ ] | [ ] | [ ] |

### C. Reliability and Safety Behavior

| ID | Statement | 1 | 2 | 3 | 4 | N/O |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Repeating the same workflow produces stable app behavior. | [ ] | [ ] | [ ] | [ ] | [ ] |
| R2 | The app recovers clearly from an invalid image or failed scan. | [ ] | [ ] | [ ] | [ ] | [ ] |
| R3 | Serious reported symptoms remain visible even when the scan is invalid. | [ ] | [ ] | [ ] | [ ] | [ ] |
| R4 | The app avoids treatment or definitive-diagnosis wording. | [ ] | [ ] | [ ] | [ ] | [ ] |
| R5 | Saved results retain the analytes, action, and rule details needed for review. | [ ] | [ ] | [ ] | [ ] | [ ] |

### D. Performance Efficiency

| ID | Statement | 1 | 2 | 3 | 4 | N/O |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | The app opens within an acceptable time on the test phone. | [ ] | [ ] | [ ] | [ ] | [ ] |
| P2 | Scan processing finishes within an acceptable time for RHU use. | [ ] | [ ] | [ ] | [ ] | [ ] |
| P3 | Navigation remains responsive during normal use. | [ ] | [ ] | [ ] | [ ] | [ ] |

Record observed scan-processing time: __________ seconds.

### E. Compatibility, Offline Operation, and Privacy Controls

| ID | Statement | 1 | 2 | 3 | 4 | N/O |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | The complete tested workflow works in airplane mode. | [ ] | [ ] | [ ] | [ ] | [ ] |
| C2 | Camera/gallery access behaves correctly on the test phone. | [ ] | [ ] | [ ] | [ ] | [ ] |
| C3 | Saved scans remain available after closing and reopening the app. | [ ] | [ ] | [ ] | [ ] | [ ] |
| C4 | A saved scan can be deleted through the app. | [ ] | [ ] | [ ] | [ ] | [ ] |
| C5 | The app avoids requesting information unnecessary for screening. | [ ] | [ ] | [ ] | [ ] | [ ] |

## Open Comments

Most useful feature: _________________________________________________________

Most important issue: _______________________________________________________

Suggested correction: ______________________________________________________

Any wording that could be misunderstood clinically: _________________________

## Overall Decision

Select one:

- [ ] Acceptable for the stated thesis prototype scope.
- [ ] Acceptable after minor revisions.
- [ ] Major revision and repeat evaluation required.
- [ ] Not acceptable for the stated scope.

Evaluator signature: __________________________  Date: ______________________

## Researcher Scoring Instructions

1. Encode each rating as 1 to 4; leave `N/O` missing.
2. Report the mean and standard deviation for each item and quality section.
3. Report task success as `passes / tasks attempted`; do not count `Not tested`.
4. Report the number and percentage selecting each overall decision.
5. Preserve individual de-identified forms and the raw scoring sheet.
6. Do not invent a pass threshold after viewing results. Use an adviser-approved
   threshold declared before data collection, or report descriptive results.
7. Describe this as an ISO/IEC 25010-guided user evaluation, not ISO
   certification.
