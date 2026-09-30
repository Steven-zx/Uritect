# URITECT Manuscript Final Revision Guide

The current source available in the repository is
`docs/BSCS_Group5_Manuscript_50.pdf`; no editable manuscript source is present.
The PDF cannot be safely rewritten as a thesis source document. Apply the
changes below to the original Word/Google Docs file, then replace the exported
PDF.

## Global Replacements

Search the entire manuscript, including captions, diagrams, tables, abstract,
and conclusion.

| Current claim to remove | Final replacement |
| --- | --- |
| Python/FastAPI scan server, SciPy runtime, HTTP endpoint | All production scan and interpretation logic executes locally in Flutter/Dart on Android. |
| Marker-based or macromarker localization | Markerless strip localization based on plausible strip geometry and color/chroma activity. |
| Adaptive thresholding and contour detection as the final ROI algorithm | Orientation search, strip-candidate scoring, pad-column detection, chroma-activity row localization, and ten-pad geometry validation. |
| k-NN probabilities sent directly into disease Bayesian fusion | k-NN outputs semiquantitative analyte classes and confidence. The UTI research model maps source-matched LEU/NIT/BLD categories into one grouped dipstick LR. |
| Four sentinel analytes GLU/PRO/LEU/NIT in one Bayesian disease engine | Bayesian inference is limited to gated lower-UTI screening using LEU/NIT/BLD. Renal follow-up is a separate deterministic rule engine using protein, blood, symptoms, repeat history, safety, and interference inputs. |
| Low/Moderate/High UTI risk or 20/80, 30/70, or 35/70 thresholds | Display the provisional posterior with its prior and applied LRs only for eligible calculations, plus Observe, Consultation suggested, Prompt medical consultation suggested, or Insufficient evidence. Do not convert the number into a probability band. |
| Bayesian renal probability | Deterministic renal follow-up action; no renal probability and no renal diagnosis. |
| 80% overall app/scan accuracy | 82.52% individual-analyte accuracy and 17.18% all-ten-correct whole-scan accuracy under specimen-grouped evaluation. |
| Random train/test split with images treated independently | Specimen-grouped 80/20 split; all lighting variants from one specimen remain on one side. |
| ISO compliance/certification | Evaluation guided by ISO/IEC 25010. |

## Title and Abstract

Keep “Bayesian Late Fusion” only if the abstract immediately limits it to the
provisional, literature-derived UTI research pathway. State that renal output
uses deterministic follow-up rules. Include offline Android execution,
markerless ten-pad processing, the exact model version, grouped evaluation, and
both individual and whole-scan accuracy. Do not call the posterior clinically
calibrated or validated.

## Chapter 1

### General objective

Describe an offline Android urinalysis screening prototype with markerless
computer vision, ten-analyte k-NN classification, gated Bayesian UTI research
interpretation, and separate renal follow-up rules.

### Specific Objective 2

Retain the unreacted strip/plastic reference concept, but use this operational
wording:

> Develop a neutral strip/plastic-referenced gray-world normalization method
> that estimates channel gains from low-saturation pixels adjacent to the
> detected reagent-pad stack to reduce lighting-related color shifts.

### Specific Objective 3

Replace adaptive-threshold/contour wording with:

> Develop an offline Android application with markerless strip localization
> and automated ten-pad ROI extraction using orientation search, strip geometry,
> color/chroma activity, pad-spacing validation, and invalid-scan rejection.

### Specific Objective 4

Use:

> Train and evaluate per-analyte k-nearest neighbors models using accuracy,
> macro F1-score, one-vs-rest macro sensitivity and specificity, and Cohen's
> kappa under specimen-grouped splitting; integrate source-matched dipstick
> categories and symptoms into a gated Bayesian UTI research estimate, while
> producing renal follow-up through a separate deterministic rule engine.

### Scope and limitations

State the supported strip profile and unresolved physical-manufacturer gate.
Limit the Bayesian pathway to symptomatic, nonpregnant women aged 18-64 with
all six eligibility confirmations and no alternate-cause/systemic finding.
State that no culture-confirmed calibration study was performed.

## Chapter 3

Document these exact reproducible details:

- Laua-an plus Cabatuan 2026-07-15 and 2026-07-17 cleaned packages.
- 7,840 final analyte rows; zero exact duplicates removed by the frozen key.
- 257 capture bursts rejected during corrected markerless ingest.
- Normalized HSV features and analyte-specific `k`, distance metric, and feature
  transform from the final report.
- GroupShuffleSplit, test size 0.20, random state 42, group `specimen_group`.
- Confidence threshold 0.45 applied to every analyte at scan acceptance.
- UTI v1.1 eligibility, mapping, grouped LR hierarchy, and audit-only posterior.
- Renal v1.1 rule IDs, priority order, final action, and invalid-scan safety
  override.

Do not describe unselected symptoms as confirmed absent. Unselected/unknown,
unavailable, or unreliable inputs receive no Bayesian update.

## Chapter 4

Replace architecture, sequence, activity, deployment, and data-flow diagrams
that still show Python, FastAPI, HTTP, macromarkers, four-sentinel fusion, or
risk buckets. The final flow is:

```text
Android image capture/gallery
  -> image-quality rejection
  -> orientation search
  -> markerless strip localization
  -> neutral strip/plastic AWB
  -> ten-pad ROI validation
  -> normalized HSV extraction
  -> ten per-analyte k-NN predictions
  -> confidence retake gate
  -> separate UTI, systemic/alternate-cause, and renal outputs
  -> local history
```

The k-NN library is not shipped as Python/scikit-learn. Training uses
scikit-learn; the frozen neighbors, labels, scaling parameters, feature
transforms, metrics, and `k` values are serialized to JSON and the same
algorithm is executed in Dart on Android.

## Results

Use `pipeline/output/production_grouped_metrics_complete.json` as the classifier
source. Report the full per-analyte table from `FINAL_PROJECT_HANDOFF.md`, class
support/confusion matrices where space permits, and the confidence-gated
coverage results. Explain that weak macro F1/sensitivity for some analytes
reflect class imbalance and rare-level performance despite high aggregate
accuracy.

Do not compute diagnostic sensitivity/specificity for UTI or renal disease from
the reagent-class metrics. No culture-confirmed disease reference standard was
used for the Bayesian model.

## Objective 5 and ISO/IEC 25010

Use the prepared 10-medtech form. Report task-success results, per-item and
per-characteristic means/standard deviations, observed processing time, defects,
and overall decisions. Call this an ISO/IEC 25010-guided evaluation, not
certification. Do not mark Objective 5 complete before data collection.

## Conclusion

Conclude only that the offline prototype achieved the stated individual-analyte
performance under the frozen grouped evaluation and implements conservative
screening/referral-support logic. Explicitly retain these limitations:

- Whole-scan all-ten-correct accuracy is 17.18%.
- Specific Gravity and Leukocytes remain weak analytes.
- Cross-device and real-world invalid-image acceptance require field testing.
- Physical manufacturer/IFU identity must be recorded.
- Bayesian probability calibration and diagnostic validation require
  culture-confirmed prospective cases.
