# M4c+d 核心体验、主题与无障碍 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为课表应用补齐课程冲突确认、单项删除撤销、教务考试视图、三档主题模式、仅中文运行模式以及核心无障碍和窄屏适配。

**Architecture:** 保留现有 Provider 和 SharedPreferences 存储结构，将课程冲突识别抽成无副作用策略类，由 `CourseProvider` 统一实施写入门禁。考试继续复用 `Event`，主题通过 `ThemeExtension<AppThemeTokens>` 和根 `MaterialApp` 的 `themeMode` 接入，界面改动按业务能力分批验证。

**Tech Stack:** Flutter、Dart、Provider、SharedPreferences、flutter_test、Material 3、flutter_localizations。

---

## 执行约束

- 当前工作树包含 M1-M4b 的累计修复，不执行 `git add` 或 `git commit`。每个任务以聚焦测试和 `git diff --check` 作为检查点，避免把未分离的历史改动混入提交。
- Windows 命令统一使用 `pwsh -NoLogo -NoProfile -Command '...'`。
- 每个任务遵循红灯、最小实现、绿灯顺序；新增测试是长期回归测试，不在验证后删除。

## 文件结构

### 新增文件

- `lib/services/course_conflict_policy.dart`：纯课程冲突策略，不访问存储，不依赖 Widget。
- `lib/core/app_theme_tokens.dart`：亮暗界面令牌、黑白前景选择和对比度计算。
- `lib/screens/exam_overview_page.dart`：只展示 `academic.exam` 的专属考试页面。
- `lib/widgets/timetable_app.dart`：可直接 Widget 测试的根 `MaterialApp` 配置。
- `test/services/course_conflict_policy_test.dart`：策略边界回归测试。
- `test/core/app_theme_tokens_test.dart`：颜色前景和对比度回归测试。
- `test/widgets/exam_overview_page_test.dart`：考试筛选、倒计时、来源和空状态测试。
- `test/widgets/theme_mode_settings_test.dart`：三档主题模式和中文 Material 本地化测试。
- `test/widgets/responsive_accessibility_test.dart`：语义、窄屏工具栏和大字体滚轮回归测试。
- `test/widgets/reschedule_course_page_test.dart`：调课冲突确认测试。
- `test/widgets/import_course_page_conflict_test.dart`：批次导入冲突确认测试。
- `test/widgets/event_details_sheet_test.dart`：日程删除撤销测试。

### 修改文件

- `lib/providers/course_provider.dart`：调用冲突策略、增加预检和 `allowConflicts`、返回删除记录并支持恢复、为导入考试写入统一时间。
- `lib/models/event.dart`：增加可空 `importedAt`。
- `lib/screens/add_course_page.dart`：新增和编辑前汇总冲突确认；补颜色中文语义标签和对比度前景。
- `lib/screens/reschedule_course_page.dart`：调课前冲突确认。
- `lib/screens/import_course_page.dart`：课程批次预检、一次汇总确认、可见英文错误中文化。
- `lib/widgets/timetable/timetable_detail_sheets.dart`：单项删除后在父页面显示 Undo。
- `lib/core/app_routes.dart`：注册考试页路由。
- `lib/screens/timetable_page.dart`：增加考试入口和窄屏更多菜单。
- `lib/core/app_theme.dart`：构建亮暗主题并挂载主题令牌。
- `lib/providers/settings_provider.dart`：主题模式持久化接口；语言固定为中文。
- `lib/services/storage_service.dart`：主题模式读写；移除语言写入入口。
- `lib/main.dart`：根、加载和初始化错误 `MaterialApp` 接入亮暗主题与中文本地化。
- `lib/screens/settings_page.dart`：外观区展示三档显示模式。
- `lib/screens/theme_settings_page.dart`：主题色块中文语义和动态前景。
- `lib/widgets/common/app_ui.dart`：公共表面读取主题令牌。
- `lib/widgets/common/app_wheel_pickers.dart`：可用高度约束和主题令牌。
- `lib/widgets/common/guided_tour_overlay.dart`：中文屏障标签和步骤语义。
- `lib/widgets/common/capsule_multi_select.dart`、`lib/widgets/timetable/course_card.dart`、`lib/widgets/timetable/event_card.dart`、`lib/widgets/timetable/course_overview_panel.dart`、`lib/widgets/timetable/timetable_grid.dart`：主要用户界面迁移固定浅色常量。
- `lib/app_localizations.dart`：增加本轮中文文案键。
- `pubspec.yaml`：增加 `flutter_localizations` SDK 依赖。
- `pubspec.lock`：由 `flutter pub get` 更新 SDK 依赖锁定信息。
- `test/providers/course_provider_test.dart`、`test/models/event_test.dart`、`test/widgets/add_course_page_test.dart`、`test/widgets/course_details_sheet_test.dart`、`test/widgets/guided_tour_overlay_test.dart`、`test/widgets/timetable_page_test.dart`：扩充既有回归。

### 保留兼容数据

- `lib/app_localizations.dart` 中既有英文词典：保留为兼容数据，不再暴露运行时英文切换。

## Task 1: 课程冲突纯策略与 Provider 写入门禁

**Files:**
- Create: `lib/services/course_conflict_policy.dart`
- Create: `test/services/course_conflict_policy_test.dart`
- Modify: `lib/providers/course_provider.dart`
- Modify: `test/providers/course_provider_test.dart`

- [ ] **Step 1: 写纯策略失败测试**

新增策略测试，固定不同课程重叠、相同身份排除、星期/周次/节次不重叠排除：

```dart
final policy = CourseConflictPolicy();
final conflicts = policy.findConflicts(
  candidates: [course(name: '线性代数', weekday: 1, weeks: [1], start: 2, end: 3)],
  existingCourses: [course(name: '大学英语', weekday: 1, weeks: [1], start: 3, end: 4)],
);
expect(conflicts, hasLength(1));
expect(conflicts.single.candidate.name, '线性代数');
expect(conflicts.single.existingCourse.name, '大学英语');
```

再加入 `location`、`teacher` 经 `trim().toLowerCase()` 规范化后相同的课程不进入冲突列表。

- [ ] **Step 2: 运行纯策略测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/services/course_conflict_policy_test.dart'
```

Expected: FAIL，提示 `course_conflict_policy.dart` 或 `CourseConflictPolicy` 不存在。

- [ ] **Step 3: 实现最小纯策略**

新增以下公开接口：

```dart
class CourseConflict {
  const CourseConflict({
    required this.candidate,
    required this.existingCourse,
  });

  final Course candidate;
  final Course existingCourse;
}

class CourseConflictPolicy {
  const CourseConflictPolicy();

  List<CourseConflict> findConflicts({
    required Iterable<Course> candidates,
    required Iterable<Course> existingCourses,
    String? ignoredCourseId,
  }) {
    final conflicts = <CourseConflict>[];
    final acceptedCandidates = <Course>[];
    for (final candidate in candidates) {
      for (final existing in [...existingCourses, ...acceptedCandidates]) {
        if (existing.id == ignoredCourseId ||
            hasSameIdentity(existing, candidate) ||
            existing.weekday != candidate.weekday ||
            !existing.weeks.any(candidate.weeks.contains) ||
            !_rangesOverlap(
              existing.startPeriod,
              existing.endPeriod,
              candidate.startPeriod,
              candidate.endPeriod,
            )) {
          continue;
        }
        conflicts.add(
          CourseConflict(candidate: candidate, existingCourse: existing),
        );
      }
      acceptedCandidates.add(candidate);
    }
    return conflicts;
  }

  bool hasSameIdentity(Course left, Course right) {
    String normalize(String value) => value.trim().toLowerCase();
    return normalize(left.name) == normalize(right.name) &&
        normalize(left.location) == normalize(right.location) &&
        normalize(left.teacher) == normalize(right.teacher);
  }

  bool _rangesOverlap(int leftStart, int leftEnd, int rightStart, int rightEnd) {
    return leftStart <= rightEnd && rightStart <= leftEnd;
  }
}
```

- [ ] **Step 4: 运行策略测试并确认绿灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/services/course_conflict_policy_test.dart'
```

Expected: PASS。

- [ ] **Step 5: 写 Provider 门禁失败测试**

在 `test/providers/course_provider_test.dart` 增加：

```dart
expect(provider.findCourseConflicts([conflictingCourse]), hasLength(1));
expect(await provider.addCourse(conflictingCourse), isFalse);
expect(await provider.addCourse(conflictingCourse, allowConflicts: true), isTrue);
```

同时覆盖：

```dart
final importConflicts = provider.findImportedCourseConflicts([
  importedConflictWithManualCourse,
  firstImportedCourse,
  secondImportedCourseConflictingWithFirst,
]);
expect(importConflicts.map((item) => item.candidate.id), containsAll([
  importedConflictWithManualCourse.id,
  secondImportedCourseConflictingWithFirst.id,
]));
```

并断言旧 `academic.timetable` 记录不会导致误报，重复课程即使传入 `allowConflicts: true` 仍被拒绝。

- [ ] **Step 6: 运行 Provider 测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/providers/course_provider_test.dart'
```

Expected: FAIL，提示缺少 `findCourseConflicts`、`findImportedCourseConflicts` 或 `allowConflicts`。

- [ ] **Step 7: 实现 Provider 查询和门禁**

在 `CourseProvider` 中持有：

```dart
static const CourseConflictPolicy _conflictPolicy = CourseConflictPolicy();
```

公开查询：

```dart
List<CourseConflict> findCourseConflicts(
  Iterable<Course> candidates, {
  String? ignoredCourseId,
}) {
  return _conflictPolicy.findConflicts(
    candidates: candidates,
    existingCourses: _courses,
    ignoredCourseId: ignoredCourseId,
  );
}

List<CourseConflict> findImportedCourseConflicts(Iterable<Course> courses) {
  return _conflictPolicy.findConflicts(
    candidates: courses,
    existingCourses: _courses.where(
      (course) => course.importSource != academicTimetableImportSource,
    ),
  );
}

List<CourseConflict> findRescheduleCourseConflicts({
  required Course originalCourse,
  required int sourceWeek,
  required int targetWeek,
  required int targetWeekday,
  required int targetStartPeriod,
}) {
  final candidate = _buildRescheduledCourseOccurrence(
    originalCourse: originalCourse,
    sourceWeek: sourceWeek,
    targetWeek: targetWeek,
    targetWeekday: targetWeekday,
    targetStartPeriod: targetStartPeriod,
  );
  if (candidate == null) {
    return const <CourseConflict>[];
  }
  return findCourseConflicts(
    [candidate],
    ignoredCourseId: originalCourse.id,
  );
}
```

为 `addCourse`、`addCourses`、`updateCourse`、`rescheduleCourseOccurrence`、`mergeImportedCourses` 增加默认 `allowConflicts = false`。每个方法保持现有重复拒绝逻辑，并在真正写入前执行冲突门禁：

```dart
if (!allowConflicts &&
    findCourseConflicts([semesterCourse]).isNotEmpty) {
  return false;
}
```

编辑调用传入 `ignoredCourseId: originalCourse.id`；调课调用将 `remainingCourse` 纳入候选或策略既有记录，避免拆分后的同一课程残段误报。导入使用 `findImportedCourseConflicts`，检测新批次内部冲突并忽略被替换旧批次。

将调课候选记录构造抽为 `_buildRescheduledCourseOccurrence`，由预检和实际写入共同调用；这样页面只传调课参数，不复制跨度、ID 和来源字段处理。实际写入继续先校验原课程存在且包含 `sourceWeek`。

- [ ] **Step 8: 运行聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib/services/course_conflict_policy.dart lib/providers/course_provider.dart test/services/course_conflict_policy_test.dart test/providers/course_provider_test.dart; flutter test test/services/course_conflict_policy_test.dart test/providers/course_provider_test.dart; git diff --check'
```

Expected: PASS；`git diff --check` 无新增空白错误。

## Task 2: 冲突确认界面与整批导入确认

**Files:**
- Modify: `lib/screens/add_course_page.dart`
- Modify: `lib/screens/reschedule_course_page.dart`
- Modify: `lib/screens/import_course_page.dart`
- Modify: `lib/widgets/common/app_ui.dart`
- Modify: `lib/app_localizations.dart`
- Modify: `test/widgets/add_course_page_test.dart`
- Create: `test/widgets/reschedule_course_page_test.dart`
- Create: `test/widgets/import_course_page_conflict_test.dart`

- [ ] **Step 1: 写新增、编辑、调课与导入冲突确认失败测试**

Widget 测试应断言：

```dart
expect(find.text('发现课程时间冲突'), findsOneWidget);
expect(find.textContaining('线性代数'), findsWidgets);
expect(find.textContaining('大学英语'), findsWidgets);
await tester.tap(find.text('取消'));
expect(provider.courses.where((course) => course.name == '线性代数'), isEmpty);
```

确认路径点击“仍然保存”，断言课程写入。导入页面使用可注入或提取后的批次处理函数，断言一批多个冲突只显示一个确认框，取消后旧教务批次完整保留。

- [ ] **Step 2: 运行 Widget 测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/widgets/add_course_page_test.dart test/widgets/reschedule_course_page_test.dart test/widgets/import_course_page_conflict_test.dart'
```

Expected: FAIL，尚无冲突确认界面。

- [ ] **Step 3: 增加公共汇总确认框**

在 `app_ui.dart` 增加：

```dart
Future<bool> showCourseConflictConfirmDialog(
  BuildContext context, {
  required List<CourseConflict> conflicts,
}) {
  final summary = conflicts
      .map(
        (item) =>
            '${item.candidate.name} 与 ${item.existingCourse.name}：'
            '周${item.candidate.weekday} 第${item.candidate.startPeriod}-'
            '${item.candidate.endPeriod}节',
      )
      .toSet()
      .join('\n');
  return showAppConfirmDialog(
    context,
    title: '发现课程时间冲突',
    message: summary,
    confirmLabel: '仍然保存',
    cancelLabel: '取消',
  );
}
```

- [ ] **Step 4: 在三个保存入口接入“预检后重试”**

新增保存按以下顺序执行：

```dart
final conflicts = provider.findCourseConflicts(
  candidates,
  ignoredCourseId: existingCourse?.id,
);
var allowConflicts = false;
if (conflicts.isNotEmpty) {
  allowConflicts = await showCourseConflictConfirmDialog(
    context,
    conflicts: conflicts,
  );
  if (!allowConflicts || !mounted) {
    return;
  }
}
final saved = await provider.addCourses(
  candidates,
  allowConflicts: allowConflicts,
);
```

编辑保存使用同一确认流程，预检传入 `ignoredCourseId: existingCourse.id`，确认后调用：

```dart
await provider.updateCourse(
  originalCourse: existingCourse,
  updatedCourse: candidate,
  allowConflicts: allowConflicts,
);
```

调课保存调用 Provider 级预检，确认后重试实际写入：

```dart
final conflicts = provider.findRescheduleCourseConflicts(
  originalCourse: widget.course,
  sourceWeek: widget.sourceWeek,
  targetWeek: targetWeek,
  targetWeekday: targetWeekday,
  targetStartPeriod: targetStartPeriod,
);
final allowConflicts = conflicts.isNotEmpty
    ? await showCourseConflictConfirmDialog(context, conflicts: conflicts)
    : false;
if (conflicts.isNotEmpty && !allowConflicts) {
  return;
}
await provider.rescheduleCourseOccurrence(
  originalCourse: widget.course,
  sourceWeek: widget.sourceWeek,
  targetWeek: targetWeek,
  targetWeekday: targetWeekday,
  targetStartPeriod: targetStartPeriod,
  allowConflicts: allowConflicts,
);
```

导入页面解析后先调用 `findImportedCourseConflicts(parseReport.items)`，只显示一次汇总框；用户确认后调用：

```dart
await courseProvider.mergeImportedCourses(
  parseReport.items,
  allowConflicts: true,
);
```

取消时直接返回，不修改课程、不刷新提醒。

- [ ] **Step 5: 将导入页可见英文错误改为中文**

替换以下消息：

```dart
'课表提取失败：$error'
'考试提取失败：$error'
'当前页面不属于允许导入的教务系统域名，请返回安徽大学教务页面后重试。'
'已阻止跳转到非教务系统页面：$url'
'课表导入失败：${error.message}'
'考试导入失败：${error.message}'
```

- [ ] **Step 6: 运行聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib/screens/add_course_page.dart lib/screens/reschedule_course_page.dart lib/screens/import_course_page.dart lib/widgets/common/app_ui.dart lib/app_localizations.dart test/widgets/add_course_page_test.dart test/widgets/reschedule_course_page_test.dart test/widgets/import_course_page_conflict_test.dart; flutter test test/widgets/add_course_page_test.dart test/widgets/reschedule_course_page_test.dart test/widgets/import_course_page_conflict_test.dart; git diff --check'
```

Expected: PASS；批次导入取消测试证明旧数据未变。

## Task 3: 课程和日程单项删除 Undo

**Files:**
- Modify: `lib/providers/course_provider.dart`
- Modify: `lib/widgets/timetable/timetable_detail_sheets.dart`
- Modify: `lib/app_localizations.dart`
- Modify: `test/providers/course_provider_test.dart`
- Modify: `test/widgets/course_details_sheet_test.dart`
- Create: `test/widgets/event_details_sheet_test.dart`

- [ ] **Step 1: 写 Provider 删除恢复失败测试**

在 `test/providers/course_provider_test.dart` 增加课程和日程各一组测试：

```dart
final removed = await provider.removeCourse(course);
expect(removed?.id, course.id);
expect(provider.courses, isEmpty);

await provider.restoreCourse(removed!);
expect(provider.courses.single.id, course.id);

await provider.restoreCourse(removed);
expect(provider.courses, hasLength(1));
expect(reminderRefreshCount, 2);
```

日程使用：

```dart
final removed = await provider.deleteEvent(event.id);
expect(removed?.id, event.id);
await provider.restoreEvent(removed!);
await provider.restoreEvent(removed);
expect(provider.events, hasLength(1));
```

提醒刷新计数只在实际删除和首次恢复时增加，重复恢复不写存储、不重复刷新。

- [ ] **Step 2: 运行 Provider 测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/providers/course_provider_test.dart'
```

Expected: FAIL，删除方法尚不返回记录，恢复方法尚不存在。

- [ ] **Step 3: 实现删除返回值与幂等恢复**

在 `CourseProvider` 中替换删除方法并新增恢复方法：

```dart
Future<Course?> removeCourse(Course course) async {
  final index = _courses.indexWhere((item) => item.id == course.id);
  if (index == -1) {
    return null;
  }
  final removed = _courses.removeAt(index);
  notifyListeners();
  await _persistCourses();
  await _syncBackgroundRuntimeIfEnabled();
  await _refreshReminders();
  return removed;
}

Future<void> restoreCourse(Course course) async {
  if (_courses.any((item) => item.id == course.id)) {
    return;
  }
  _courses.add(course);
  notifyListeners();
  await _persistCourses();
  await _syncBackgroundRuntimeIfEnabled();
  await _refreshReminders();
}
```

日程实现同样模式：

```dart
Future<Event?> deleteEvent(String eventId)
Future<void> restoreEvent(Event event)
```

- [ ] **Step 4: 写详情弹层 Undo 失败测试**

课程和日程 Widget 测试都执行：

```dart
await tester.tap(find.text('删除课程'));
await tester.tap(find.text('删除课程').last);
await tester.pumpAndSettle();
expect(find.text('已删除课程'), findsOneWidget);
expect(find.text('撤销'), findsOneWidget);
await tester.tap(find.text('撤销'));
await tester.pumpAndSettle();
expect(provider.courses.single.id, course.id);
```

日程对应断言 `已删除日程` 和 `provider.events`。

- [ ] **Step 5: 运行详情弹层测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/widgets/course_details_sheet_test.dart test/widgets/event_details_sheet_test.dart'
```

Expected: FAIL，删除后没有带“撤销”的 SnackBar。

- [ ] **Step 6: 在父页面 Messenger 显示 Undo**

`showCourseDetailsSheet` 和 `showEventDetailsSheet` 在打开弹层前保存：

```dart
final messenger = ScaffoldMessenger.of(context);
```

确认删除后先关闭弹层，延迟执行删除，拿到实际删除记录后显示：

```dart
final removed = await courseProvider.removeCourse(course);
if (removed == null) {
  return;
}
messenger.showSnackBar(
  SnackBar(
    content: const Text('已删除课程'),
    action: SnackBarAction(
      label: '撤销',
      onPressed: () => courseProvider.restoreCourse(removed),
    ),
  ),
);
```

日程使用 `deleteEvent`、`restoreEvent` 和“已删除日程”。清空全部数据逻辑不改。

- [ ] **Step 7: 运行聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib/providers/course_provider.dart lib/widgets/timetable/timetable_detail_sheets.dart test/providers/course_provider_test.dart test/widgets/course_details_sheet_test.dart test/widgets/event_details_sheet_test.dart; flutter test test/providers/course_provider_test.dart test/widgets/course_details_sheet_test.dart test/widgets/event_details_sheet_test.dart; git diff --check'
```

Expected: PASS；撤销后数据只恢复一次。

## Task 4: 教务考试导入时间和专属考试页

**Files:**
- Modify: `lib/models/event.dart`
- Modify: `lib/providers/course_provider.dart`
- Create: `lib/screens/exam_overview_page.dart`
- Modify: `lib/core/app_routes.dart`
- Modify: `lib/screens/timetable_page.dart`
- Modify: `lib/app_localizations.dart`
- Modify: `test/models/event_test.dart`
- Modify: `test/providers/course_provider_test.dart`
- Create: `test/widgets/exam_overview_page_test.dart`
- Modify: `test/widgets/timetable_page_test.dart`

- [ ] **Step 1: 写 `Event.importedAt` 失败测试**

在 `test/models/event_test.dart` 增加：

```dart
test('event json preserves nullable imported time', () {
  final importedAt = DateTime(2026, 6, 1, 10, 30);
  final event = Event(
    name: '考试',
    location: 'A101',
    dateTime: DateTime(2026, 6, 8, 9),
    enableAlarm: true,
    importedAt: importedAt,
  );
  expect(Event.fromJson(event.toJson()).importedAt, importedAt);
  expect(Event.fromJson({...event.toJson(), 'importedAt': 'broken'}).importedAt, isNull);
  expect(Event.fromJson({...event.toJson()}..remove('importedAt')).importedAt, isNull);
});
```

- [ ] **Step 2: 运行模型测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/models/event_test.dart'
```

Expected: FAIL，`Event` 尚无 `importedAt`。

- [ ] **Step 3: 增加可空导入时间**

在 `Event` 构造函数、字段、`copyWith`、`toJson` 和 `fromJson` 增加：

```dart
final DateTime? importedAt;

importedAt: importedAt ?? this.importedAt,

'importedAt': importedAt?.toIso8601String(),

final rawImportedAt = json['importedAt'];
final importedAt = rawImportedAt is String
    ? DateTime.tryParse(rawImportedAt)
    : null;
```

`dateTime` 继续严格校验；`importedAt` 损坏只降级为 `null`。

- [ ] **Step 4: 写统一批次导入时间失败测试**

在 `test/providers/course_provider_test.dart` 的考试导入测试增加：

```dart
expect(imported.importedAt, isNotNull);
expect(
  provider.events
      .where((event) => event.importSource == CourseProvider.academicExamImportSource)
      .map((event) => event.importedAt)
      .toSet(),
  hasLength(1),
);
expect(manualEvent.importedAt, isNull);
```

- [ ] **Step 5: 为考试导入写入同一时间**

在 `mergeImportedEvents` 进入循环前捕获：

```dart
final importedAt = DateTime.now();
```

每个 `sanitizedEvent` 写入：

```dart
importedAt: importedAt,
```

- [ ] **Step 6: 写考试页失败测试**

新增 `test/widgets/exam_overview_page_test.dart`，提供手动日程、未来教务考试、当天教务考试和已结束教务考试。断言：

```dart
expect(find.text('教务考试'), findsOneWidget);
expect(find.text('手工会议'), findsNothing);
expect(find.text('教务系统'), findsNWidgets(3));
expect(find.textContaining('还有'), findsWidgets);
expect(find.text('今天'), findsOneWidget);
expect(find.text('已结束'), findsOneWidget);
expect(find.textContaining('最近导入'), findsWidgets);
```

空数据时断言“暂无教务考试”和“导入考试”按钮；点击按钮后出现 `ImportCoursePage`。

- [ ] **Step 7: 运行考试页测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/widgets/exam_overview_page_test.dart'
```

Expected: FAIL，考试页不存在。

- [ ] **Step 8: 新增考试页**

`ExamOverviewPage` 使用 `context.watch<CourseProvider>()`，只取：

```dart
final exams = courseProvider.events
    .where(
      (event) =>
          event.importSource == CourseProvider.academicExamImportSource,
    )
    .toList()
  ..sort((left, right) => left.dateTime.compareTo(right.dateTime));
```

页面展示日期时间、地点、`note`、来源、最近导入时间和倒计时。倒计时辅助函数以本地日期比较：

```dart
String examCountdownLabel(DateTime examTime, DateTime now) {
  final examDate = DateTime(examTime.year, examTime.month, examTime.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = examDate.difference(today).inDays;
  if (days < 0) return '已结束';
  if (days == 0) return '今天';
  return '还有 $days 天';
}
```

卡片点击调用 `showEventDetailsSheet(context, event)`；空状态按钮跳转 `AppRoutes.importCourses`。

- [ ] **Step 9: 注册路由和课表入口**

在 `AppRoutes` 增加：

```dart
static const String exams = '/exams';
```

路由返回 `const ExamOverviewPage()`。课表工具栏常规宽度增加考试 IconButton：

```dart
IconButton(
  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.exams),
  icon: const Icon(Icons.assignment_outlined),
  tooltip: '教务考试',
)
```

- [ ] **Step 10: 运行聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib/models/event.dart lib/providers/course_provider.dart lib/screens/exam_overview_page.dart lib/core/app_routes.dart lib/screens/timetable_page.dart test/models/event_test.dart test/providers/course_provider_test.dart test/widgets/exam_overview_page_test.dart test/widgets/timetable_page_test.dart; flutter test test/models/event_test.dart test/providers/course_provider_test.dart test/widgets/exam_overview_page_test.dart test/widgets/timetable_page_test.dart; git diff --check'
```

Expected: PASS；考试页不显示手动日程。

## Task 5: 主题令牌、黑白前景策略与三档主题模式

**Files:**
- Create: `lib/core/app_theme_tokens.dart`
- Modify: `lib/core/app_theme.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/providers/settings_provider.dart`
- Modify: `lib/screens/settings_page.dart`
- Modify: `lib/main.dart`
- Create: `lib/widgets/timetable_app.dart`
- Modify: `lib/app_localizations.dart`
- Modify: `pubspec.yaml`
- Create: `test/core/app_theme_tokens_test.dart`
- Modify: `test/services/storage_service_test.dart`
- Modify: `test/providers/settings_provider_test.dart`
- Create: `test/widgets/theme_mode_settings_test.dart`

- [ ] **Step 1: 写前景策略失败测试**

新增 `test/core/app_theme_tokens_test.dart`：

```dart
test('best contrasting foreground chooses black or white', () {
  expect(bestContrastingForeground(const Color(0xFFFFFFFF)), Colors.black);
  expect(bestContrastingForeground(const Color(0xFF111827)), Colors.white);
});

test('preset palette foreground reaches wcag aa contrast', () {
  for (final colorValue in {
    ...AppColors.coursePaletteValues,
    ...AppColors.themePickerPaletteValues,
  }) {
    final background = Color(colorValue);
    final foreground = bestContrastingForeground(background);
    expect(contrastRatio(background, foreground), greaterThanOrEqualTo(4.5));
  }
});
```

- [ ] **Step 2: 运行前景策略测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/core/app_theme_tokens_test.dart'
```

Expected: FAIL，`app_theme_tokens.dart` 不存在。

- [ ] **Step 3: 实现主题令牌和对比度函数**

新增：

```dart
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.pageBackground,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.infoSurface,
    required this.warningSurface,
    required this.dangerSurface,
  });

  final Color pageBackground;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color infoSurface;
  final Color warningSurface;
  final Color dangerSurface;

  static const light = AppThemeTokens(
    pageBackground: Color(0xFFF3F7FF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF8FAFC),
    surfaceMuted: Color(0xFFF1F5F9),
    divider: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF334155),
    textTertiary: Color(0xFF64748B),
    infoSurface: Color(0xFFEFF6FF),
    warningSurface: Color(0xFFFFFBEB),
    dangerSurface: Color(0xFFFEE2E2),
  );

  static const dark = AppThemeTokens(
    pageBackground: Color(0xFF0F172A),
    surface: Color(0xFF172033),
    surfaceRaised: Color(0xFF1E293B),
    surfaceMuted: Color(0xFF263449),
    divider: Color(0xFF3A4A62),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textTertiary: Color(0xFF94A3B8),
    infoSurface: Color(0xFF172554),
    warningSurface: Color(0xFF422006),
    dangerSurface: Color(0xFF450A0A),
  );

  @override
  AppThemeTokens copyWith({
    Color? pageBackground,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? infoSurface,
    Color? warningSurface,
    Color? dangerSurface,
  }) {
    return AppThemeTokens(
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      infoSurface: infoSurface ?? this.infoSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
    );
  }

  @override
  AppThemeTokens lerp(covariant AppThemeTokens? other, double t) {
    if (other == null) return this;
    return AppThemeTokens(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
    );
  }
}

double contrastRatio(Color left, Color right) {
  final lighter = math.max(left.computeLuminance(), right.computeLuminance());
  final darker = math.min(left.computeLuminance(), right.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}

Color bestContrastingForeground(Color background) {
  return contrastRatio(background, Colors.black) >=
          contrastRatio(background, Colors.white)
      ? Colors.black
      : Colors.white;
}
```

- [ ] **Step 4: 写主题模式持久化失败测试**

在存储与 Provider 测试中加入：

```dart
expect(storage.readAppThemeMode(), AppThemeMode.system);
await storage.writeAppThemeMode(AppThemeMode.dark);
expect(storage.readAppThemeMode(), AppThemeMode.dark);

SharedPreferences.setMockInitialValues({'settings.appThemeMode': 'broken'});
expect(storage.readAppThemeMode(), AppThemeMode.system);

await provider.changeAppThemeMode(AppThemeMode.dark);
expect(provider.appThemeMode, AppThemeMode.dark);
expect(provider.materialThemeMode, ThemeMode.dark);
```

- [ ] **Step 5: 运行主题模式测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/core/app_theme_tokens_test.dart test/services/storage_service_test.dart test/providers/settings_provider_test.dart'
```

Expected: FAIL，缺少 `AppThemeMode` 和读写接口。

- [ ] **Step 6: 实现主题模式存储和 Provider**

在 `storage_service.dart` 定义：

```dart
enum AppThemeMode { system, light, dark }
```

增加键和读写：

```dart
static const String _appThemeModeKey = 'settings.appThemeMode';

AppThemeMode readAppThemeMode({AppThemeMode fallback = AppThemeMode.system}) {
  final raw = _sharedPreferences.getString(_appThemeModeKey);
  return AppThemeMode.values.where((mode) => mode.name == raw).firstOrNull ??
      fallback;
}

Future<void> writeAppThemeMode(AppThemeMode mode) {
  return _setString(_appThemeModeKey, mode.name);
}
```

如果当前 Dart SDK 不支持 `firstOrNull`，使用显式 `for` 循环返回匹配值。`SettingsProvider` 初始化 `_appThemeMode`，公开：

```dart
AppThemeMode get appThemeMode => _appThemeMode;
ThemeMode get materialThemeMode => switch (_appThemeMode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};

Future<void> changeAppThemeMode(AppThemeMode mode) async {
  if (mode == _appThemeMode) return;
  _appThemeMode = mode;
  notifyListeners();
  await _storageService.writeAppThemeMode(mode);
}
```

- [ ] **Step 7: 将 `AppTheme` 改为亮暗双主题**

保留 `light` 并新增 `dark`，内部共用：

```dart
static ThemeData _build({
  required Brightness brightness,
  required AppThemePalette palette,
}) {
  final tokens = brightness == Brightness.dark
      ? AppThemeTokens.dark
      : AppThemeTokens.light.copyWith(
          pageBackground: palette.scaffoldBackground,
          surfaceMuted: palette.surfaceMuted,
          divider: palette.divider,
        );
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  ).copyWith(
    primary: palette.primary,
    secondary: palette.accent,
    surface: tokens.surface,
    onSurface: tokens.textPrimary,
    onPrimary: bestContrastingForeground(palette.primary),
    onSecondary: bestContrastingForeground(palette.accent),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.pageBackground,
    extensions: <ThemeExtension<dynamic>>[tokens],
    useMaterial3: true,
  );
}
```

在返回的 `ThemeData` 中继续保留当前已有的 `pageTransitionsTheme`、`appBarTheme`、`bottomNavigationBarTheme`、`snackBarTheme`、`cardTheme`、`inputDecorationTheme`、按钮主题、`floatingActionButtonTheme`、`chipTheme`、`sliderTheme`、`bottomSheetTheme` 和 `dividerColor`；这些配置中的固定浅色表面逐项替换为 `tokens`，强调色和前景改用 `scheme`。

- [ ] **Step 8: 写设置入口和根应用失败测试**

新增 `test/widgets/theme_mode_settings_test.dart`，断言：

```dart
expect(find.text('显示模式'), findsOneWidget);
await tester.tap(find.text('显示模式'));
expect(find.text('跟随系统'), findsOneWidget);
expect(find.text('浅色'), findsOneWidget);
expect(find.text('深色'), findsOneWidget);
await tester.tap(find.text('深色'));
await tester.pumpAndSettle();
expect(provider.appThemeMode, AppThemeMode.dark);
```

根应用测试泵入 `TimetableApp(settingsProvider: provider)`，从 Widget 树读取 `MaterialApp`，断言 `themeMode == ThemeMode.dark` 且 `darkTheme != null`。

- [ ] **Step 9: 接入设置页和根应用**

设置页外观区域改成包含两个 `AppActionTile` 的 `Column`：主题颜色和显示模式。显示模式使用现有 `showAppOptionPicker<AppThemeMode>`：

```dart
options: const [
  AppPickerOption(value: AppThemeMode.system, label: '跟随系统'),
  AppPickerOption(value: AppThemeMode.light, label: '浅色'),
  AppPickerOption(value: AppThemeMode.dark, label: '深色'),
],
```

新增 `TimetableApp`，接收 `SettingsProvider` 并构造主 `MaterialApp`。主应用 `Consumer<SettingsProvider>` 返回该组件；加载页和初始化错误页继续在 `main.dart` 中构造轻量 `MaterialApp`。三个入口都配置：

```dart
theme: AppTheme.light(palette: palette),
darkTheme: AppTheme.dark(palette: palette),
themeMode: settingsProvider.materialThemeMode,
```

`TimetableApp` 中同时配置 `locale`、路由和滚动行为。加载和错误页没有 Provider 时使用 `ThemeMode.system` 与默认 palette。

- [ ] **Step 10: 运行聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib/core/app_theme_tokens.dart lib/core/app_theme.dart lib/services/storage_service.dart lib/providers/settings_provider.dart lib/screens/settings_page.dart lib/main.dart lib/widgets/timetable_app.dart test/core/app_theme_tokens_test.dart test/services/storage_service_test.dart test/providers/settings_provider_test.dart test/widgets/theme_mode_settings_test.dart; flutter test test/core/app_theme_tokens_test.dart test/services/storage_service_test.dart test/providers/settings_provider_test.dart test/widgets/theme_mode_settings_test.dart; git diff --check'
```

Expected: PASS；未知存储值回退 `system`。

## Task 6: 仅保留中文并迁移主要暗色界面

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/main.dart`
- Modify: `lib/widgets/timetable_app.dart`
- Modify: `lib/providers/settings_provider.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `lib/models/event.dart`
- Modify: `lib/widgets/common/app_ui.dart`
- Modify: `lib/widgets/common/app_wheel_pickers.dart`
- Modify: `lib/widgets/common/capsule_multi_select.dart`
- Modify: `lib/widgets/timetable/course_card.dart`
- Modify: `lib/widgets/timetable/event_card.dart`
- Modify: `lib/widgets/timetable/course_overview_panel.dart`
- Modify: `lib/widgets/timetable/timetable_detail_sheets.dart`
- Modify: `lib/widgets/timetable/timetable_grid.dart`
- Modify: `lib/screens/theme_settings_page.dart`
- Modify: `lib/screens/reschedule_course_page.dart`
- Modify: `lib/screens/semester_time_settings_page.dart`
- Modify: `test/providers/settings_provider_test.dart`
- Modify: `test/widgets/theme_mode_settings_test.dart`

- [ ] **Step 1: 写仅中文运行模式失败测试**

在 Provider 测试中加入：

```dart
SharedPreferences.setMockInitialValues({'settings.languageCode': 'en'});
final provider = SettingsProvider(storageService: storage);
expect(provider.languageCode, 'zh');
expect(provider.t('settings'), '设置');
```

Widget 测试断言：

```dart
expect(app.supportedLocales, const [Locale('zh')]);
expect(app.localizationsDelegates, isNotEmpty);
```

- [ ] **Step 2: 运行中文模式测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/providers/settings_provider_test.dart test/widgets/theme_mode_settings_test.dart'
```

Expected: FAIL，旧语言偏好仍会切换到英文。

- [ ] **Step 3: 固定中文并启用 Material 中文本地化**

`SettingsProvider` 删除 `_languageCode` 字段和 `changeLanguage`，改为：

```dart
String get languageCode => 'zh';
String t(String key) => AppStrings.get(key, 'zh');
```

保留 `StorageService` 的旧语言键读取兼容，但删除新写入入口。`pubspec.yaml` 增加：

```yaml
  flutter_localizations:
    sdk: flutter
```

`main.dart` 增加：

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

supportedLocales: const [Locale('zh')],
localizationsDelegates: GlobalMaterialLocalizations.delegates,
```

同时把 `Event.fromJson` 的默认名称改为“未命名日程”，初始化错误默认文本改为“未知初始化错误”。

- [ ] **Step 4: 写主要暗色界面失败测试**

在 `theme_mode_settings_test.dart` 用 `Theme(data: AppTheme.dark(), child: ...)` 包裹公共组件并断言：

```dart
final tokens = Theme.of(element).extension<AppThemeTokens>()!;
expect(tokens.surface, isNot(AppThemeTokens.light.surface));
expect(find.byType(AppSurface), findsWidgets);
```

渲染 `AppSurface`、`AppEmptyState`、`EventCard`、`TimetableGrid` 和详情弹层，确认没有固定浅色背景断言失败或 overflow 异常。

- [ ] **Step 5: 将公共组件和课表主要组件改用令牌**

在需要读取令牌的 `build` 中统一使用：

```dart
final tokens = Theme.of(context).extension<AppThemeTokens>()!;
```

替换规则：

```text
AppColors.surface       -> tokens.surface
AppColors.surfaceRaised -> tokens.surfaceRaised
AppColors.surfaceMuted  -> tokens.surfaceMuted
AppColors.divider       -> tokens.divider
AppColors.textPrimary   -> tokens.textPrimary
AppColors.textSecondary -> tokens.textSecondary
AppColors.textTertiary  -> tokens.textTertiary
AppColors.onPrimary     -> Theme.of(context).colorScheme.onPrimary
```

`AppSurface` 的 `color`、`borderColor` 改为可空参数，在 `build` 内分别回退 `tokens.surface` 和 `tokens.divider`。危险按钮前景使用 `Theme.of(context).colorScheme.onError`。

- [ ] **Step 6: 运行依赖解析、聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter pub get; dart format lib/main.dart lib/widgets/timetable_app.dart lib/providers/settings_provider.dart lib/services/storage_service.dart lib/models/event.dart lib/widgets/common/app_ui.dart lib/widgets/common/app_wheel_pickers.dart lib/widgets/common/capsule_multi_select.dart lib/widgets/timetable/course_card.dart lib/widgets/timetable/event_card.dart lib/widgets/timetable/course_overview_panel.dart lib/widgets/timetable/timetable_detail_sheets.dart lib/widgets/timetable/timetable_grid.dart lib/screens/theme_settings_page.dart lib/screens/reschedule_course_page.dart lib/screens/semester_time_settings_page.dart test/providers/settings_provider_test.dart test/widgets/theme_mode_settings_test.dart; flutter test test/providers/settings_provider_test.dart test/widgets/theme_mode_settings_test.dart; git diff --check'
```

Expected: PASS；旧 `settings.languageCode=en` 不改变运行时中文。

## Task 7: 色块语义、引导播报、窄屏工具栏和大字体滚轮

**Files:**
- Modify: `lib/core/app_colors.dart`
- Modify: `lib/screens/add_course_page.dart`
- Modify: `lib/screens/theme_settings_page.dart`
- Modify: `lib/screens/timetable_page.dart`
- Modify: `lib/widgets/common/guided_tour_overlay.dart`
- Modify: `lib/widgets/common/app_wheel_pickers.dart`
- Modify: `test/widgets/add_course_page_test.dart`
- Modify: `test/widgets/guided_tour_overlay_test.dart`
- Modify: `test/widgets/timetable_page_test.dart`
- Create: `test/widgets/responsive_accessibility_test.dart`

- [ ] **Step 1: 写色块和引导语义失败测试**

在 Widget 测试中读取 semantics：

```dart
final semantics = tester.getSemantics(find.byKey(const ValueKey('course-color-0')));
expect(semantics.label, contains('颜色 1，青绿'));
expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
```

主题颜色色块同样断言序号和中文颜色名。引导层测试调用 `showGuidedTourOverlay` 后检查：

```dart
expect(find.bySemanticsLabel('功能引导'), findsOneWidget);
expect(find.bySemanticsLabel(contains('第 1 步，共 2 步')), findsWidgets);
```

- [ ] **Step 2: 运行语义测试并确认红灯**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test test/widgets/add_course_page_test.dart test/widgets/guided_tour_overlay_test.dart test/widgets/responsive_accessibility_test.dart'
```

Expected: FAIL，色块语义缺少颜色名，引导屏障仍为英文。

- [ ] **Step 3: 增加可复用中文颜色名和动态勾选前景**

在 `AppColors` 中增加与调色盘值匹配的方法：

```dart
static String colorName(int value) {
  return switch (value) {
    0xFF0D9488 => '青绿',
    0xFF2563EB => '蓝色',
    0xFFF97316 => '橙色',
    0xFFDB2777 => '粉色',
    0xFF7C3AED => '紫色',
    0xFF16A34A => '绿色',
    0xFF0891B2 => '青色',
    0xFFDC2626 => '红色',
    0xFFCA8A04 => '金色',
    0xFF4F46E5 => '靛蓝',
    0xFFF59E0B => '琥珀',
    0xFF84CC16 => '青柠',
    0xFF475569 => '灰蓝',
    _ => '自定义',
  };
}
```

课程色块和主题色块都补 `ValueKey`，语义标签统一为：

```dart
label: '颜色 ${index + 1}，${AppColors.colorName(colorValue)}',
```

选中勾选图标前景使用：

```dart
bestContrastingForeground(Color(colorValue))
```

- [ ] **Step 4: 中文化引导屏障并合并步骤语义**

`showGeneralDialog` 改为：

```dart
barrierLabel: '功能引导',
```

在 `_GuidedTourCard` 的步骤文本区域增加合并语义，不包裹底部操作按钮：

```dart
Semantics(
  container: true,
  label: '$stepLabel，$title，$body',
  child: ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stepLabel),
        const SizedBox(height: 8),
        Text(title),
        const SizedBox(height: 8),
        Text(body),
      ],
    ),
  ),
)
```

步骤文本区域之后继续渲染现有 `FilledButton`，保留单独可点击语义，确保 TalkBack 能播报当前步骤、总步骤和可执行操作。

- [ ] **Step 5: 写窄屏工具栏失败测试**

在 `test/widgets/timetable_page_test.dart` 增加：

```dart
await tester.binding.setSurfaceSize(const Size(320, 720));
await tester.pumpWidget(buildTimetablePage());
await tester.pumpAndSettle();
expect(tester.takeException(), isNull);
expect(find.byTooltip('更多操作'), findsOneWidget);
await tester.tap(find.byTooltip('更多操作'));
await tester.pumpAndSettle();
expect(find.text('总览'), findsOneWidget);
expect(find.text('教务考试'), findsOneWidget);
expect(find.text('导入教务课表'), findsOneWidget);
expect(find.text('添加课程'), findsOneWidget);
```

- [ ] **Step 6: 用 `LayoutBuilder` 收敛窄屏操作**

在课表页将 AppBar 构造提取为 `_buildAppBar`。宽度低于 `420` 时标题只保留周次和今天，actions 只保留：

```dart
PopupMenuButton<_TimetableToolbarAction>(
  tooltip: '更多操作',
  itemBuilder: (_) => const [
    PopupMenuItem(value: _TimetableToolbarAction.overview, child: Text('总览')),
    PopupMenuItem(value: _TimetableToolbarAction.exams, child: Text('教务考试')),
    PopupMenuItem(value: _TimetableToolbarAction.import, child: Text('导入教务课表')),
    PopupMenuItem(value: _TimetableToolbarAction.addCourse, child: Text('添加课程')),
  ],
  onSelected: _handleToolbarAction,
)
```

宽屏继续显示总览、考试、导入、新增。所有 `IconButton` 和菜单入口保留中文 tooltip 或文本；按钮约束不小于 `44dp`。

- [ ] **Step 7: 写大字体滚轮失败测试**

在 `test/widgets/responsive_accessibility_test.dart` 设置：

```dart
MediaQuery(
  data: const MediaQueryData(
    size: Size(320, 480),
    textScaler: TextScaler.linear(2),
  ),
  child: testApp,
)
```

打开 `showAppClockTimePicker`，断言：

```dart
expect(tester.takeException(), isNull);
expect(find.text('取消'), findsOneWidget);
expect(find.text('确认'), findsOneWidget);
```

- [ ] **Step 8: 约束滚轮弹层可用高度**

`_showWheelPickerSheet` 的 builder 增加：

```dart
final mediaQuery = MediaQuery.of(sheetContext);
return ConstrainedBox(
  constraints: BoxConstraints(
    maxHeight: mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom,
  ),
  child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xxl,
      0,
      AppSpacing.xxl,
      AppSpacing.xxl,
    ),
    child: child,
  ),
);
```

确认和取消仍位于滚动内容中，低高度或 `200%` 字体时可滚动到达。

- [ ] **Step 9: 运行聚焦测试和差异检查**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib/core/app_colors.dart lib/screens/add_course_page.dart lib/screens/theme_settings_page.dart lib/screens/timetable_page.dart lib/widgets/common/guided_tour_overlay.dart lib/widgets/common/app_wheel_pickers.dart test/widgets/add_course_page_test.dart test/widgets/guided_tour_overlay_test.dart test/widgets/timetable_page_test.dart test/widgets/responsive_accessibility_test.dart; flutter test test/widgets/add_course_page_test.dart test/widgets/guided_tour_overlay_test.dart test/widgets/timetable_page_test.dart test/widgets/responsive_accessibility_test.dart; git diff --check'
```

Expected: PASS；`320dp` 和 `200%` 字体场景无 overflow 异常。

## Task 8: 全量验证与临时产物审计

**Files:**
- Verify only: all modified files

- [ ] **Step 1: 运行 Dart 格式化**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'dart format lib test'
```

Expected: 格式化完成，无命令错误。

- [ ] **Step 2: 运行 Flutter 全量测试**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter test'
```

Expected: 全部测试 PASS。

- [ ] **Step 3: 运行静态分析**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter analyze'
```

Expected: `No issues found!`

- [ ] **Step 4: 验证 Android Kotlin 编译和 JVM 测试**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '.\gradlew.bat app:compileDebugKotlin app:testDebugUnitTest --no-daemon'
```

Workdir: `android`

Expected: `BUILD SUCCESSFUL`。允许现有 Android Gradle Plugin 对 compileSdk 36 的兼容性提示，但不允许新增编译错误。

- [ ] **Step 5: 验证 Web 发布构建**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter build web --release'
```

Expected: 构建成功。

- [ ] **Step 6: 验证 Windows Debug 构建**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'flutter build windows --debug'
```

Expected: 构建成功。

- [ ] **Step 7: 检查差异空白问题**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command 'git diff --check'
```

Expected: 没有新增空白错误；Windows 行尾转换提醒可以记录但不视为失败。

- [ ] **Step 8: 扫描临时测试产物**

Run:

```powershell
pwsh -NoLogo -NoProfile -Command '$temporary = Get-ChildItem -LiteralPath ''lib'',''test'',''docs'',''tool'' -Force -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match ''(^tmp|\.tmp$|\.bak$|\.orig$|\.rej$)'' }; if ($temporary) { $temporary | Select-Object -ExpandProperty FullName; exit 1 }; ''NO_TEMP_ARTIFACTS'''
```

Expected: `NO_TEMP_ARTIFACTS`。若发现仅用于验证的临时文件，确认绝对路径位于当前工作树后使用 `Remove-Item -LiteralPath` 删除，再重新扫描。

## 最终验收清单

- [ ] 不同课程冲突需要确认；相同身份重复仍直接拒绝。
- [ ] 教务导入只弹一次批次冲突确认；取消不修改旧批次。
- [ ] 单门课程和单条日程删除均可撤销；清空全部数据仍不可撤销。
- [ ] 专属考试页只展示 `academic.exam`，旧记录导入时间未知时仍可展示。
- [ ] 三档主题模式可持久化，非法值回退跟随系统。
- [ ] 主要课表、设置和弹层在深色主题下使用暗色表面和可读前景。
- [ ] 运行时固定中文，Material 控件启用中文本地化。
- [ ] 课程和主题色块有中文颜色语义与视觉勾选。
- [ ] 引导层屏障为中文，步骤语义包含当前进度。
- [ ] `320dp` 工具栏和 `200%` 字体滚轮无 overflow。
- [ ] Flutter、Android、Web、Windows 和差异检查全部通过。
