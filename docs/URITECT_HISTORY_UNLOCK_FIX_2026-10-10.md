# History unlock correction: 1.5.1+17

The RMX3933 user reported HISTORY_LOCKED after attempting to unlock saved history in 1.5.0+16. That error did not establish damaged records. Neither app data nor AndroidKeyStore keys have been cleared.

## Changes

- Prepare or retrieve the original `uritect_history_v1` key before asking for credentials. Previously, a first-save or legacy-migration operation could generate the authentication-bound key after the credential interaction.
- On Android 11 and later, use the platform BiometricPrompt with DEVICE_CREDENTIAL exclusively, matching the key's credential authentication requirement. Older devices retain the framework credential-intent fallback. USE_BIOMETRIC is the normal permission required by that platform API; this prompt requests a PIN, pattern or password.
- After successful credential confirmation, verify an in-memory AES-GCM encrypt/decrypt probe with the same key before reporting an unlocked session to Flutter. A prompt result alone no longer establishes key authorization. The probe contains no health records and writes no files.
- Invalidate the displayed session after a protected-operation error or cancelled authentication. Distinguish locked, unavailable-key and integrity errors in the user-facing message.
- Native diagnostic logs contain the exception class and operation stage only, with no records, images, keys or credentials.

Android recommends the allowed-authenticator API for credential authentication: [Android authentication guidance](https://developer.android.com/identity/sign-in/biometric-auth). Authentication-bound key operations can fail when authorization is missing: [KeyGenParameterSpec.Builder](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec.Builder).

The original key alias, encrypted envelope, authenticated contexts, two-minute session, screenshot protection, backup exclusions and verified atomic migration format remain compatible. No replacement key is generated when an existing key cannot be retrieved. Actual key invalidation or corrupt records remain recovery problems, rather than reasons to discard health data.

## Acceptance

New Flutter tests cover operation failure clearing the session, cancelled reauthentication clearing an earlier session, and distinct readable error messages. Native compilation and the full Flutter suite are required before release. Physical-device confirmation requires the user to enter their credential on the phone. A successful build or installation alone does not establish that history unlock or migration works on RMX.

Verification completed: 122 Flutter tests passed; static analysis clean; native release Kotlin compilation passed; signed release APK built. A test-only unused import was removed after the passing suite, with no executable code change. The final source archive preserves that correction and the pre-lint archive is retained separately. The installed APK on RMX3933 (Android 16) was verified byte-for-byte against the sealed release and launched successfully. In-place installation retained app data. Native credential unlock and migration remain pending the user's retry.

Release evidence: `output/device_pilot/2026-10-10/1.5.1+17/`. APK SHA-256: `2997501B02EAF5C1E812165E4B4BA080E9B58BE102D23366446ABCA034CC74CB`.

On the exact updated APK, record: cancel then retry; unlock existing history and verify expected records; open a record/photo; background and return; unlock again; session expiry; and save/read/delete a disposable test record. Do not expose a PIN, clear app data, uninstall the app, or reset keys to diagnose an unlock error.

Classifier assets, predictions, Bayesian tables and the previous development accuracy evidence are unchanged by this authentication fix.
