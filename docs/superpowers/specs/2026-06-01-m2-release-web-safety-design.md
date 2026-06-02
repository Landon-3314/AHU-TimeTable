# M2 Release And Web Safety Design

## Scope

This milestone restores a trustworthy release path and makes the existing Web
scaffold buildable without exposing Android APK installation behavior.

## Version Monotonicity

- Bump the next candidate to `0.3.6+3`.
- Treat the build number after `+` as the globally increasing Android
  `versionCode`.
- Add a small Python verifier that rejects a candidate build number less than
  or equal to every supplied published manifest.
- Run the verifier against the checked-in manifest and the latest GitHub
  Release manifest before building release assets.

## Release Signing

- Remove Gradle's silent debug-signing fallback for Release tasks.
- Reject Release builds when any keystore value is missing.
- Require CI to receive the complete signing secret set and an expected
  SHA-256 certificate fingerprint.
- Verify the decoded keystore fingerprint before building.
- Verify every generated APK fingerprint after building.
- Download the previous public arm64 APK when a previous release exists and
  require its fingerprint to match the new APK fingerprint.

## CI Quality Gates

Before APK generation, run:

1. `flutter analyze`
2. `flutter test`
3. `flutter build web --release`
4. candidate `versionCode` monotonicity verification
5. signing secret and keystore fingerprint verification

Release creation and manifest publication occur only after all gates pass.

## Web Platform Boundary

- Keep shared update HTTP response types in a platform-neutral library.
- Select the default HTTP client with conditional imports:
  - Android IO builds prefer Cronet and fall back to `IOClient`.
  - Other IO builds use `IOClient`.
  - Web builds use `http.Client`.
- Remove `dart:io` use from manifest loading by using portable headers and
  exceptions.
- Keep the existing Android-only `AppUpdatePlatform.isSupported` gate for APK
  download and installation. Add further Web stubs only if Web compilation
  proves they are needed.
- Web never reaches a working APK install path.
- Keep the existing Android and desktop IO behavior unchanged.

## Verification

- Existing Flutter tests remain green.
- Add verifier unit tests for increasing, duplicate, and regressed build
  numbers.
- `flutter build web --release` succeeds.
- Android debug Kotlin compilation and JVM tests remain green.
- A local unsigned Release build fails closed with a clear signing message.
- Modified Dart files are formatted and `git diff --check` passes.
