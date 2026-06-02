# M2 Release And Web Safety Implementation Plan

## Task 1: Make Update HTTP Portable

- [ ] Split default update HTTP client creation behind a conditional import.
- [ ] Keep Cronet on Android IO builds and use `http.Client` on Web.
- [ ] Remove `dart:io` from update manifest loading.
- [ ] Re-run the Web Release build to reveal the next platform boundary.

## Task 2: Confirm Android-Only File Features Stay Unreachable On Web

- [x] Verify the existing `AppUpdatePlatform.isSupported` Web guard.
- [x] Build Web Release after isolating Cronet.
- [x] Keep file-feature APIs unchanged because the successful Web build proves
  that additional placeholder layers are unnecessary.

## Task 3: Enforce Monotonic Versions

- [ ] Add verifier unit tests for increasing, duplicate, and regressed build
  numbers.
- [ ] Implement the verifier.
- [ ] Bump `pubspec.yaml` to `0.3.6+3`.
- [ ] Add the verifier to Release CI before APK generation.

## Task 4: Fail Closed On Release Signing

- [ ] Remove Gradle's silent debug-signing fallback.
- [ ] Require all CI signing secrets and the expected certificate fingerprint.
- [ ] Verify the decoded keystore fingerprint.
- [ ] Verify generated APK fingerprints and adjacent public APK continuity.
- [ ] Confirm an unsigned local Release build fails clearly.

## Task 5: Verify The Milestone

- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter build web --release`.
- [ ] Run Android debug Kotlin compilation and JVM tests.
- [ ] Run verifier unit tests.
- [ ] Run modified Dart formatting and `git diff --check`.

## Execution Notes

- Execute inline because no subagent delegation was requested.
- Do not publish, commit, or modify GitHub secrets from the local workspace.
- Preserve M1 changes and the user-provided root `problem.md`.

## Execution Result

- Added conditional update HTTP client creation. Android IO builds retain
  Cronet with `IOClient` fallback, while Web uses `http.Client`.
- Passed `flutter build web --release`, including the Wasm dry run.
- Added and passed three Python verifier tests for increasing, duplicate, and
  regressed Android build numbers.
- Bumped the release candidate to `0.3.6+3`.
- Added CI analysis, Flutter tests, verifier tests, Web build, version
  monotonicity checks, signing secret validation, keystore fingerprint
  validation, APK fingerprint validation, and previous public APK continuity
  validation.
- Confirmed unsigned local Release configuration fails closed with a clear
  message.
- Passed `flutter test`: 94 tests.
- Passed `flutter analyze`: no issues.
- Passed Android Debug Kotlin compilation and 7 JVM tests.
- Passed Windows Debug and Web Release builds.
- Passed YAML parsing, Bash syntax checking for 14 CI run steps, modified Dart
  formatting, and `git diff --check`.
