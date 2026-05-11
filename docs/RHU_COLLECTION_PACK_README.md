# RHU Collection Pack

Use these files together during field capture:

1. `pipeline/dataset/templates/rhu_sample_master_template.csv`
2. `pipeline/dataset/templates/rhu_image_log_template.csv`
3. `docs/RHU_SEMIQUANT_FILENAME_CONVENTION.md`
4. `docs/RHU_FIELD_COLLECTION_SOP.md`

## Recommended Flow
1. Capture and rename images on phone (offline) for days D1 to D3.
2. Manually encode med-tech readings and analyte levels in sample master.
3. Log every file row in image log and complete QC flags.
4. Transfer daily batch to laptop after closeout checks.
5. Build app packages only after day-3 completion.

## Locked 3-Day Targets
- 30 participants/day
- Per participant: 1 single + 10 burst
- Daily target: 330 images (30 single + 300 burst)

## RHU170 Implementation (Semiquant, Participant-Level Train/Val)
Use this flow when you already have med-tech semiquant labels in sample master.

1. Create participant-level split manifests (leakage-safe split):

```powershell
python pipeline/create_participant_split_manifest.py \
	--sample-master "pipeline/dataset/rhu_sample_master.csv" \
	--participant-out "pipeline/dataset/participant_split_manifest.csv" \
	--event-out "pipeline/dataset/event_split_manifest.csv" \
	--val-ratio 0.25 \
	--seed 42
```

2. Build semiquant package ZIP from sample master + image log + transferred images:

```powershell
python pipeline/build_semiquant_training_package.py \
	--sample-master "pipeline/dataset/rhu_sample_master.csv" \
	--image-log "pipeline/dataset/rhu_image_log.csv" \
	--images-dir "C:/data/rhu_transferred_images" \
	--split-manifest "pipeline/dataset/event_split_manifest.csv" \
	--batch-id "RHU170_SEMIQUANT_V1" \
	--recursive-images
```

3. Ingest and validate before training:

```powershell
python pipeline/ingest.py
python pipeline/validate_semiquant_labels.py --strict
python pipeline/check_training_readiness.py --json
```

4. Train and evaluate:

```powershell
python pipeline/train.py --enforce-readiness
python pipeline/evaluate_semiquant.py
```
