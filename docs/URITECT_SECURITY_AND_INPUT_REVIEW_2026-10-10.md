# QA remediation — URITECT 1.5.0+16

This update addresses the source-review findings in the current Acer checkout.
The changes are engineering safeguards, not evidence of clinical validation.
Earlier signed builds and their evidence remain historical artifacts.

## What changed

The follow-up QA screenshots describe the same concerns. In this build the entire
protected history payload includes urinalysis categories, symptoms, clinical
outputs, scan/analysis timestamps, provenance, and historical estimates. Saved
dipstick photos are encrypted separately with the same platform-backed protection.
The bundled model and rule code remain ordinary app assets/code; encrypting them
would not protect a user's records or validate the classifier.

| Follow-up finding | Disposition in this build |
| --- | --- |
| Low all-ten accuracy | Disclosed separately from analyte accuracy; independent abnormal-class data/evaluation still required |
| Unvalidated Bayesian assumptions | Provisional research language retained; numerical tables unchanged; expert approval does not establish calibration |
| High confidence on unfamiliar colors | Absolute training-distance guard added; prospective rejection validation still pending |
| Missing reliability metadata | Exact unique analyte set and complete safety evidence required; legacy archives remain unverified |
| Reused photos and self-reported timing | Source, known-duplicate flags and timing recorded; biological freshness is not authenticated |
| Unencrypted saved local history | Authenticated encryption and device-credential history access added; legacy migration must complete successfully |
| Non-atomic history saves | Serialized staged writes, verified recovery and visible corruption handling added and fault-tested |

### Image provenance and repeat submissions

Camera and gallery sources are recorded separately. Analysis date is never
presented as proof of specimen collection or gallery-photo age. Before analysis,
the user can record a non-identifying study/specimen code, seconds after dipping,
and a current-specimen/required-reading-time confirmation. Unknown information
permits image review and the safety checklist, while withholding current-result
Bayesian and analyte-dependent renal interpretation. Symptom safety advice remains.

The app hashes file bytes and orientation-corrected decoded pixels. Either exact
match against available saved history flags a repeat for review only. A small
perceptual fingerprint produces an advisory; similarity alone does not establish
reuse and must not reject a genuinely different specimen. History comparison
requires unlocking protected storage; older records without provenance hashes
use exact saved-file matching. Metadata/container changes to such older photos
may evade that comparison. Cancellation, corruption or unavailable
keys cannot silently count as a successful duplicate check.

EXIF dates are explicitly unverified. An earlier reported date prevents treating
that import as a current specimen. Missing or edited metadata, rephotographed
prints/screens, altered or recompressed images, unsaved/deleted records, and
incorrect self-report cannot be ruled out by this mechanism. The code records
provenance and contradictions; it does not authenticate a biological specimen.
Manufacturer-specific reading times and lot/expiry still require the physical
strip protocol and qualified review; no new reaction time is invented here.

### Confidence and training support

The existing model vectors, labels, neighbour settings, vote confidence and 0.45
confidence threshold are unchanged. The new separate support-policy asset is
bound to the model's SHA-256. For each analyte, its engineering radius is the
maximum nearest-distinct-vector distance obtained by leaving out one unique
training vector at a time, using the exact production metric and transformed
feature space. Duplicate vectors are removed when deriving the radius. The
generator uses training vectors only; test outcomes and phone photos do not
select this threshold.

At inference, the closest training distance must be finite and within this
envelope even when neighbour votes agree. Unsupported colors reject the entire
interpretation with `OUTSIDE_TRAINING_SUPPORT`, retaining the measured ten-pad
localization count and retake guidance. Accepted scans record all ten distances.
Model/policy mismatches fail closed. A large training outlier can produce a broad
radius; an unfamiliar sample inside this envelope can still pass. This is not a
validated clinical out-of-distribution detector. Independent abnormal specimens,
predefined sensitivity/specificity and acceptance/retake criteria, and uncertainty
intervals remain required to validate a final rejection policy.

### Strict reliability and archives

Technical reliability requires exactly ten unique expected analyte code/name
pairs, ten pads detected and zero unavailable, finite overall confidence, all ten
per-analyte confidences above the existing threshold, and all ten successful
training-support checks with finite non-negative distances. Fractional pad counts
are not truncated into valid counts. Missing evidence fails closed.

Current-result use additionally requires provenance, a completed duplicate check,
and the specimen/timing confirmation described above. Older records remain
readable as **unverified archives**. Their historical estimates are shown as
recorded, not reconstructed or presented as newly verified measurements.

### Protected and recoverable history

The Android implementation uses AES-256-GCM with fresh nonces, authenticated
context and an AndroidKeyStore key requiring device-credential authentication.
Photos, the history index and deletion journal are protected; keys are not written
into Dart files or exported into the history directory. A device PIN, pattern or
password is required to unlock or save history. Cancelling a save still allows
unsaved results and the safety checklist.

History starts locked, hides on background/inactive transitions, and hides before
the two-minute credential session expires. Saved-result and child renal-detail
screens each use the history guard. Android's secure-window flag protects saved
history screenshots and recent-app previews. No network permission is added.
Cloud backup and device-transfer exclusions cover app records and metadata; they
do not imply a portable encrypted backup feature. These choices follow
[AndroidKeyStore documentation](https://developer.android.com/privacy-and-security/keystore)
and [Android backup guidance](https://developer.android.com/identity/data/autobackup).

Writes are serialized, flushed to a staging file and committed by rename. A
verified prior encrypted index is retained for recovery. Corrupt primary data can
recover the previous copy with a visible warning that recent changes may be
missing, while preserving the damaged file. If neither copy can be verified,
loading/saving reports an error and preserves the files; it does not return an
apparently empty history. A protected deletion journal prevents an older recovery
index from resurrecting a deleted record. Invalid journals fail closed.

On first successful unlock, valid legacy records and private stored photos are
migrated. Both indexes and existing photos are checked before plaintext removal.
An interrupted migration is verified and resumed; malformed or conflicting legacy
data are preserved and saving is blocked. Therefore damaged legacy plaintext may
remain pending recovery; migration is not falsely claimed to have completed.
Camera/Gallery originals outside app storage are not deleted or encrypted by this
app. Uninstalling, clearing app data or changing/removing device credentials may
make protected history unavailable. Do not reset keys to hide a decryption error.
This does not claim protection against a fully compromised unlocked device.

### Accurate claims and Bayesian framing

The home information button opens research performance and limits:

| Historical cached-feature development measure | Value |
| --- | --- |
| Individual-analyte exact-category accuracy | 82.52% (1,345/1,630) |
| Entire ten-pad exact-category accuracy | 17.18% (28/163 scans) |
| Entire ten-pad accuracy among confidence-filtered scans | 19.17% |

These are different quantities, not disease-detection accuracy or independent
performance claims for this APK. Related captures crossed development partitions
and results informed tuning. Existing collection/error-review requirements remain.

Bayesian priors, likelihood ratios and clinical rule tables are unchanged. The app
retains provisional literature-derived screening language and explicitly discloses
female symptom/dipstick multiplication, male branch validity and prior/LR
transportability, and absent local culture-confirmed calibration. MedTech/physician
content approval and ISO/IEC 25010 usability review are valuable but do not replace
statistical review or prospective outcome validation.

## Verification and remaining acceptance

Automated evidence is recorded beside the signed APK in
`output/device_pilot/2026-10-10/1.5.0+16/`. It covers strict gates, known duplicate
hashes versus similarity, training-policy regeneration and metric checks, damaged
indexes and photos, interrupted saves/migration, concurrent saves, deletion
recovery, locked history lifecycle and protected child navigation. Flutter mock
transport tests exercise persistence and UI; they do not prove AndroidKeyStore
hardware behavior. Development image regression includes previous real-image
fixtures and the RMX white-background failure reproduction. It is not an untouched
clinical test set.

Before using this build for the evaluated pilot, record on RMX3933 and a second
Android phone: credential cancel/retry, first unlock of existing history, encrypted
index/photo inspection, app background/foreground, session expiry, child renal
history lock, screenshot blocking, airplane-mode operation, record save/read/delete,
and backup exclusions. Also run the existing camera/gallery, quality, safety and
latency matrix. The automated checks passed: 119 Flutter tests, 35 Python tests,
clean static analysis and native compilation. The 18 development photos retained
all six previously accepted scans with identical category predictions. The RMX
subsequently connected at `192.168.1.37:41885` (Android 16). Version 1.5.0+16 was
installed in place without clearing app data. Its installed APK SHA-256 matches
the sealed release, and a cold launch succeeded. Installation evidence is in
`INSTALLATION.json`; the app-scoped error-log check returned no error entries.
Native authentication, migration,
two-phone acceptance and human sign-off are not inferred from a successful
installation. Physical strip IFU details and independent
clinical/statistical validation remain pending.
