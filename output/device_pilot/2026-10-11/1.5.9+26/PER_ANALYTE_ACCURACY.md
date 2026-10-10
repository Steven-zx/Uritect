# Corrected-model per-analyte development accuracy

Installed build: 1.5.9+26. Classifier and support policy are unchanged from 1.5.8+25. These are the corrected candidate evaluation figures; numerical-result retention does not constitute retraining or an accuracy gain.

| Analyte | Accuracy | Correct / evaluated |
|---|---:|---:|
| Leukocytes | 66.95% | 79 / 118 |
| Nitrite | 100.00% | 118 / 118 |
| Urobilinogen | 73.73% | 87 / 118 |
| Protein | 79.66% | 94 / 118 |
| pH | 76.27% | 90 / 118 |
| Blood | 88.98% | 105 / 118 |
| Specific Gravity | 63.56% | 75 / 118 |
| Ketone | 73.73% | 87 / 118 |
| Bilirubin | 79.66% | 94 / 118 |
| Glucose | 96.61% | 114 / 118 |

Individual-analyte accuracy: 79.92% (943/1180).
All-ten exact-category accuracy: 13.56% (16/118).

Nitrite evaluation labels were 118 negative and zero positive examples, reconstructed from the same deduplicated CSV and GroupShuffleSplit(test_size=0.2, random_state=42). Its 100% accuracy therefore does not establish positive-result sensitivity.

Exploratory development evaluation on a changed direction-verified subset. Not directly comparable to the historical 82.52%/17.18% figures, not disease-detection accuracy, and not an independent phone/clinical validation. Related lighting captures may cross development groups. No accuracy improvement is claimed for 1.5.9+26.

Source: pipeline/output/orientation_audit_2026-10-11_v3/candidate_grouped_evaluation.json
