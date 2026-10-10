# Corrected-orientation model improvement work

Priorities 1–4 are implemented. No new specimens were collected, as requested. The installed 1.5.9+26 app and its model were not replaced.

## Review packet

- [Full five-metric report](../pipeline/output/knn_improvement_2026-10-11/REPORT.md)
- [Visual error review](../pipeline/output/knn_improvement_2026-10-11/ERROR_REVIEW.html): 2,130 failed prediction rows across baseline/candidate and development/confirmation comparisons; these are not 2,130 independent specimens. Filter by Specific Gravity, Leukocytes or pH. Real baseline inner-pad crops and ten-box context images are stored locally in `image_evidence/` and excluded from Git.
- [Editable review sheet](../pipeline/output/knn_improvement_2026-10-11/ERROR_REVIEW.csv): reference category, prediction, confidence, threshold crossings, crop/context paths and blank reviewer/root-cause/adjudication fields. Existing reference labels are unchanged. Creating this packet does not substitute for adjudicating its labels or timing.
- [Group and fold manifest](../pipeline/output/knn_improvement_2026-10-11/SPLIT_MANIFEST.json), [corrected grouping CSV](../pipeline/output/knn_improvement_2026-10-11/GROUPED_DATASET.csv) and [run evidence](../pipeline/output/knn_improvement_2026-10-11/RUN_EVIDENCE.json).

## What changed

The old grouping helper failed to combine Laua-an `P001-L2700`, `P001-L4000` and `P001-L5500`. The new helper groups all these under the same batch and participant and recomputes identity rather than trusting stale CSV group fields. Unknown filename formats fail explicitly. Cabatuan lighting variants are also grouped together. Cross-batch identity remains unverified; this is a corrected filename-based split, not proof of independent patients.

The experiment uses 565 previously direction-verified events from 313 inferred identities. A shared 453-event development subset uses three group-separated folds; 112 events from 63 inferred groups are reserved for retrospective confirmation. Group and identical-image overlap checks pass. The 219 previously rejected/unresolved events are outside this classifier comparison and remain visible in the prior orientation audit. Zero within-group category disagreements were found in the retained labels; that consistency does not prove label correctness.

The search compares 18 feature/crop variants and 432 k-NN configurations per analyte, then nine augmentation/balancing refinements and the existing baseline configuration. Features include AWB versus raw color, normalized/circular HSV versus Lab, full/75%/50% inner crops, scaling, k=3/9/21, Euclidean/Manhattan distance and uniform/distance weighting. Ranking uses macro F1, macro sensitivity and supported threshold sensitivity/specificity rather than accuracy alone.

Augmentation uses training images only: neutral ±3% brightness and bounded one-pixel central-crop jitter. Clipped changes, excessive feature changes and duplicate augmented vectors from the same source are excluded. Reference-category preservation is an inherited-label assumption, not a new laboratory verification. No augmentation configuration won the final development ranking for any analyte. Augmentation was tested; it was not adopted simply to increase dataset size.

## Results and decision

These are paired, refitted configurations on the same new grouping, **not updated performance claims for the installed APK** and not directly comparable to the earlier 118-event split.

| Metric | Baseline | Development-selected candidate |
|---|---:|---:|
| Confirmation individual-analyte accuracy | 80.18% | 81.61% |
| Confirmation all-ten accuracy | 12.50% | 15.18% |
| Leukocyte exact-category accuracy | 66.07% | 75.00% |
| Specific gravity exact-category accuracy | 69.64% | 71.43% |
| pH exact-category accuracy | 66.96% | 66.07% |
| Blood exact-category accuracy | 86.61% | 75.89% |

Specific gravity's accuracy gain accompanies a slight macro-F1 decrease (0.6702 → 0.6605). pH macro F1 also drops (0.4055 → 0.3377). The candidate does not resolve either concern convincingly. Blood analytical specificity drops from 97.75% to 84.27% despite improved sensitivity for one downstream threshold. A blanket app-model replacement is therefore not justified by this experiment.

Leukocyte Small-or-higher sensitivity increases from 30% to 50% on only ten reference-positive photos, and protein renal-threshold sensitivity increases from 11.11% to 66.67% on nine. These are promising development leads, with small grouped support, not validated clinical performance. Full support counts, confusion matrices and exploratory cluster intervals are in the JSON results.

pH is heavily imbalanced: 406/565 retained reference categories are 5.0, while only six are 6.5. In development folds, the baseline predicts 5.0 on 410/453 photos despite 324 reference-5.0 photos. Reweighting reduces that tendency but does not improve confirmation accuracy or macro F1. This supports a model/data-bias concern; it does not establish the cause of the unavailable phone example reportedly read as 6.5.

The confirmation subset includes two nitrite-positive photos from **one inferred group**. Its 100% candidate accuracy/sensitivity cannot establish stable positive detection; a supporting-group sensitivity interval is withheld. No positive specimens were synthesized.

Configuration selection uses development folds; confirmation follows configuration locking. A pre-guard engineering pass is archived, and subsequent runs reproduce the guarded experiment. The reserved subset has been examined in engineering passes. Existing data were previously used, so no result is labeled a genuinely new untouched final test. Do not tune further settings to this confirmation result and then claim independent confirmation.

## Remaining implementation boundary

The candidate pickles are comparison artifacts, not drop-in app replacements. Several choices use Lab/raw color or class-prior vote weighting absent from the current Dart classifier. Deployment requires matching feature/preprocessing logic, post-vote handling, training-support policy, Python/Dart parity checks and device testing. This work preserves the app's orientation contract, safety gates, numerical results and encrypted history.

All 45 pipeline tests pass, including grouping, crop containment, training-only augmentation, missing-positive metrics and string-category k-NN prediction. Representative failed-case context images were visually checked: their displayed tip-to-handle labels follow the final order, and the shown boxes correspond to physical pad regions. This sample inspection does not certify all 565 localizations.

[Artifact verification](../pipeline/output/knn_improvement_2026-10-11/ARTIFACT_VERIFICATION.json) additionally checks recorded source/model hashes, all 5,650 unchanged reference rows, zero cross-split group/duplicate-image overlap, exactly one development validation prediction per event, recomputed accuracy/coverage summaries and complete real-image links for every failed prediction row.

Reproduce from the repository root:

```powershell
.venv\Scripts\python.exe pipeline/improve_direction_verified_knn.py
.venv\Scripts\python.exe -m unittest discover -s pipeline -p 'test_*.py'
.venv\Scripts\python.exe pipeline/verify_knn_improvement.py
```

The visual packet needs its local, Git-ignored `image_evidence/` directory. Regenerate it where the authorized original research datasets are available; do not publish identifiable research photos with the source repository.
