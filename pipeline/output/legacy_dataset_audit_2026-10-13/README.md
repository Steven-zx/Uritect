# Legacy-data audit artifacts

Use **REPORT.md** and **FINAL_SUMMARY.json** for the completed audit. SUMMARY.json
is an earlier proposal-stage result, not the final admitted training pool.

The current app/model and all binary values are unchanged. Of 2,028 unique
images, 210 qualify for the versioned pool, including six RHU175 photos.
Neither cleaned-current nor cleaned-plus-legacy models qualified for promotion
on the predeclared paired grouped comparison. There is no new APK or version.

- `LABEL_SOURCE_REVIEW.md`: where recorded categories were found, with source limitations.
- `PHOTO_REVIEW.html` and `FINAL_PHOTO_AUDIT.csv`: private local image/crop atlas and every disposition.
- `CLEAN_FEATURES.csv` and `cleaned/`: private derived feature rows and lossless processing-scale crops; original files remain intact.
- `DEVELOPMENT_COMPARISON.json` and `FIVE_METRICS.csv`: all three arms, five per-analyte metrics, class/rule support and promotion decisions.
- `SOURCE_INTEGRITY.json` and `VERIFICATION.json`: unchanged inputs, automated checks and sampled visual review.

The earlier tight-crop diagnostic failed; it is retained locally for traceability.
Context crops preserve real background, the complete strip and the handle.
They never synthesize pads, change reference labels or lower production gates.
An archival crop passing checks does not demonstrate acceptance of its uncropped
original by the app. Failure to confirm a boundary is not proof of an invalid
specimen or a request to delete its photograph.

## Reproduction

Owner raw archives and supplied reference files are required. Choose a new
output directory to avoid overwriting recorded inventories or comparison
metrics. Paths and private manifests remain local and are excluded from Git.

1. Run `audit_legacy_dataset.py --phase inventory`, then `verify_legacy_sources.py snapshot` and `audit_legacy_dataset.py --phase audit`, all with the same `--out` directory.
2. Run `audit_unpacked_references.py` for unpacked originals (its default output is this dated directory).
3. Run `prepare_legacy_runtime_audit.py --out ...`, then run its generated Flutter diagnostic test with `LEGACY_RUNTIME_MANIFEST` pointing to that directory's RUNTIME_MANIFEST.json.
4. Run `prepare_legacy_runtime_audit.py --context-crop --out ...`, then run the separate generated context-crop diagnostic against RUNTIME_CONTEXT_CROP_MANIFEST.json.
5. Finalize with `finalize_legacy_runtime_audit.run(out)`. This combines native extraction and independent direction, spacing, background-presence, color-boundary and focus checks.
6. Run `evaluate_legacy_expansion.py --out ...`. Original confirmation groups and known related identity tokens stay outside model selection; no confidence/hyperparameter search is performed.
7. Verify inputs with `verify_legacy_sources.py verify --out ...`, generate the aggregate report with `write_legacy_audit_report.run(out)`, and run `python -m unittest discover -s pipeline -p 'test_*.py'`.

Helpers with no output CLI accept `run(out)` when imported from the pipeline
directory. Independent final clinical validation is not established by
reproducing this retrospective development experiment.
