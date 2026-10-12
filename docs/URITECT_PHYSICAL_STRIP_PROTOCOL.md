# Physical URS-10T strip protocol — pending IFU confirmation

Status: **partially recorded; IFU confirmation pending**. On 2026-10-12 the owner supplied
URS-10T, lot `2026051201`, dates `5-12-2026` and `5-11-2028`, and the label claim
`anti-vc interference ability`. See [the structured strip record](URITECT_PHYSICAL_STRIP_RECORD.json).
The owner confirmed manufacture **2026-05-12** and expiry **2028-05-11** (M-D-YYYY).
The owner reports no manufacturer printed on the bottle. Product/lot/dates and the
following transcribed time schedule are recorded; manufacturer/chart/IFU evidence and
signed reconciliation remain unverified.

| Pads | Owner-reported reading time |
|---|---:|
| Bilirubin, Glucose | 30 seconds |
| Ketone | 40 seconds |
| Specific Gravity | 45 seconds |
| Leukocytes, Nitrite, Urobilinogen, Protein, pH, Blood | 60 seconds |

The app's restricted reporting now compares the recorded time with each pad's target.
No tolerance was supplied, so none is invented. A time match is self-reported schedule
consistency, not measured reaction validity or independent IFU verification. At 60 seconds,
the four earlier pads remain numerical image-review values and cannot be treated as
correctly timed current results. To obtain photographs at all scheduled points, use
separate 30/40/45/60-second captures with the same specimen code; the app does not merge
them into a verified ten-pad composite. Practice alignment before dipping. Whether a
sequential capture protocol is acceptable still requires qualified physical-strip review.

An anti-vitamin-C label claim does not establish unrestricted immunity to interference.
Its affected pads and tested ascorbate concentrations require the exact manufacturer's IFU.
Evidence from other products must not be substituted for this lot's limits. General dipstick
interference is documented in [a multicenter clinical study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6816989/),
which used a different strip and does not validate this URS-10T product.

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
All ten pads now have checks against the owner's reported schedule. No independent
reaction timer or manufacturer-verified tolerance is implemented.
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
