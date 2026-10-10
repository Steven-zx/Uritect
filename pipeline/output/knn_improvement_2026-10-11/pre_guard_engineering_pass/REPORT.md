# Direction-verified kNN improvement experiment

Retrospective research development only. The installed app, reference labels and frozen APK are unchanged. Filename-derived within-batch grouping is corrected; identity across batches is unverified. Existing data have previously been inspected, so confirmation is not a new untouched test.

565 direction-verified events; 453 development / 112 confirmation events. 313 inferred within-batch identities. 219 earlier events excluded by the existing direction/geometry audit; no new specimens collected.

Selection used three group-separated development folds, macro F1, class sensitivity and supported analytical/rule thresholds. Scaling and augmentation fit training partitions only. Confirmation was evaluated after configuration lock. No clinical acceptance criteria are invented.

| Analyte | Baseline confirmation accuracy | Candidate confirmation accuracy | Candidate macro F1 | Candidate macro sensitivity | Candidate macro specificity | Candidate kappa |
|---|---:|---:|---:|---:|---:|---:|
|Leukocytes|66.07%|75.00%|0.4248|0.4126|0.9033|0.5055|
|Nitrite|98.21%|100.00%|1.0000|1.0000|1.0000|1.0000|
|Urobilinogen|78.57%|83.93%|0.7538|0.7848|0.9139|0.5097|
|Protein|82.14%|84.82%|0.4004|0.3712|0.9160|0.4830|
|pH|66.96%|76.79%|0.3967|0.3963|0.9348|0.4748|
|Blood|86.61%|75.89%|0.3456|0.3773|0.9218|0.3903|
|Specific Gravity|69.64%|71.43%|0.6605|0.6578|0.9507|0.6374|
|Ketone|74.11%|75.89%|0.7605|0.7518|0.9200|0.5076|
|Bilirubin|83.93%|88.39%|0.8743|0.8690|0.9345|0.7488|
|Glucose|95.54%|94.64%|0.4316|0.4351|0.9136|0.5193|

Macro sensitivity/specificity use defined one-vs-rest denominators; absent reference classes are listed in JSON. These are category metrics, not disease detection. Nitrite-positive sensitivity is undefined when no positive reference exists; kappa is undefined for a single class.

## Whole-scan and coverage diagnostics

- development_baseline: individual 80.24%; all-ten 14.57%; vote-only acceptance 38.19%.
- development_selected: individual 82.41%; all-ten 17.00%; vote-only acceptance 53.42%.
- confirmation_baseline: individual 80.18%; all-ten 12.50%; vote-only acceptance 25.89%.
- confirmation_selected: individual 82.68%; all-ten 17.86%; vote-only acceptance 63.39%.

Vote-only acceptance is not the measured app retake rate: detection, absolute distance, timing, eligibility and safety gates are omitted. Confidence is kNN vote agreement, not a calibrated probability. Balanced votes change its meaning and need runtime validation before deployment.

## Review and deployment status

2108 failed prediction rows across baseline/candidate development/confirmation comparisons. Open ERROR_REVIEW.html locally for real pad crops and contexts; ERROR_REVIEW.csv has blank reviewer/adjudication fields. No reference corrections were invented.

Candidate models are development-trained comparison artifacts, not production exports. SELECTED_CONFIGURATION.json defines feature conversion, scaling, augmentation and optional sqrt inverse-frequency post-vote weighting; the pickles alone do not implement post-vote weighting. Any app replacement needs matching Dart feature extraction, support-envelope regeneration, parity tests, release build and device tests. Do not promote based on overall accuracy alone.

Feature comparison includes AWB versus raw color, normalized versus absolute circular HSV versus Lab, full/75%/50% inner crop, scaling, k=3/9/21, Manhattan/Euclidean and uniform/distance votes. The top three development settings also compare augmentation and class-prior weighting. Augmentation inherits labels and remains an assumption; it adds no independent biological information.

Reproduce: `.venv/Scripts/python pipeline/improve_direction_verified_knn.py`. Input/script hashes, real-image SHA256s, fold assignments, baseline extraction parity, predictions, ranked candidates, configuration lock and threshold-support/cluster-interval evidence are saved beside this report. Reproducing an already inspected confirmation set does not make it untouched.
