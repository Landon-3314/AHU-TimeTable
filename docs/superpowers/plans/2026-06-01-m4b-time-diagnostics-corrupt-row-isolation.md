# M4b Time Diagnostics and Corrupt Row Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Android alarm plans safely after time changes, report real diagnostic scheduling failures, quarantine malformed timetable rows, and show one startup notice for newly isolated records.

**Architecture:** Add pure Kotlin policies for timezone rebasing and diagnostic result classification, then wire them into the existing Android scheduler and MethodChannel. Add a focused Dart corrupt-row diagnostic store and let `StorageService.create` scan, quarantine, restore, or sanitize rows before publishing a valid backup. Surface newly isolated row counts once through `MainScaffold`.

**Tech Stack:** Kotlin/JUnit 4, Android AlarmManager and BroadcastReceiver, Flutter/Dart, SharedPreferences, MethodChannel, flutter_test.

---

### Task 1: Rebuild Android Native Time Plans After Clock Changes

**Files:**
- Create: `android/app/src/main/kotlin/com/gh/timetable/NativeAlarmTimePolicy.kt`
- Create: `android/app/src/test/kotlin/com/gh/timetable/NativeAlarmTimePolicyTest.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeStateStore.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeAlarmScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/BootRescheduleReceiver.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Write failing Kotlin policy tests**

Add tests for:

```kotlin
NativeAlarmTimePolicy.rebaseTimestamp(
    timestamp = sourceCalendar.timeInMillis,
    sourceTimeZoneId = "Asia/Shanghai",
    targetTimeZoneId = "America/New_York",
)
```

Assert that the target timestamp still represents the same local year, month, day, hour, minute, second, and millisecond in the target zone. Add a DST case where a fixed offset subtraction would be incorrect. Add `rebaseAlarmItems` and `rebaseTodayCourseItems` tests covering every timestamp field. Add a missing-source-zone test asserting unchanged items. Add an allowed-action test for:

```text
android.intent.action.TIMEZONE_CHANGED
android.intent.action.TIME_SET
android.intent.action.DATE_CHANGED
```

- [ ] **Step 2: Run Kotlin tests and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; $env:JAVA_HOME = ''D:\Android\Android Studio\jbr''; $gradle = ''C:\Users\lenovo\.gradle\wrapper\dists\gradle-8.9-all\6m0mbzute7p0zdleavqlib88a\gradle-8.9\bin\gradle.bat''; & $gradle app:testDebugUnitTest --tests ''com.gh.timetable.NativeAlarmTimePolicyTest'' --no-daemon; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Expected: FAIL because `NativeAlarmTimePolicy` and the new receiver action check do not exist.

- [ ] **Step 3: Implement the pure timezone policy**

Create `NativeAlarmTimePolicy` with:

```kotlin
fun rebaseTimestamp(
    timestamp: Long?,
    sourceTimeZoneId: String?,
    targetTimeZoneId: String,
): Long?

fun rebaseAlarmItems(
    items: List<NativeAlarmScheduler.AlarmItem>,
    sourceTimeZoneId: String?,
    targetTimeZoneId: String,
): List<NativeAlarmScheduler.AlarmItem>

fun rebaseTodayCourseItems(
    items: List<NativeStateStore.TodayCourseItem>,
    sourceTimeZoneId: String?,
    targetTimeZoneId: String,
): List<NativeStateStore.TodayCourseItem>
```

Use `Calendar` and `TimeZone`; preserve local date-time fields rather than applying a fixed offset.

- [ ] **Step 4: Persist timezone metadata and wire rescheduling**

Add `KEY_ALARM_ITEMS_TIME_ZONE_ID`, `getAlarmItemsTimeZoneId`, and timezone cleanup to `NativeStateStore`. Save the current timezone whenever native alarm items are saved. In `NativeAlarmScheduler.rescheduleStored`, read the stored zone first, rebase alarm items and today-course items into the current zone, persist both caches, then filter and register future work.

- [ ] **Step 5: Register time-change broadcasts**

Expose `BootRescheduleReceiver.isAllowedAction(action: String)` for JVM testing, add the three time-change actions to its whitelist, and add matching manifest actions.

- [ ] **Step 6: Run Kotlin policy tests and compile**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; $env:JAVA_HOME = ''D:\Android\Android Studio\jbr''; $gradle = ''C:\Users\lenovo\.gradle\wrapper\dists\gradle-8.9-all\6m0mbzute7p0zdleavqlib88a\gradle-8.9\bin\gradle.bat''; & $gradle app:compileDebugKotlin app:testDebugUnitTest --no-daemon; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Expected: PASS.

### Task 2: Return Real Native Diagnostic Scheduling Results

**Files:**
- Create: `android/app/src/main/kotlin/com/gh/timetable/NativeDiagnosticSchedulePolicy.kt`
- Create: `android/app/src/test/kotlin/com/gh/timetable/NativeDiagnosticSchedulePolicyTest.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/NativeAlarmScheduler.kt`
- Modify: `android/app/src/main/kotlin/com/gh/timetable/MainActivity.kt`
- Modify: `lib/services/native_alarm_service.dart`
- Modify: `lib/screens/developer_diagnostics_page.dart`
- Create: `test/services/native_alarm_service_test.dart`

- [ ] **Step 1: Write failing Kotlin diagnostic-result tests**

Test:

```kotlin
NativeDiagnosticSchedulePolicy.result(
    silentScheduled = true,
    restoreScheduled = true,
)
```

Assert success only when both booleans are true. Assert failure reasons `silent_alarm_schedule_failed` and `restore_alarm_schedule_failed`.

- [ ] **Step 2: Run Kotlin diagnostic tests and verify RED**

Expected: FAIL because `NativeDiagnosticSchedulePolicy` does not exist.

- [ ] **Step 3: Implement Kotlin policy and scheduler return values**

Create:

```kotlin
data class DiagnosticScheduleResult(
    val success: Boolean,
    val reason: String? = null,
) {
    fun toMap(): Map<String, Any?> = mapOf("success" to success, "reason" to reason)
}
```

Make `scheduleOneMinuteMuteTest` and `scheduleDiagnosticMuteWindow` return this result. Capture the return values from exact and inexact scheduling attempts. Return silent failure immediately; return restore failure only after the fallback also fails.

- [ ] **Step 4: Return maps through MethodChannel**

In `MainActivity`, call `.toMap()` for both diagnostic methods instead of returning unconditional `true`.

- [ ] **Step 5: Write failing Dart MethodChannel tests**

Add `NativeMuteTestResult` expectations for:

```dart
{'success': false, 'reason': 'restore_alarm_schedule_failed'}
```

Also test malformed responses and `PlatformException` as generic failures. Set `debugDefaultTargetPlatformOverride = TargetPlatform.android` and use a mock handler for `com.timetable/native_alarm`.

- [ ] **Step 6: Run Dart service test and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; flutter test test\services\native_alarm_service_test.dart; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Expected: FAIL because `runTimedMuteTest` still returns `bool`.

- [ ] **Step 7: Parse and display structured Dart results**

Add:

```dart
class NativeMuteTestResult {
  const NativeMuteTestResult({required this.success, this.reason});

  final bool success;
  final String? reason;

  String get failureMessage;
}
```

Change `runTimedMuteTest` to return this type. Map known native reasons to Chinese SnackBar messages in `DeveloperDiagnosticsPage`; unknown failures keep the current `MuteDiag` guidance.

- [ ] **Step 8: Run focused Dart and Kotlin tests**

Expected: PASS.

### Task 3: Quarantine Malformed Timetable Rows and Recover Safely

**Files:**
- Create: `lib/services/corrupt_row_diagnostic_store.dart`
- Create: `test/services/corrupt_row_diagnostic_store_test.dart`
- Create: `test/models/event_test.dart`
- Modify: `lib/models/event.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `test/services/storage_service_test.dart`

- [ ] **Step 1: Write failing strict Event tests**

Assert that missing, non-string, and malformed `dateTime` values throw `FormatException`.

- [ ] **Step 2: Run Event tests and verify RED**

Expected: FAIL because `Event.fromJson` currently substitutes `DateTime.now()`.

- [ ] **Step 3: Implement strict Event parsing**

Require a parseable string and throw:

```dart
throw const FormatException('Invalid event dateTime');
```

- [ ] **Step 4: Write failing diagnostic store tests**

Test recording raw rows, `sourceKey + rawValue` deduplication, pending-count consumption, and truncation to the newest 100 records. Use local preference keys:

```text
diagnostics.corruptRows.v1
diagnostics.corruptRowsPendingCount.v1
```

- [ ] **Step 5: Run diagnostic store tests and verify RED**

Expected: FAIL because the component does not exist.

- [ ] **Step 6: Implement the focused diagnostic store**

Create immutable `CorruptRowDiagnosticRecord` plus `CorruptRowDiagnosticStore`. Store records as JSON strings, keep newest 100, and increment pending count only for newly added dedupe keys.

- [ ] **Step 7: Write failing StorageService recovery tests**

Add tests for:

- corrupt scoped event row with a valid external backup: restore backup and retain diagnostic record;
- corrupt scoped course and event rows without backup: remove only bad rows and preserve valid rows;
- repeated startup scan: do not duplicate diagnostic records or pending count;
- structural damage without backup: remain an initialization failure;
- consuming the pending notice count clears it;
- diagnostics keys do not appear in external backup preferences.

- [ ] **Step 8: Run StorageService tests and verify RED**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; flutter test test\models\event_test.dart test\services\corrupt_row_diagnostic_store_test.dart test\services\storage_service_test.dart; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Expected: FAIL because row scanning and sanitize fallback do not exist.

- [ ] **Step 9: Add scan, recovery, and sanitize flow**

In `StorageService.create`:

1. scan legacy and semester-scoped `courses.items` and `events.items` string lists;
2. record invalid row raw values before any recovery action;
3. resume pending semester work;
4. classify strictly and try external restore when needed;
5. when restore is unavailable and the tolerant classification proves damage is row-only, rewrite affected lists with valid rows;
6. classify strictly again and only publish a valid backup.

Add:

```dart
Future<int> consumePendingCorruptRowNoticeCount()
```

Keep structural classification strict.

- [ ] **Step 10: Run focused storage tests**

Expected: PASS.

### Task 4: Show a One-Time Startup Notice and Verify the Milestone

**Files:**
- Modify: `lib/providers/settings_provider.dart`
- Modify: `lib/screens/main_scaffold.dart`
- Create: `test/widgets/main_scaffold_corrupt_row_notice_test.dart`

- [ ] **Step 1: Write failing startup-notice widget test**

Build `MainScaffold` with normal providers and a pending corrupt-row count of `2`. After the first frame, assert:

```text
已跳过并保留 2 条损坏日程记录
```

Rebuild and assert the notice is not shown again after consumption.

- [ ] **Step 2: Run widget test and verify RED**

Expected: FAIL because startup corrupt-row notices are not consumed or shown.

- [ ] **Step 3: Surface and show the notice**

Delegate `consumePendingCorruptRowNoticeCount()` through `SettingsProvider`. In `MainScaffold._runStartupPrompts`, consume and display the notice before the semester start-date prompt using the existing app SnackBar helper.

- [ ] **Step 4: Run focused M4b tests**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; flutter test test\models\event_test.dart test\services\corrupt_row_diagnostic_store_test.dart test\services\storage_service_test.dart test\services\native_alarm_service_test.dart test\widgets\main_scaffold_corrupt_row_notice_test.dart; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Expected: PASS.

- [ ] **Step 5: Format and run full verification**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; dart format lib test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; flutter test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; flutter analyze; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Run Android verification:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; $env:JAVA_HOME = ''D:\Android\Android Studio\jbr''; $gradle = ''C:\Users\lenovo\.gradle\wrapper\dists\gradle-8.9-all\6m0mbzute7p0zdleavqlib88a\gradle-8.9\bin\gradle.bat''; & $gradle app:compileDebugKotlin app:testDebugUnitTest --no-daemon; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }'
```

Run diff and artifact checks:

```powershell
pwsh -NoLogo -NoProfile -Command '$ErrorActionPreference = ''Stop''; git diff --check; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; $artifacts = Get-ChildItem -Path . -Recurse -Force -File | Where-Object { $_.Name -match ''(__pycache__|\.pyc$|\.tmp$|\.orig$|\.rej$)'' }; if ($artifacts) { $artifacts.FullName; exit 1 }; ''NO_TEMP_ARTIFACTS'''
```

Expected: all checks pass and temporary artifact scan prints `NO_TEMP_ARTIFACTS`.

- [ ] **Step 6: Inspect the cumulative diff**

Review only M4b files alongside the existing cumulative M1-M4a changes. Do not revert unrelated work and do not stage or commit unless explicitly requested.
