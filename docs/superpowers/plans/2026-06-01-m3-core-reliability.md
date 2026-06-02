# M3 Core Reliability Implementation Plan

## Task 1: Extend Android Scheduling

- [ ] Add schedule-plan regression coverage beyond day 14.
- [ ] Include exact-alarm permission in automatic mute availability.
- [ ] Build Android native plans for the remaining semester.
- [ ] Add native policy tests for exact-alarm fallback.
- [ ] Preserve restore work while converting unschedulable future mute work to
  manual reminders.

## Task 2: Replace Academic Imports By Source Batch

- [ ] Add optional import source metadata to course and event models.
- [ ] Add provider tests for moved, removed, and changed imported courses.
- [ ] Add provider tests for changed and empty imported exam batches.
- [ ] Preserve manual records during academic batch replacement.
- [ ] Update the import page to use explicit academic source identifiers.

## Task 3: Reject Invalid Parser Records

- [ ] Add parser tests for unknown weeks and invalid period ranges.
- [ ] Remove the fabricated week-1 fallback.
- [ ] Return accepted timetable records with skip diagnostics.
- [ ] Report skipped record counts after import.

## Task 4: Make Semester Operations Recoverable

- [ ] Add storage tests for interrupted create, initialize, delete, and switch
  operations.
- [ ] Persist and resume semester operation intent.
- [ ] Publish external backup only after completed operations.
- [ ] Add one provider-level semester change callback for course reload and
  schedule refresh.

## Task 5: Verify The Milestone

- [ ] Run focused Dart and JVM tests after each batch.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter build web --release`.
- [ ] Run `flutter build windows --debug`.
- [ ] Run Android debug Kotlin compilation and JVM tests.
- [ ] Run modified Dart formatting and `git diff --check`.

## Execution Notes

- Execute inline because no subagent delegation was requested.
- Keep M1 and M2 changes intact.
- Preserve the user-provided root `problem.md`.
