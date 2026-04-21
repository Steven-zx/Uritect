# RHU Field Collection SOP (Semiquant)

## Purpose
Collect urinalysis strip images with med-tech ground truth under controlled lighting for semiquant model training.

Current execution mode: 3-day offline-first collection. No immediate app ingestion during capture days.

## Scope
RHU collection using one phone mount, one dark box, and three single-source lights: 2700K, 4000K, 5500K.

## Roles
- Med Tech: dipstick handling and official strip reading
- Capture Operator: photo capture, naming, and logging
- Data Manager: transfer, integrity check, and delayed app ingestion after day 3

## Collection Plan (Locked)
- Duration: 3 days
- Daily participants: 30
- Per participant: 1 single image + 10 burst images
- Daily image target: 30 single + 300 burst = 330 total
- If collecting all 3 lights per participant, total scales accordingly

## Pre-Collection Setup
1. Confirm strip brand, model, lot, IFU revision, and read timing rule.
2. Prepare dark box with fixed phone slot and fixed lamp aim hole.
3. Verify only one lamp is on at a time.
4. Set fixed camera placement and disable zoom changes.
5. Open `rhu_sample_master_template.csv` and `rhu_image_log_template.csv`.
6. Create day folder on phone (`Uritect_D1`, `Uritect_D2`, `Uritect_D3`).

## Per-Sample Workflow
1. Create IDs:
   - `participant_id`
   - `sample_id`
   - `event_id` per light with day prefix (example: `D1-P001-S1-L2700`)
2. Med tech performs dip and reads all 10 analytes.
3. Manually encode med-tech levels into sample master row.
4. Place strip in box and confirm framing using fixed phone slot.
5. Capture sequence for that `event_id`:
   - 1 single image
   - 10 burst images
6. Manually rename files on phone using naming convention doc.
7. Log every file row in image log.
8. Mark `excel_row_status` after labels are encoded.
9. Run QC gate and mark `qc_pass`.
10. Repeat for next participant and next light condition if used.

## QC Gate (Mandatory)
Fail and recapture if any are present:
- blur
- glare/saturation
- strip not fully visible
- wrong orientation
- mixed lighting/shadow leak
- framing drift from mount reference

## Data Transfer and Security
1. Use de-identified IDs only (no patient names).
2. Keep files on phone during collection day while logs are being completed.
3. Transfer day batch to laptop only after day closeout checks.
4. If cloud transfer is used, use private storage and restricted access.
5. Record transfer status and timestamp in image log.

## Ingestion Handoff
1. Complete days D1 to D3 first.
2. Verify every image file has matching sample and image-log rows.
3. Verify each event has exactly 1 single + 10 burst frames.
4. Build ZIP package(s) in app only after the 3-day collection is complete.
5. Upload package(s) and archive logs with collection day tags.

## Daily Closeout Checklist
- Daily target count achieved (330 images unless scaled by light plan)
- Missing/duplicate filenames resolved
- CSV templates complete and saved
- Transfer status recorded
- Backup copy stored on laptop and secure drive
