# RHU Semiquant File Naming Convention

This naming is for the 3-day offline collection phase (manual rename on phone, manual Excel encoding, app ingestion later).

## Required Pattern
`<participant_id>_<sample_id>_<event_id>_<light_kelvin>K_<frame_role>_<frame_index>.jpg`

Example:
`P001_P001-S1_D1-P001-S1-L2700_2700K_burst_004.jpg`

## Token Rules
- `participant_id`: site-safe ID only (no patient name), e.g., `P001`
- `sample_id`: participant sample key, e.g., `P001-S1`
- `event_id`: one event per sample per light condition with day prefix, e.g., `D1-P001-S1-L2700`
- `light_kelvin`: must be one of `2700`, `4000`, `5500`
- `frame_role`: `single` for primary image, `burst` for burst frames
- `frame_index`: 3-digit zero-padded index (`001` to `010`)

## Enforcement Rules
- Use only ASCII letters, numbers, dash (`-`), underscore (`_`)
- No spaces
- Keep `.jpg` extension
- Do not rename after upload unless both CSV templates are updated

## Capture Sequence Rule
For each `event_id`:
1. Capture one `single` image (`frame_index=001`)
2. Capture ten `burst` images (`frame_index=001` to `010`)
3. Repeat per person/event with a new `event_id`

## 3-Day Target Rule
- Day target: 30 people
- Per person: 1 single + 10 burst
- Expected images per day: 30 single + 300 burst = 330 total images
- If all three lights are captured per person, multiply by 3 (990 images/day)

## Offline-First Rule
- Rename on phone immediately after capture
- Encode med-tech readings and analyte pad labels in Excel before any app upload
- Transfer to laptop only after the day batch is complete and checked

## Split Rule
- Split by `participant_id`, never by image
- All files from the same sample/event stay in the same split
