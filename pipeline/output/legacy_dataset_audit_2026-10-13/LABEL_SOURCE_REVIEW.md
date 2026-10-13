# Reference-value search and preservation

The per-analyte values are present in this project. Their availability and their
traceability are separate checks. No original binary value, supplied category,
raw photo, archive, or installed model is changed by this audit.

| Collection | Reference found | Treatment |
|---|---|---|
| RHU175 | `pipeline/dataset/URITECT_DATASET_locked_v1.csv`, with 175 within-batch IDs; matching package indexes and derived sample-master CSVs | Use complete matching supplied references after duplicate/conflict and image checks. |
| Cabatuan 2026-07-15 | Supplied Labels XLSX, 38 IDs | Preserve supplied per-pad readings; match photo folders to IDs. |
| Cabatuan 2026-07-17 | Supplied Labels XLSX, 48 IDs | Preserve supplied per-pad readings; unmatched folders do not gain invented labels. |
| Laua-an 2026-07-30 | `new_uritect_dataset/uritect_2026-7-30_Laua-an/uritect_2026-7-30_Laua-an_Labels_cleaned.csv`, 261 IDs | Use recorded categories; the XLSX is an empty template rather than an alternative set of readings. |
| Original BATCH controls | Original event indexes and manifests contain Normal/Abnormal labels | Keep the binary values byte-for-byte unchanged. Photos can support acquisition/geometry research. |
| Converted BATCH exports | `pipeline/dataset/features.csv`, other historical feature CSVs, and `*_SEMIQUANT_FROM_BINARY.zip` indexes contain per-pad category values | Preserve these values too. No separate original per-pad reading sheet for these controls was found in the searched project CSVs or original event manifests. These converted references do not enter the semiquantitative training pool. |
| COLORWHEEL | Working-copy CSVs, historical feature CSVs, and package indexes contain category values | Source photos show a printed chart. Original multianalyte CSV notes describe cyclic assignment from chart vocabulary; working copies say REVIEW_ME. Preserve as reference material, not labeled specimen observations. |

The search included all project CSVs mentioning BATCH, the original external
training manifest and event CSVs, archive indexes, gold development/holdout
feature tables, label-validation code, sample-master CSVs and source label
files. A syntactically valid category does not establish a laboratory reading.

Four unique RHU photos are reused under IDs with conflicting reference values.
They are quarantined from training; neither label is selected using the model's
prediction. Duplicate exports and burst frames do not create new biological
specimens. Counts of within-batch IDs are not verified independent-patient
counts, and cross-batch identity remains uncertain.

The user explicitly instructed that binary values must never be touched. The
protected-input snapshot and final source-integrity check cover original CSVs,
source archives and current model assets. All crop images, annotations and
feature outputs are written into a separate versioned audit directory.
