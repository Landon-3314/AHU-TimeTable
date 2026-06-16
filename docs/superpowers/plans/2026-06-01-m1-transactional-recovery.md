# M1 Transactional Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make local recovery, legacy migration, external backup replacement, and Android auto-mute restoration resilient to refreshes and interrupted writes.

**Architecture:** Keep the existing SharedPreferences data model and add narrow recovery layers around it. Dart storage changes validate persisted business state before startup synchronization and commit external snapshots through serialized file replacement. Android changes extract pure mute-state decisions and retain app-owned restore work while native schedules are refreshed.

**Tech Stack:** Flutter/Dart, `shared_preferences`, Dart `dart:io`, Android Kotlin, Gradle JVM unit tests, `flutter_test`.

---

## File Map

- Modify: `test/widgets/timetable_page_test.dart`
  - Scope the overview finder to the overview panel so the test is independent
    of the current weekday.
- Modify: `test/services/storage_backup_store_test.dart`
  - Add serialized-write, temporary recovery, and rename-failure coverage.
- Modify: `lib/services/external_data_backup_store.dart`
  - Add serialized atomic writes, previous snapshot fallback, temporary snapshot
    recovery, and an injectable file-operation seam.
- Modify: `test/services/storage_service_test.dart`
  - Add damaged-internal-state and interrupted-migration coverage.
- Modify: `lib/services/storage_service.dart`
  - Add strict startup classification and idempotent migration state.
- Create: `android/app/src/main/kotlin/com/gh/timetable/NativeMuteStatePolicy.kt`
  - Hold pure decisions for retained restore work and user-intervention-safe
    restoration.
- Create: `android/app/src/test/kotlin/com/gh/timetable/NativeMuteStatePolicyTest.kt`
  - Verify native mute behavior without an emulator.
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeAlarmScheduler.kt`
  - Merge retained app-owned restore work into refreshed schedules.
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeStateStore.kt`
  - Persist the ringer mode actually applied by the app.
- Modify: `android/app/src/main/kotlin/com/gh/timetable/AlarmReceiver.kt`
  - Restore only when the device remains in the app-applied mode.
- Modify: `lib/services/app_services.dart`
  - Force native mute reconciliation when auto mute is disabled.
- Modify: `android/app/build.gradle.kts`
  - Add JUnit dependency for pure JVM tests.

## Task 1: Stabilize the Existing Widget Baseline

**Files:**
- Modify: `test/widgets/timetable_page_test.dart`

- [ ] **Step 1: Reproduce the date-dependent failure**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\widgets\timetable_page_test.dart --plain-name ''overview groups courses by name and opens a single record edit'''
```

Expected: FAIL because the page background and the overview panel can both
contain `Grouped Course` on a Monday.

- [ ] **Step 2: Scope the overview course finder**

Add the panel import:

```dart
import 'package:AnKe/widgets/timetable/course_overview_panel.dart';
```

After opening the overview, create a scoped finder and use it for overview-row
assertions and taps:

```dart
final overviewCourse = find.descendant(
  of: find.byType(CourseOverviewPanel),
  matching: find.text('Grouped Course'),
);

expect(overviewCourse, findsOneWidget);
await tester.tap(overviewCourse);
```

Recreate the finder after returning from the edit page before asserting the
overview row again.

- [ ] **Step 3: Verify the isolated widget regression**

Run the command from Step 1.

Expected: PASS.

## Task 2: Serialize and Atomically Replace External Snapshots

**Files:**
- Modify: `test/services/storage_backup_store_test.dart`
- Modify: `lib/services/external_data_backup_store.dart`

- [ ] **Step 1: Add a failing concurrent-write test**

Add a test that issues two writes through one store while delaying the first
temporary-file rename. Mutate `settings.languageCode` between requests and
assert that both futures return `true`, the final snapshot is valid, and its
language is the value captured by the second serialized write.

Use a file-operation seam with this shape:

```dart
abstract interface class ExternalDataBackupFileOperations {
  const ExternalDataBackupFileOperations();

  Future<void> writeString(File file, String contents);
  Future<String> readString(File file);
  Future<void> rename(File file, String newPath);
  Future<void> delete(File file);
  Future<bool> exists(File file);
}
```

The delaying test implementation completes a `Completer<void>` before allowing
the first rename to continue.

- [ ] **Step 2: Run the concurrent-write test and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_backup_store_test.dart --plain-name ''serializes concurrent snapshot writes and keeps the latest state'''
```

Expected: FAIL because `ExternalDataBackupFileOperations` and constructor
injection do not exist yet.

- [ ] **Step 3: Add the file-operation seam and serialized queue**

In `external_data_backup_store.dart`, add a default implementation and inject
it through the existing constructor:

```dart
class IoExternalDataBackupFileOperations
    implements ExternalDataBackupFileOperations {
  const IoExternalDataBackupFileOperations();

  @override
  Future<void> writeString(File file, String contents) {
    return file.writeAsString(contents, flush: true);
  }

  @override
  Future<String> readString(File file) => file.readAsString();

  @override
  Future<void> rename(File file, String newPath) async {
    await file.rename(newPath);
  }

  @override
  Future<void> delete(File file) => file.delete();

  @override
  Future<bool> exists(File file) => file.exists();
}
```

Add a per-destination static queue:

```dart
static final Map<String, Future<void>> _writeQueues = {};
static int _temporarySequence = 0;

Future<bool> _enqueueWrite(
  String destinationPath,
  Future<bool> Function() operation,
) {
  final previous = _writeQueues[destinationPath] ?? Future<void>.value();
  final completer = Completer<bool>();
  final current = previous.catchError((_) {}).then((_) async {
    try {
      completer.complete(await operation());
    } catch (_) {
      completer.complete(false);
    }
  });
  _writeQueues[destinationPath] = current.whenComplete(() {
    if (identical(_writeQueues[destinationPath], current)) {
      _writeQueues.remove(destinationPath);
    }
  });
  return completer.future;
}
```

Move snapshot capture inside the queued operation so each writer sees a
coherent post-predecessor SharedPreferences state.

- [ ] **Step 4: Commit through unique temporary and previous files**

Use:

```dart
final previousFile = File('${file.path}.previous');
final tempFile = File(
  '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}-'
  '${_temporarySequence++}',
);
```

Write, flush, read back, and validate the temporary snapshot before moving the
current destination to `.previous`. Rename the validated temporary snapshot to
the main destination. If the final rename fails after the old main was moved,
rename `.previous` back to the main destination when possible.

- [ ] **Step 5: Verify serialized writes GREEN**

Run the command from Step 2.

Expected: PASS.

## Task 3: Recover from Previous and Temporary Snapshots

**Files:**
- Modify: `test/services/storage_backup_store_test.dart`
- Modify: `lib/services/external_data_backup_store.dart`

- [ ] **Step 1: Add failing recovery tests**

Add two focused tests:

```dart
test('recovers from a valid temporary snapshot when main snapshot is absent', () async {
  final directory = await Directory.systemTemp.createTemp('temp-recovery-');
  addTearDown(() => directory.delete(recursive: true));
  final store = ExternalDataBackupStore(externalFilesDirectory: directory);
  await _writeLanguageSnapshot(store, 'zh');
  final mainFile = await store.debugBackupFile();
  await mainFile.rename('${mainFile.path}.tmp-interrupted');

  expect((await store.readPreferences())!['settings.languageCode'], 'zh');
});

test('rename failure preserves a valid recoverable snapshot', () async {
  final directory = await Directory.systemTemp.createTemp('rename-failure-');
  addTearDown(() => directory.delete(recursive: true));
  final store = ExternalDataBackupStore(externalFilesDirectory: directory);
  await _writeLanguageSnapshot(store, 'zh');
  final failingStore = ExternalDataBackupStore(
    externalFilesDirectory: directory,
    fileOperations: const _FailingFinalRenameOperations(),
  );

  expect(await _writeLanguageSnapshot(failingStore, 'en'), isFalse);
  expect((await store.readPreferences())!['settings.languageCode'], 'zh');
});
```

Implement `_writeLanguageSnapshot` by setting mock preferences, getting the
SharedPreferences instance, and returning
`store.writeFromSharedPreferences(preferences)`. Implement
`_FailingFinalRenameOperations` by delegating all operations to
`IoExternalDataBackupFileOperations` except a rename from `.tmp-*` to the main
`timetable-data.v1.json` destination, which throws `FileSystemException`.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_backup_store_test.dart'
```

Expected: FAIL because reads inspect only the main snapshot.

- [ ] **Step 3: Inspect all recovery candidates**

Add an internal candidate record:

```dart
class _SnapshotCandidate {
  const _SnapshotCandidate({
    required this.file,
    required this.preferences,
    required this.writtenAt,
    required this.priority,
  });

  final File file;
  final Map<String, Object> preferences;
  final DateTime writtenAt;
  final int priority;
}
```

List the main file, `.previous`, and sibling `.tmp-*` files. Validate each
candidate, quarantine malformed candidates, and choose the newest valid
snapshot. On timestamp ties, prefer main over previous over temporary.

- [ ] **Step 4: Make restore use the candidate search**

Remove the early `main file exists` return from
`restoreToSharedPreferences`. Return:

- `noBackup` when no candidate files exist;
- `invalidBackup` when candidates existed but none validate;
- `restored` after writing the chosen snapshot.

- [ ] **Step 5: Verify backup-store coverage GREEN**

Run the command from Step 2.

Expected: all backup-store tests PASS.

## Task 4: Validate Internal State Before Startup Synchronization

**Files:**
- Modify: `test/services/storage_service_test.dart`
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: Add a failing damaged-internal-state recovery test**

Start with a valid external snapshot, then initialize SharedPreferences with a
semester key containing malformed JSON:

```dart
SharedPreferences.setMockInitialValues({
  'semesters.items': ['{broken json'],
  'semesters.currentId': 'broken-semester',
});

final service = await StorageService.create(
  externalDataBackupStore: store,
);

expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
expect(service.currentSemesterId, 'semester-1');
expect(service.loadCourses().single.name, 'Math');
```

- [ ] **Step 2: Run the damaged-state test and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_service_test.dart --plain-name ''restores valid external backup when internal business state is damaged'''
```

Expected: FAIL because the current key-existence check skips restore.

- [ ] **Step 3: Add strict startup classification**

Introduce:

```dart
enum InternalDataState { missing, valid, damaged }
```

Replace `_hasRecoverableInternalData` with
`_classifyInternalData(SharedPreferences preferences)`. Use a strict list
decoder for validation:

```dart
static bool _canDecodeList<T>({
  required SharedPreferences preferences,
  required String key,
  required T Function(Map<String, dynamic> json) decode,
}) {
  final rawItems = preferences.getStringList(key);
  if (rawItems == null) {
    return true;
  }
  try {
    for (final raw in rawItems) {
      decode(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    }
    return true;
  } catch (_) {
    return false;
  }
}
```

Classification must:

- return `missing` when no timetable business key exists;
- treat structurally valid legacy course/event lists as `valid`;
- reject malformed semester lists;
- reject empty semester IDs;
- reject a current semester ID that is absent from the semester list;
- validate each semester-scoped course and event list strictly.

- [ ] **Step 4: Change startup ordering**

Use the classifier before restoring and after migration:

```dart
final internalState = _classifyInternalData(sharedPreferences);
final recoveryStatus = internalState == InternalDataState.valid
    ? ExternalDataRecoveryStatus.skippedInternalDataPresent
    : await backupStore.restoreToSharedPreferences(sharedPreferences);

final service = StorageService(...);
await service.ensureSemesterMigration();
if (_classifyInternalData(sharedPreferences) == InternalDataState.valid) {
  await service.syncExternalBackup();
}
```

This prevents damaged internal state from overwriting a valid external
snapshot during startup.

- [ ] **Step 5: Verify damaged-state recovery GREEN**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 6: Reject malformed scoped course rows**

Add a second test whose internal preferences contain a valid semester and
current ID but:

```dart
'semesters.semester-1.courses.items': ['{broken json'],
```

Keep a valid external snapshot and assert the service restores its `Math`
course. Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_service_test.dart --plain-name ''restores external backup when a scoped course row is damaged'''
```

Expected: PASS after strict classification is active.

## Task 5: Resume Interrupted Legacy Migration

**Files:**
- Modify: `test/services/storage_service_test.dart`
- Modify: `lib/services/storage_service.dart`

- [ ] **Step 1: Add a failing interrupted-migration test**

Initialize preferences with an existing target semester, an `in_progress`
marker, a target ID, and an uncopied legacy course:

```dart
SharedPreferences.setMockInitialValues({
  'semesters.items': [jsonEncode(semester.toJson())],
  'semesters.currentId': semester.id,
  'semesters.migrationState': 'in_progress',
  'semesters.migrationTargetId': semester.id,
  'courses.items': [jsonEncode(course.toJson())],
});

final service = await StorageService.create(
  externalDataBackupStore: const _UnavailableBackupStore(),
);

expect(service.loadCourses().single.name, 'Math');
```

- [ ] **Step 2: Run the migration test and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_service_test.dart --plain-name ''resumes interrupted legacy timetable migration into recorded semester'''
```

Expected: FAIL because existing semesters currently cause an early return.

- [ ] **Step 3: Add explicit migration state**

Add:

```dart
static const String _semesterMigrationStateKey =
    'semesters.migrationState';
static const String _semesterMigrationTargetIdKey =
    'semesters.migrationTargetId';
static const String _migrationStateInProgress = 'in_progress';
static const String _migrationStateComplete = 'complete';
```

Allow `_saveSemesters` and `_migrateLegacyTimetableData` to suppress backup
synchronization during the migration transaction.

Extend `setCurrentSemesterId` so migration can avoid publishing intermediate
state:

```dart
Future<void> setCurrentSemesterId(String semesterId, {bool sync = true}) {
  return _setString(_currentSemesterIdKey, semesterId, sync: sync);
}
```

- [ ] **Step 4: Make migration repeatable**

Implement this ordering:

```dart
final targetSemester = _resolveOrCreateMigrationTarget(existingSemesters);
await _setString(_semesterMigrationStateKey, _migrationStateInProgress, sync: false);
await _setString(_semesterMigrationTargetIdKey, targetSemester.id, sync: false);
await setCurrentSemesterId(targetSemester.id, sync: false);
await _migrateLegacyTimetableData(targetSemester.id, legacyUser: legacyUser, sync: false);
await _setInt(_semesterMigrationVersionKey, _semesterMigrationVersion, sync: false);
await _setString(_semesterMigrationStateKey, _migrationStateComplete, sync: false);
await syncExternalBackup();
```

When a complete current migration already exists, return without copying.
When older metadata has semesters but no complete marker and legacy data still
exists, reuse the current or first semester and repair its scoped payload.

- [ ] **Step 5: Verify storage-service coverage GREEN**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_service_test.dart'
```

Expected: all storage-service tests PASS.

## Task 6: Extract Pure Android Mute-State Decisions

**Files:**
- Create: `android/app/src/main/kotlin/com/gh/timetable/NativeMuteStatePolicy.kt`
- Create: `android/app/src/test/kotlin/com/gh/timetable/NativeMuteStatePolicyTest.kt`
- Modify: `android/app/build.gradle.kts`

- [ ] **Step 1: Add the JUnit dependency**

Add:

```kotlin
testImplementation("junit:junit:4.13.2")
```

- [ ] **Step 2: Write failing pure policy tests**

Create tests for:

```kotlin
@Test
fun `active app-owned restore survives schedule refresh`() {
    assertTrue(
        NativeMuteStatePolicy.shouldRetainRestore(
            mutedByApp = true,
            restoreAtMillis = 2_000L,
            now = 1_000L,
        ),
    )
}

@Test
fun `expired restore is not retained`() {
    assertFalse(
        NativeMuteStatePolicy.shouldRetainRestore(
            mutedByApp = true,
            restoreAtMillis = 1_000L,
            now = 1_000L,
        ),
    )
}

@Test
fun `manual vibration is not overridden`() {
    assertFalse(
        NativeMuteStatePolicy.shouldRestoreOwnedMute(
            mutedByApp = true,
            currentRingerMode = AudioManager.RINGER_MODE_VIBRATE,
            appAppliedRingerMode = AudioManager.RINGER_MODE_SILENT,
        ),
    )
}
```

Also assert that app-owned silent mode can be restored when forced by disabling
auto mute.

- [ ] **Step 3: Run Android policy tests and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '.\gradlew.bat app:testDebugUnitTest --tests ''com.gh.timetable.NativeMuteStatePolicyTest'''
```

Working directory: `android`

Expected: FAIL because `NativeMuteStatePolicy` does not exist.

- [ ] **Step 4: Implement the minimal pure policy**

Create:

```kotlin
package com.gh.timetable

object NativeMuteStatePolicy {
    fun shouldRetainRestore(
        mutedByApp: Boolean,
        restoreAtMillis: Long?,
        now: Long,
    ): Boolean {
        return mutedByApp && restoreAtMillis != null && restoreAtMillis > now
    }

    fun shouldRestoreOwnedMute(
        mutedByApp: Boolean,
        currentRingerMode: Int,
        appAppliedRingerMode: Int?,
    ): Boolean {
        return mutedByApp &&
            appAppliedRingerMode != null &&
            currentRingerMode == appAppliedRingerMode
    }
}
```

- [ ] **Step 5: Verify Android policy tests GREEN**

Run the command from Step 3.

Expected: PASS.

## Task 7: Preserve Restore Work During Native Schedule Refresh

**Files:**
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeAlarmScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeStateStore.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/AlarmReceiver.kt`

- [ ] **Step 1: Persist the app-applied ringer mode**

Add `app_applied_ringer_mode_<index>` storage alongside the existing original
mode:

```kotlin
fun recordAppliedRingerMode(context: Context, index: Int, ringerMode: Int) {
    prefs(context).edit().putInt(appliedRingerModeKey(index), ringerMode).apply()
}

fun appliedRingerMode(context: Context, index: Int): Int? {
    val key = appliedRingerModeKey(index)
    val values = prefs(context)
    return if (values.contains(key)) values.getInt(key, -1) else null
}
```

Remove the new key from `clearMutedByApp`.

- [ ] **Step 2: Record the applied mode and respect manual intervention**

After `applySilent` changes the device to silent, record the actual mode:

```kotlin
NativeStateStore.recordAppliedRingerMode(context, index, audioManager.ringerMode)
```

In `applyRestore` and `reconcileMuteState`, replace the
`SILENT || VIBRATE` condition with:

```kotlin
NativeMuteStatePolicy.shouldRestoreOwnedMute(
    mutedByApp = true,
    currentRingerMode = audioManager.ringerMode,
    appAppliedRingerMode = NativeStateStore.appliedRingerMode(context, index),
)
```

If the predicate is false, clear the ownership record without changing the
ringer mode.

- [ ] **Step 3: Merge active restore work before replacing schedules**

In `scheduleAll`, load the old items before cancellation. Retain an old item
when the policy says the app still owns a future restore:

```kotlin
val retainedRestoreItems =
    NativeStateStore.loadAlarmItems(context).filter { item ->
        NativeMuteStatePolicy.shouldRetainRestore(
            mutedByApp = NativeStateStore.wasMutedByApp(context, item.index),
            restoreAtMillis = item.restoreAtMillis,
            now = now,
        )
    }.map { item ->
        item.copy(
            silentAtMillis = null,
            reminderAtMillis = null,
        )
    }
```

Merge retained items with new future work by index, preserving a retained
future restore when the refreshed item omits it.

- [ ] **Step 4: Run Android JVM tests**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '.\gradlew.bat app:testDebugUnitTest'
```

Working directory: `android`

Expected: PASS.

## Task 8: Restore Immediately When Auto Mute Is Disabled

**Files:**
- Modify: `lib/services/app_services.dart`

- [ ] **Step 1: Add forced reconciliation to the refresh path**

Change the Android branch:

```dart
await NativeAlarmService.instance.reconcileMuteState(
  restoreActiveAppMute: !settings.autoMuteEnabled,
);
```

The native scheduler then sees cleared ownership and does not retain a restore
window after auto mute is disabled.

- [ ] **Step 2: Analyze Dart changes**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter analyze'
```

Expected: no issues.

## Task 9: Run M1 Verification

**Files:**
- Verify all modified M1 files.

- [ ] **Step 1: Run Dart storage tests**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\services\storage_backup_store_test.dart test\services\storage_service_test.dart'
```

Expected: PASS.

- [ ] **Step 2: Run the widget regression**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test\widgets\timetable_page_test.dart'
```

Expected: PASS.

- [ ] **Step 3: Run the complete Flutter suite**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test'
```

Expected: PASS with zero failures.

- [ ] **Step 4: Run static analysis**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter analyze'
```

Expected: no issues.

- [ ] **Step 5: Compile Android debug Kotlin**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '.\gradlew.bat app:compileDebugKotlin app:testDebugUnitTest'
```

Working directory: `android`

Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: Check formatting and repository artifacts**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format --output=none --set-exit-if-changed lib test; git diff --check; git status --short'
```

Expected: no formatting changes required, no whitespace errors, and no
temporary test files.

## Execution Notes

- Execute inline in this session because no subagent delegation was requested.
- Do not create commits unless the user explicitly requests them.
- Preserve the user-provided untracked `problem.md`.
- Keep M2, M3, M4, and product-decision M5 changes outside this M1 batch.

## Execution Result

- Completed the M1 implementation inline with red-green regression tests.
- Passed `flutter test`: 94 tests.
- Passed `flutter analyze`: no issues.
- Passed Android `app:compileDebugKotlin app:testDebugUnitTest`: 7 JVM tests.
- Passed `git diff --check` and the modified Dart file format check.
- Used the cached Gradle 8.9 distribution because the repository does not
  contain Gradle wrapper scripts.
- Kept unrelated pre-existing Dart formatting differences outside this batch.
