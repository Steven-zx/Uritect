# Abnormal detection recovery and evaluation audit

Date: 2026-10-05. Status: development audit complete; image adjudication, new independent specimens and final confirmation pending.

The app's current classifier remains unchanged. This work addresses evaluation and development controls. It does not establish improved clinical reliability.

## What the audit actually found

The old split reproduces 1,345/1,630 correct analyte categories (82.52%) and 28/163 complete scans with all ten categories correct (17.18%). That overall number hides these failures:

| Reference-label comparison | Positive captures | Correct positive side | Missed positive side |
|---|---:|---:|---:|
| Female LE threshold: Small 70 or higher | 16 | 5 | 11 |
| Nitrite Positive | 2 | 1 | 1 |
| Protein 0.3 g/L or higher | 6 | 0 | 6 |
| Glucose non-negative, including Trace 5 | 15 | 6 | 9 |

Exact LE Small 70 classification was correct for 1/12 reference captures. An error between two positive categories differs from a negative prediction; both are recorded separately.

These are captures, not verified independent specimen counts. The historical train/evaluation split shares **95 filename-inferred identities** for each analyte. The old grouping failed to combine LAUAAN L2700/L4000/L5500 captures. Additionally, hyperparameters were selected on the same split later reported as evaluation. Consequently, those results are retrospective development diagnostics. The old report is retained for provenance, not offered as untouched test evidence.

The new development split uses 257 training and 86 validation provisional identities, shared across all analytes. Filename inference strips lighting suffixes and groups explicit S1/S2 specimens of a participant together. Batch namespaces avoid accidentally merging unrelated local IDs, but cannot establish whether someone appears in another batch. A verified global participant registry is required before final evaluation.

## Deliverables and how to use them

All generated analytical intermediates are in ../pipeline/output/abnormal_error_audit_2026-10-05/:

- retrospective_audit.json: complete category confusion matrices; support; undefined sensitivity/specificity as null; separate reference-label thresholds; exploratory cluster uncertainty; related-identity split overlaps; accepted-feature metrics and abstention counts.
- historical_predictions.csv: one traceable held-out prediction per analyte/capture, including original archive and event ID, label, vote confidence, threshold crossings and leakage flag.
- abnormal_error_review.csv: all non-negative reference examples for the defined analytical comparisons, plus every exact-category error across all ten analytes. It includes correct abnormal examples for context and negative false positives for review. pH and specific gravity have category errors recorded without inventing normal/abnormal clinical ranges.
- targeted_collection_plan.csv: threshold and exact-category priorities, existing capture counts and provisional identity counts. Required new positive/negative specimen targets remain blank for clinical/statistical approval.
- development_candidate_comparison.json: twelve candidates per analyte (k 3/5/11, raw/scaled features, ordinary versus inverse-training-class-prior vote weighting). Only training labels determine balancing. No rows are duplicated, no final test is inspected, and no model is exported.
- prospective_identity_manifest_template.csv and acceptance_contract_template.json: prerequisites for a new final cohort. The pending template deliberately cannot pass the metadata gate.

Run with the repository Python environment:

~~~powershell
& '.\.venv\Scripts\python.exe' pipeline/audit_abnormal_detection.py --benchmark
& '.\.venv\Scripts\python.exe' -m unittest discover -s pipeline -p test_abnormal_detection_audit.py -v
~~~

Existing manual review rows are preserved on a rerun. Use a new --output-dir when changing data/model configuration to seed a new review; compare by event_key and analyte before transferring annotations.

The historical search now requires explicit acknowledgment and a separate output path, preventing accidental overwrite of frozen production settings. The historical evaluation defaults to a separate reproduction file and marks its design as retrospective with known grouping limitations. Do not run freeze_production_semiquant.py to promote a candidate from this audit.

## Error review before classifier changes

Update from the subsequent source recovery: all 146 events represented in the 408 review rows were located. Raw RHU archives are under new_uritect_dataset; the processed LAUAAN package is in Documents/uritect_training_dataset/packages, and Cabatuan packages are in pipeline/dataset/cabatuan_cleaned. The review now links original images and retains the historical pad crops. New checked_crop_status, checked_pad_crop_path and checked_overlay_path fields distinguish geometry-checked evidence. Clinical reference adjudication and timing review remain pending. See [the implementation and phone-test handoff](URITECT_WORKFLOW_AND_IMAGE_FIXES_2026-10-05.md).

For each priority record, the data manager must locate the original photo using source_zip and event_id, recover the pad crop using the matching extraction configuration, and retain both files. Record strip brand/model, lot, IFU revision, dip/capture/read timestamps and lighting. An archive-derived label is not automatically a verified reference.

Two qualified medtechs should independently assess the reference category using the exact strip instructions, blinded to the model prediction where feasible. Record both readings and an adjudicated category; retain the original label and all disagreement notes. Review agreement cases as well as discrepancies. Do not selectively relabel only model disagreements to inflate performance. Correct development labels only after documented adjudication; preserve a versioned audit trail. Review timing separately for each analyte against the actual IFU rather than assuming a universal read time.

Use label_issue, timing_issue, localization_issue, lighting_issue and classification_issue with yes/no/unknown plus evidence. Multiple issues can coexist. Keep root_cause unresolved until reviewed. Compare full-frame strip localization to crop alignment; inspect glare, clipping, blur and color shifts; compare properly timed labels to the captured pad state. Only then decide whether acquisition, segmentation, reference labels or classification requires correction.

## Targeted independent collection

Prioritize nitrite positives, LE Small 70 and higher, protein-positive categories and glucose-positive categories. The category rows expose absent/rare levels separately. Collect adequate negative controls for specificity as well as positive specimens for sensitivity. A specimen can support several analyte comparisons, but cannot be counted as several independent people for one comparison.

Use a stable de-identified global participant ID across sites/dates, a unique specimen ID and a unique capture ID. Photograph repeats under planned lights and both camera/upload workflows for repeatability; keep every specimen from the same participant on one split side. Preserve rejected images and reasons. Acquire and medtech-label genuinely new specimens; duplicates, oversampling, synthetic colors and repeated photographs cannot fulfill biological sample-size targets.

Capture the exact strip IFU metadata, per-pad timing, two independent label readings, disagreement resolution, device/capture route and acquisition/QC results. Failed scans belong in the acquisition log. Retakes must link to the original attempt so eventual success cannot erase earlier failures.

The existing RHU daily image target is an operational capture plan, not a statistically justified abnormal-cohort sample size. Clinical advisers and the statistician must approve independently labeled positive and negative specimen counts per threshold, eligible population, acceptable miss/false-positive rates and precision. No numeric safety cutoff or sample target is invented here.

## Development comparison and selection

The new benchmark ranks development diagnostics by mean threshold sensitivity, supported-reference-class macro F1, then threshold specificity; overall accuracy is descriptive. Unsupported reference categories are listed rather than silently treated as observed successes. Candidate ranking is provisional, and selected_model is null for every analyte.

Balancing illustrates a real tradeoff: the sensitivity-ranked LE candidate has mean threshold sensitivity about 70.7% but mean specificity about 55.4%; the protein candidate about 73.7% and 65.1%. These means combine explicitly listed rules, including overlapping thresholds; they are not independent clinical endpoints. Inspect each rule separately. These results do not justify switching the app classifier. The corrected development split also differs from the historical split, so comparisons to historical accuracy are not proof of improvement.

Approve specificity constraints and a rule-specific selection objective before selecting a candidate. Then compare balanced alternatives within verified participant-grouped development folds, examine class supports and failure modes, and lock the selected configuration. The current benchmark is one development validation split, not nested cross-validation or a final confirmation.

## Untouched final evaluation and acceptance

Use a new cohort: previously inspected historical records cannot become untouched test data by renaming their split. A data custodian should seal final labels, while development uses separate training/validation records. Lock the model, analysis plan, eligibility, threshold definitions and decision criteria before unsealing final data. Evaluate the chosen version once; subsequent tuning needs another independent confirmation.

The manifest metadata validator rejects missing identities/adjudication, cross-split participant/specimen/image-hash overlap, duplicate capture IDs, previously reviewed test data, missing train/validation/test inventory, unapproved acceptance settings and missing model/analysis hashes. This is a metadata check, not authenticity verification, a final evaluation runner, sample-size certification or a deployment approval.

~~~powershell
& '.\.venv\Scripts\python.exe' pipeline/audit_abnormal_detection.py --final-manifest path/to/complete_inventory.csv --acceptance-contract path/to/approved_contract.json
~~~

The final analysis must report exact-category confusion/support and the actual downstream-rule thresholds separately, with confidence intervals appropriate to the prespecified independent unit or participant clustering. Report all attempted scans, invalid detections, confidence abstentions, retakes, eventual successes and performance among accepted scans. Do not count abstentions as negative results or report accepted-only accuracy without coverage and missed-positive outcomes.

This retrospective report's 43/163 feature-stage abstentions (26.38%) and 23/120 all-ten-correct accepted events (19.17%) use reconstructed distance-weighted kNN vote confidence at 0.45. Detection failures and capture-quality failures were already excluded by feature extraction. Thus these are not measured end-to-end app retake rates. The .45 vote threshold is an existing implementation setting, not a calibrated probability or clinical safety criterion.

Exploratory percentile intervals resample provisional identity clusters with 500 deterministic draws. Intervals are withheld for fewer than two supporting identities or degenerate draws; they do not establish final precision. Tiny positive counts, incomplete identity verification and tuning contamination remain limitations. A final statistician-approved interval method is still required.

The JSON field names sensitivity/specificity refer to the supplied reference labels. Medtech strip agreement does not by itself establish UTI/renal disease diagnostic sensitivity. If the comparator is not an accepted reference standard for the target condition, report positive/negative agreement with clear terminology. FDA guidance distinguishes reference-standard diagnostic accuracy from non-reference agreement and recommends uncertainty reporting; it does not supply a sample-size design for these correlated lighting captures. [FDA guidance](https://www.fda.gov/regulatory-information/search-fda-guidance-documents/statistical-guidance-reporting-results-studies-evaluating-diagnostic-tests-guidance-industry-and-fda). Group-aware validation keeps related samples together; independent held-out data are needed after model selection. [Scikit-learn cross-validation documentation](https://scikit-learn.org/stable/modules/cross_validation.html).

## Thesis limitations to retain

Current performance is exploratory development evidence with related-capture leakage, selection on the reported split, sparse abnormal reference categories, uncertain cross-batch identity, incomplete image/timing adjudication and unmeasured end-to-end rejection rates. Neither balancing nor relabeling has demonstrated improved independent clinical reliability. The current app remains a research prototype pending new reference-verified specimens and prespecified final validation.
