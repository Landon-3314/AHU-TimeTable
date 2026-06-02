# M1 Transactional Recovery Design

## Status

Approved in conversation on 2026-06-01.

## Context

The current implementation has several data-safety and alarm-state defects:

1. Refreshing Android alarm schedules can discard the restore task for an
   auto-mute window that is already active.
2. Legacy data migration records enough metadata to skip later migration work
   before the legacy payload is safely copied.
3. Internal SharedPreferences state is treated as recoverable when expected
   keys merely exist, even if their values are malformed.
4. Startup can overwrite a valid external backup with damaged internal state.
5. External backup replacement deletes the previous file before the new file
   is committed, uses a fixed temporary path, and does not serialize concurrent
   writers.

M1 fixes these defects without replacing the existing SharedPreferences data
model or introducing a database migration.

## Goals

- Preserve Android ringer restoration when schedules refresh during an active
  app-owned mute window.
- Restore immediately when the user disables auto mute during an active
  app-owned mute window.
- Avoid overriding a user-initiated ringer-mode change.
- Make legacy timetable migration repeatable after interruption.
- Validate internal persisted state before treating it as a recovery source.
- Prefer a valid external snapshot when internal state is missing or damaged.
- Ensure damaged internal state never overwrites a valid external snapshot
  during startup recovery.
- Serialize external snapshot writes and keep a previous valid snapshot until
  the replacement is committed.
- Add fault-focused regression tests before implementation changes.

## Non-Goals

- Replacing SharedPreferences with SQLite.
- Implementing the rolling reminder horizon from M3.
- Redesigning semester CRUD as a general transaction engine.
- Shipping release workflow fixes from M2.
- Redesigning the UI from M4.

## Design Overview

M1 uses incremental, idempotent changes around the existing storage and alarm
services. Existing data formats remain readable. New metadata only records
recovery state and never becomes the sole copy of user data.

## Android Auto-Mute Restoration

### Current failure

`NativeAlarmScheduler.scheduleAll` reconciles mute state, cancels all previous
intents, replaces the stored alarm item list, and then schedules the new list.
When a class is already in progress, its silent action is in the past but its
restore action is still required. A refreshed Dart plan may omit that old
window, so the restore intent and the stored ownership record disappear.

### Required behavior

Before replacing stored alarms, native scheduling must retain app-owned active
mute windows whose restore time is still in the future. The retained restore
work is merged into the new schedule using the existing request-code identity.

The app owns restoration only when it previously applied silent mode for that
window. Restoration is allowed only while the current ringer mode still equals
the mode applied by the app. If the user manually changes the device to
vibrate, normal, or another mode, the app clears its ownership record without
overriding the user's choice.

Disabling auto mute must explicitly reconcile with
`restoreActiveAppMute = true` before schedules are replaced.

### Native state extension

Persist enough state to distinguish:

- the original ringer mode observed before app mute;
- whether the app currently owns the mute state;
- the ringer mode applied by the app;
- the active window identity and restore timestamp.

Existing stored alarm items remain readable. New fields use backward-compatible
defaults.

### Native decision helper

Extract pure decision logic for:

- retaining active restore work during refresh;
- deciding whether app-owned mute may be restored;
- clearing ownership after user intervention.

This keeps Android behavior testable without requiring an emulator for every
branch.

## Recoverable Internal State

### Validation boundary

Startup must classify internal state as one of:

- `valid`: metadata and timetable payload can be decoded and satisfy structural
  invariants;
- `missing`: no meaningful business payload exists;
- `damaged`: business keys exist but decoding or invariants fail.

Validation covers at least:

- semester list decoding and non-empty semester IDs;
- current semester reference consistency;
- semester-scoped course and event list decoding;
- course and event row shape required by their model parsers;
- migration metadata shape.

Unknown settings keys remain forward-compatible. A malformed row is not
silently accepted as proof that the overall snapshot is healthy.

### Startup ordering

Startup proceeds in this order:

1. Inspect internal state without writing an external snapshot.
2. Ask the external backup store for its best valid recoverable snapshot.
3. If internal state is missing or damaged and external state is valid, restore
   external state.
4. Run idempotent legacy migration.
5. Validate the resulting internal state.
6. Only after validation succeeds, synchronize the external backup.

If both internal and external sources are damaged, preserve evidence for
diagnostics and initialize only through the existing safe fallback path. Do
not overwrite external recovery candidates with damaged internal data.

## Idempotent Legacy Migration

### Current failure

The migration can save a semester list and migration version around the legacy
copy process. If execution stops between those writes and the payload copy,
the next launch sees semesters and skips the missing migration work.

### Commit protocol

Migration is split into repeatable phases:

1. Discover or create a deterministic target semester.
2. Record migration as `in_progress` with the target semester ID.
3. Copy legacy timetable payload into the target semester keys using
   idempotent replacement writes.
4. Validate the copied target payload.
5. Record migration as `complete`.
6. Preserve existing cleanup behavior only after the complete marker is
   durable.

On startup, an `in_progress` migration resumes from the recorded target. If an
older installation has semester metadata but no complete marker, migration
checks for missing scoped payload and repairs it before marking complete.

## Atomic External Snapshot Store

### Write serialization

All writes through one `ExternalDataBackupStore` instance are serialized. Each
write captures one complete SharedPreferences snapshot after the previous write
finishes. Callers still receive `Future<bool>` so existing UI flows remain
compatible.

### Commit protocol

For a destination `preferences-backup.json`:

1. Serialize the snapshot with schema version and checksum.
2. Write to a unique sibling temporary file.
3. Flush the temporary file.
4. Validate the temporary snapshot by reading it back.
5. Move the current valid destination to a sibling previous-snapshot file.
6. Rename the validated temporary file to the destination.
7. Remove obsolete temporary files and an obsolete previous file only after a
   successful commit.

If replacement fails, restore the previous snapshot when necessary and leave a
valid recovery candidate available.

### Read recovery priority

Read recovery inspects:

1. the main snapshot;
2. the previous snapshot;
3. sibling temporary snapshots left by interrupted writes.

The newest valid candidate wins, with the committed main snapshot preferred
when timestamps are equal. Invalid candidates are quarantined rather than
treated as valid data.

### Test seam

The store gains a narrow file-operation seam so tests can inject rename and
write failures without using platform-specific filesystem tricks.

## Test Strategy

### Dart storage tests

Add regression coverage for:

- interrupted migration resumes and copies legacy payload;
- malformed internal business state restores from a valid external snapshot;
- malformed internal state does not overwrite a valid external snapshot;
- concurrent backup requests serialize and leave a valid latest snapshot;
- rename failure preserves a valid recoverable snapshot;
- startup recovers from a valid temporary snapshot when the main file is
  absent or damaged;
- corrupted rows are surfaced as damaged state instead of silently accepted.

### Android tests

Add pure Kotlin tests for:

- active app-owned restore work survives schedule refresh;
- disabling auto mute restores an active app-owned mute;
- manual vibration change is not overridden;
- expired windows are not retained.

### Existing widget regression

Scope the date-dependent timetable overview assertion so the background Monday
grid and the overview sheet cannot be mistaken for duplicate overview rows.

## Verification

M1 is complete when:

- new focused Dart tests pass;
- Android pure logic tests pass;
- the existing Flutter test suite passes;
- `flutter analyze` passes;
- Android debug Kotlin compilation passes;
- no temporary test artifact remains in the repository.
