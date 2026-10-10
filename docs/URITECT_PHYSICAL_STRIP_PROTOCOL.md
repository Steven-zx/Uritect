# Physical URS-10T strip protocol — pending IFU confirmation

Status: **not finalized**. User deferred these details on 2026-10-06 and asked to be asked
again next session. No manufacturer, lot, expiry or reading times have been guessed.

This protocol reconciles the frozen app with the actual physical product. "URS-10T" alone
does not identify a manufacturer-specific category chart or IFU.

## Record before specimen collection

Enter manufacturer, full product name, catalogue number, lot, expiry, opening date,
storage conditions, IFU revision/language and photos/scans of bottle, carton, category chart
and complete IFU in the acceptance record. Keep participant identifiers out of screenshots.
Record specimen ID, participant pseudonym, collection time, sample handling, immersion time,
removal time, excess-urine removal method, read/photo time and light/device for each capture.
Follow the exact IFU for immersion, blotting, positioning, mixing and timing.

## Reconcile pad order, categories and units

The current model order is:
Leukocytes, Nitrite, Urobilinogen, Protein, pH, Blood, Specific Gravity, Ketone, Bilirubin, Glucose.
This is the algorithm's pad-stack order; verify its physical direction relative to the handle
using the actual strip and ten-pad overlay. Do not assume list order proves bottle alignment.

`APP_STRIP_MAPPING.json` beside the release records the actual model's observed training labels.
It is not the manufacturer's full chart: absent training categories may still exist on the IFU.
For each pad, two MedTechs must transcribe all IFU levels/units, match each app label, flag missing
or ambiguous classes and verify blood hemolyzed/non-hemolyzed distinctions.

The app currently treats protein/blood as 60-second checks through Urs10TProfile and the
`read_outside_60_seconds` quality question. That is an implementation assumption awaiting IFU.
Other pads do not have verified per-pad reading-time enforcement or independent timers.
The app does not automatically recognize manufacturer/lot/expiry or verify reaction time.

Record **all ten** manufacturer reading times and tolerances in seconds. If pads require
different reading times, a single photo at an assumed 60 seconds cannot be declared valid
for all ten. Decide with the MedTechs whether sequential captures, timed per-pad extraction,
or restricted reporting is required. If the IFU conflicts with current timing or mappings,
this frozen candidate fails the physical-strip gate and must be revised under a new version.
Do not change the protocol to fit the app.

## Review/sign-off

Two qualified MedTechs independently check product identity, physical pad order, chart levels,
units, sample handling, reaction timing and reference-label adjudication.
Record disagreement and resolution, names/credentials, dates, signed evidence and the exact
APK SHA-256. Only mark `confirmed_matches_frozen_app` after every mismatch is resolved.
A physician reviews output wording and safety separately; usability review does not replace
strip/IFU verification. No clinical deployment or final clinical accuracy claim is justified
by an incomplete physical-strip record.
