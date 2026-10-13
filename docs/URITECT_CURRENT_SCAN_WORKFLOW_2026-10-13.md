# Current scan workflow and reference legend — 1.5.17+35

This version supersedes the 1.5.16 reading-display and automatic-save behavior. It does not retrain the classifier or establish improved accuracy or clinical validation.

## Changes

- Actual available model categories remain visible in Dipstick Results and the summary measurements drawer. Confidence, timing or missing verification evidence adds a secondary **Low confidence**, **Provisional** or **Unverified** label. An absent output is not reconstructed from the legend or reference range. Invalid scans with predictions carry a prominent preliminary warning.
- Teal secondary buttons use a 1.5 px border, teal text/icons, rounded shapes and a consistent minimum tap height. Summary actions stack on narrow screens or large text.
- Current capture, gallery import, analysis, checklist completion, summary and checklist editing do not request history authentication. Authentication remains on explicit saved-history access and protected record operations.
- Checklist editing opens a populated checklist, retains the original scan ID and predictions, returns revised answers, and recalculates the existing screening and renal rules. Same-ID saves update one record. Existing patient names are preserved when the pending update is merged.
- An expandable **Dataset level reference** lists categories from `pipeline/semiquant_schema.py`. It is a category guide, not a verified color chart or normal-range guide. The owner will supply the actual chart later. No artificial swatches, replacement labels, classifier input or thresholds were introduced; `REVIEW_ME` color-wheel CSVs remain unverified working copies.

## Prompt-free saving without unlocking old records

`ScanHistoryService.queueCompletedScan` serializes the completed record and photo into a write-only encrypted inbox. Android creates a separate RSA-2048 Keystore private key restricted to credential-authorized decryption. Its exported public key wraps a fresh 256-bit AES key; AES-GCM seals the record/photo with a random nonce and scan-ID-bound context. The existing authenticated AES history key and ciphertext format remain unchanged. No private key is exported.

Sealing requires a configured device screen lock, but does not display a credential prompt. If sealing fails, current results remain usable for review and the app reports that saving failed. Inbox envelopes use atomic staged writes; checklist edits replace the envelope for the same ID.

Explicitly opening history authenticates first, verifies all pending envelopes and identities, creates encrypted photos, upserts the protected index, then removes committed inbox envelopes. Cancelled authentication, unavailable keys or malformed envelopes preserve the original files. The encrypted deletion journal prevents a queued update from resurrecting a deleted ID. An interrupted initial envelope is recovered only after authentication. These envelopes are encrypted saved health data and are included in the app's existing backup-exclusion policy.

Native implementation follows the Android [Keystore](https://developer.android.com/privacy-and-security/keystore) and [cryptography](https://developer.android.com/privacy-and-security/cryptography) guidance. Host transport tests exercise the persistence protocol, not Android's hardware/credential authorization; actual device acceptance remains necessary.

## Duplicate checks and clinical gates

Current scans never unlock old records to check duplicate photos. A memory-only index contains opaque record IDs and verified image hashes, without names, symptoms, results or photos. It can be populated by explicitly opening history or by sealing scans in a session that has a complete index. It is invalidated when the protected files change.

After an app restart with existing saved records, the index may be unavailable until history is explicitly opened. In that case, scanning still proceeds without a password, but duplicate checking is marked incomplete and current-specimen calculations remain unavailable. The app does not silently claim that an unchecked photo is new. This conservative limitation is intentional; an unauthenticated API for reading protected records was not added.

Confidence thresholds, unique-analyte checks, orientation, training support, image-quality checks, per-pad timing, specimen metadata, eligibility and serious-symptom gates remain unchanged. Showing a prediction does not authorize its use by the clinical engines. Bayesian percentages remain available only when the existing engine can calculate them, in optional Research Details with research framing. No diagnosis or calibrated probability is claimed.

## Verification and remaining acceptance

Current test counts, static analysis, source/core guard and signed APK identity are recorded in the versioned build receipt. Automated tests cover no-prompt sealing, same-ID updates, authentication before history reads, photo round trips, cancellation/corruption preservation, interrupted writes, deletion protection, duplicate-cache invalidation, restored checklist answers and edits, preliminary predictions, timing labels and small-screen actions. Real-font reading and summary previews are inspected.

Before pilot use, test an in-place APK update on the RMX: complete two scans without credential prompts; edit a checklist; explicitly unlock history; confirm updated answers and photos; background/reopen history; restart and verify the conservative duplicate-check notice; cancel an unlock; verify device-lock setup errors preserve current results. Do not uninstall or clear data/Keystore keys. No current-build phone pass, expert approval, color-chart verification or clinical validation is inferred from automated tests.
