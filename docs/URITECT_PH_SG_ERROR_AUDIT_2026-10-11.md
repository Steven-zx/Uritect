# pH and specific-gravity error audit — 2026-10-11

The focused audit and targeted development experiments are complete. Neither analyte has a sufficiently consistent improvement to replace the current app classifier. The physical pad order remains LEU → NIT → URO → PRO → pH → BLD → SG → KET → BIL → GLU, from tip toward handle.

## Evidence and scope

- [Focused visual review](../pipeline/output/ph_sg_error_audit_2026-10-11/FOCUSED_REVIEW.html): failed crops, correct controls, reference/predicted categories, confidence, original and experimental crops, and surrounding pad context.
- [Editable review sheet](../pipeline/output/ph_sg_error_audit_2026-10-11/FOCUSED_REVIEW.csv): 906 development pad records, including 121 pH and 192 SG baseline errors.
- [Benchmark report](../pipeline/output/ph_sg_error_audit_2026-10-11/REPORT.md), [five-metric results and class confusion counts](../pipeline/output/ph_sg_error_audit_2026-10-11/NESTED_DEVELOPMENT_RESULTS.json), and [error-cause diagnostics](../pipeline/output/ph_sg_error_audit_2026-10-11/ERROR_CAUSE_DIAGNOSTICS.json).

Only the existing 453 development photos entered error ranking, nearest-neighbor diagnostics, or nested evaluation. The 112 already-inspected confirmation photos were not evaluated again. Extraction covers the retained 565 photographs for reproducibility; extraction is not evaluation. Groups remain filename-inferred within batches, with identity across batches unverified. These are exploratory development results, not a new independent confirmation or clinical validation.

## Findings

### pH majority-class bias is confirmed

The retained data contain 406 pH 5.0 photos and only six pH 6.5 photos. In development, 324/453 reference labels are 5.0, but the baseline predicts 5.0 for 410/453. It calls 84/101 pH 6.0 photos 5.0. It correctly identifies none of the four development 6.5 examples. This explains a strong tendency toward 5.0; it does not prove that every phone result of 5.0 is wrong.

Color neighborhoods overlap: using normalized app-style features, the nearest photograph from another inferred specimen group has a different reference label for 33.55% of development pH photos. For reference 6.0 the disagreement is 69.31%. Raw features reduce overall disagreement to 28.48%, but the grouped experiment still does not establish a stable model improvement. Neighborhood disagreement is an exploratory feature-overlap diagnostic, not proof that the reference labels are incorrect.

### SG has substantial adjacent-category confusion

Of 192 development SG errors, 145 (75.52%) differ by exactly one 0.005 category step. Normalized app-style features have 44.15% nearest-other-group label disagreement; raw features have 45.03%. Brightness removal, Lab, backing calibration and smaller crops do not consistently separate these classes in the nested comparison.

### No widespread original-crop contamination was established

Visual inspection covered targeted failed examples with large brightness variation, large proposed shifts, uncertain boundaries and rare categories, plus correct controls. The inspected original boxes generally lie inside the reagent pads. Strong warm/cool casts and nonuniform pad color remain visible. This is a sampled visual review, not manual adjudication of every photograph.

After the boundary safeguard described below, complete color boundaries were supported for only 67/121 pH errors and 89/192 SG errors. None of those supported original crops had less than 95% mask support. The remaining cases are **uncertain**, not verified clean. A saturated backing can resemble reagent color, so mask support alone cannot establish physical containment.

The initial experimental refinement did make a confirmed localization mistake: tinted backing joined the color mask and shifted a proposed crop left toward the backing in Cabatuan examples, including `uritect_2026-7-15_Cabatuan_025_Daylight` (SG) and `uritect_2026-7-15_Cabatuan_011_Daylight` (pH). This was a development candidate, not the deployed detector. The candidate now rejects components reaching the search-window edge and retains the original ROI when a complete boundary is unavailable. Regression tests cover this failure. Results below were regenerated after the safeguard.

### Training/runtime feature extraction differs

The existing Python extractor uses OpenCV's quantized hue and arithmetic averaging; the app uses float corrected RGB, circular hue averaging, and strided sampling. On identical supplied ROIs and gains, median normalized hue differences among errors are about 0.23° for both targets. Differences above 5° occur in two pH errors and five SG errors, but also occur in correct predictions. The mismatch is real; it does not explain most observed errors by itself.

Cross-pad normalization also couples a pad's features to the other nine reagent colors. A regression test demonstrates that identical target-pad color can yield different normalized features when other pads change. This is a potential nuisance dependency, not proof of the cause of an individual error. Raw and neutral-backing feature experiments explicitly tested alternatives.

Python now has an app-compatible float/circular feature helper. The app delegates its existing math to a shared, directly testable helper. This refactor preserves the runtime feature calculation and model. Thirty synthetic pixel/ROI/gain cases verify Python/Dart feature parity, including hue wrap and clipped gain corrections. This does **not** establish full JPEG decoder, resize, AWB-estimator, detector, or new-classifier prediction parity.

### Recorded labels are internally consistent, not independently revalidated

Raw reference values canonicalize to the retained category with zero mismatches for pH/SG. No inferred specimen group has conflicting pH/SG reference labels across its photographs. Labels were not changed. This cannot establish correct strip-chart interpretation, laboratory reference values or reaction times. The retained set has no pH 8.0 or SG 1.000 examples, so performance for those categories is unsupported.

## Targeted comparison and decision

Twelve recipes tested runtime-compatible normalized/raw HSV, hue/saturation without brightness, dense sampling, half-size crops, conservative local refinement, neutral backing correction, and Lab. Each target had 216 configurations across scaling, k=3/9/21 and frequency reweighting. Three outer grouped folds each used three inner grouped folds to select settings using macro F1 and macro sensitivity. The unchanged baseline was eligible during inner selection.

| Analyte | Baseline accuracy | Selected procedure accuracy | Baseline macro F1 | Selected macro F1 | Baseline macro sensitivity | Selected macro sensitivity |
|---|---:|---:|---:|---:|---:|---:|
| pH | 73.29% | 69.09% | 0.2493 | 0.4283 | 0.2357 | 0.4978 |
| SG | 57.62% | 55.63% | 0.5221 | 0.5156 | 0.5164 | 0.5140 |

Accuracy, macro F1, sensitivity, specificity and Cohen's kappa are recorded with class supports and confusion counts in the result JSON. The selected procedure uses different inner-selected configurations per outer fold; it is not one frozen deployable model. Its numbers must not be substituted for previous whole-scan results.

pH's minority recall improves at the expense of overall category accuracy. SG gets worse overall. Neither passes the recorded engineering promotion screen. Refitting the original settings with app-compatible features alone yields pH accuracy 73.51% and SG 57.17%; this small, mixed change is also insufficient for promotion.

**Decision: retain both current models.** No blood or other analyte model, confidence threshold, Bayesian LR/prior, label, strip orientation, frozen APK, or phone installation was changed by these experiments. A future candidate must pass its individual comparison, regenerate model-bound support limits, and demonstrate prediction parity before export and phone testing.

## Verification and next useful work

- 50 Python regression tests passed, including circular hue, normalization coupling, conservative pad refinement and tinted-backing fallback.
- 143 Flutter tests passed, including real-image camera/gallery equivalence, tip/handle mapping under all rotations, invalid/multiple-strip rejection and Python/Dart pixel-feature parity.
- Static analysis is recorded in `VERIFICATION.json` after cleanup of the obsolete circular-mean helper.

The next investigation should concentrate on the listed overlapping-color/reference pairs and lighting variation within existing inferred specimens, rather than another broad parameter search. Independent reference evidence would be necessary before changing a label; this audit does not manufacture such evidence. With the user's decision to defer new specimens, unsupported categories and small rare-class support remain explicit limitations. No performance gain is claimed from this round.

Reproduce from repository root:

```powershell
.venv\Scripts\python.exe pipeline/audit_ph_sg_errors.py
.venv\Scripts\python.exe pipeline/summarize_ph_sg_audit.py
.venv\Scripts\python.exe -m unittest discover -s pipeline -p 'test_*.py'
```

Run `flutter analyze --no-pub` and `flutter test --no-pub` from `uritect_app`. Research image evidence remains local and ignored by Git.
