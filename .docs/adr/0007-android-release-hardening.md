# 7. Android release hardening

Status: Accepted

## Context
The app works on local files only and needs no network. Plugins can inject permissions (for example
INTERNET), and Flutter templates fall back to debug signing for release builds.

## Decision
- The release manifest removes plugin-injected permissions, including `INTERNET`.
- `android:allowBackup="false"`; a network security config disallows cleartext traffic.
- compileSdk/targetSdk 36, minSdk 24, edge-to-edge UI.
- Release signing reads only the git-ignored `android/key.properties`; there is no debug-signing fallback,
  so a release build without the key fails instead of producing a debug-signed artifact.
- The app bundle is built with `--obfuscate --split-debug-info=...`.
- Keystores, `local.properties` and logs are never committed.

## Consequences
- Smaller attack surface; data cannot leave the device through the app or be backed up to the cloud.
- Release builds need the signing key locally or in CI secrets.
- Debug builds that need network access (hot reload) get INTERNET from the debug manifest only.
