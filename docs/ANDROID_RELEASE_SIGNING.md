# Android Release Signing

The signed URITECT release candidate APK is signed with a dedicated project release key. The key
and its passwords are intentionally excluded from Git by `.gitignore`.

## Local Files

- Signing properties: `uritect_app/android/key.properties`
- Active keystore: `uritect_app/android/keystore/uritect-release-v2.jks`
- Alias: `uritect`

Do not commit either local file. Back them up together in a secure, encrypted
location controlled by the research team. Losing the keystore or passwords
prevents future APKs from updating an installed release with the same
application ID.

## Build Behavior

Debug builds remain available without the release key. Release APK and app
bundle tasks fail when `key.properties` is missing, preventing an accidental
unsigned or debug-signed production artifact.

## Frozen Release Identity

- Application ID: `ph.edu.wvsu.uritect`
- Current candidate: `1.4.1` (`versionCode 14`); verify its actual signature and hash in
  `output/release/URITECT_FINAL_RELEASE_MANIFEST.json`. Earlier versions are historical.
- Signing certificate SHA-256:
  `15D1138DCE077ADA624A140B3A145343D1A48305FD0847E9002869E488F19D39`

The private key itself is not part of the repository or release package.

Debug pilots may use a different signing key from the release. Do not uninstall or clear
research data automatically when Android rejects a signed update. Export/preserve records
and agree the migration with the user first. Source snapshots exclude signing properties
and both keystores. The release key is required to rebuild/update the signed candidate.
