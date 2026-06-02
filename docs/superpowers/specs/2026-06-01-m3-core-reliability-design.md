# M3 Core Reliability Design

## Scope

This milestone repairs long-running scheduling, academic import replacement,
parser validation, and semester operation consistency.

## M3a Scheduling Reliability

- Android schedule refreshes cover the remaining semester instead of only the
  next 14 days.
- Other platforms retain the existing bounded scheduling behavior.
- Automatic mute availability requires Android, the user preference, DND
  access, and exact-alarm access.
- When exact-alarm access is unavailable, Dart emits manual mute reminders
  instead of native mute windows.
- Stored native mute windows remain recoverable across boot, package
  replacement, and exact-alarm permission changes.
- Native rescheduling keeps restoration work safe and falls back to manual
  reminders when a future mute can no longer be scheduled exactly.

## M3b Import Replacement And Parser Validation

- Courses and events persist an optional academic import source.
- Academic timetable imports replace the previous records from the same
  semester and source as a batch.
- Academic exam imports replace previous records from the same semester and
  source as a batch, including an empty result.
- Manual courses, manually created events, and records from other sources are
  preserved.
- Parser validation rejects unknown week expressions and invalid period
  ranges instead of fabricating week 1 or accepting malformed records.
- Partial timetable parsing returns accepted records plus skipped-record
  diagnostics so the UI can report skipped items.

## M3c Semester Consistency

- Semester creation, initialization, deletion, and switching are recoverable
  storage operations.
- The storage layer persists operation intent before multi-step mutations and
  resumes interrupted operations at startup.
- The provider layer exposes one semester-change callback so every entry point
  reloads courses and refreshes schedules consistently.
- Existing external backup synchronization remains the durable publication
  boundary after a completed operation.

## Verification

- Add focused Dart tests for schedule horizon, permission fallback, import
  batch replacement, parser rejection, and semester-operation recovery.
- Add focused JVM tests for native exact-alarm fallback policy.
- Pass full Flutter tests, static analysis, Web Release, Windows Debug, and
  Android debug Kotlin plus JVM tests.
- Run modified Dart formatting and `git diff --check`.
