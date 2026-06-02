# M4a Basic UX And Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Add practical empty-state actions, teaching-week quick selection,
distinct color semantics, and guided-tour semantics isolation.

**Architecture:** Keep navigation orchestration in `TimetablePage`, pass
optional action widgets through presentation components, and extend the
existing course form without changing persistence behavior. Isolate guided
tour accessibility inside the overlay so callers remain unchanged.

**Tech Stack:** Flutter, Dart, Provider, `flutter_test`.

---

### Task 1: Add Teaching-Week Quick Selection And Color Semantics

**Files:**
- Modify: `lib/app_localizations.dart`
- Modify: `lib/screens/add_course_page.dart`
- Test: `test/widgets/add_course_page_test.dart`

- [ ] Add widget tests that tap select-all, clear, odd-week, and even-week
  actions and assert the selected teaching weeks saved by `CourseProvider`.
- [ ] Run `flutter test test/widgets/add_course_page_test.dart` and confirm the
  new tests fail because the quick-action controls are absent.
- [ ] Add localized labels for the four quick actions.
- [ ] Add four compact controls above the teaching-week selector. Each control
  replaces `_selectedWeeks` with the requested set.
- [ ] Add a widget semantics test that expects distinct labels such as
  `课程卡片颜色 1` and `课程卡片颜色 2`.
- [ ] Run `flutter test test/widgets/add_course_page_test.dart` and confirm all
  form tests pass.

### Task 2: Thread Empty-State Actions Through Timetable Widgets

**Files:**
- Modify: `lib/widgets/timetable/timetable_grid.dart`
- Modify: `lib/widgets/timetable/holiday_list_view.dart`
- Modify: `lib/widgets/timetable/course_overview_panel.dart`
- Modify: `lib/screens/timetable_page.dart`
- Test: `test/widgets/timetable_page_test.dart`

- [ ] Add widget tests asserting an empty timetable exposes add-course and
  import-course actions, and that tapping add-course opens `AddCoursePage`.
- [ ] Run `flutter test test/widgets/timetable_page_test.dart` and confirm the
  new tests fail because the empty-state actions are absent.
- [ ] Add an optional action widget to `EmptyScheduleState`, `DayAgendaView`,
  `TimetableGrid`, `HolidayListView`, and `CourseOverviewPanel`.
- [ ] Make `TimetableGrid` show `EmptyScheduleState` when the whole week is
  empty.
- [ ] Extract timetable-page helpers for add-course and guarded academic
  import navigation, then reuse them from the toolbar and empty-state buttons.
- [ ] Run `flutter test test/widgets/timetable_page_test.dart` and confirm all
  timetable-page tests pass.

### Task 3: Isolate Guided-Tour Semantics

**Files:**
- Modify: `lib/widgets/common/guided_tour_overlay.dart`
- Test: `test/widgets/guided_tour_overlay_test.dart`

- [ ] Add a semantics widget test asserting that underlying target content is
  hidden while the overlay card and action remain discoverable.
- [ ] Run `flutter test test/widgets/guided_tour_overlay_test.dart` and confirm
  the new test fails because underlying semantics remain visible.
- [ ] Wrap the overlay material with `BlockSemantics`, preserving the overlay
  card semantics and current visual behavior.
- [ ] Run `flutter test test/widgets/guided_tour_overlay_test.dart` and confirm
  the guided-tour tests pass.

### Task 4: Verify M4a

**Files:**
- Verify all modified Dart files.

- [ ] Run `dart format` on modified Dart files.
- [ ] Run focused widget tests for add-course, timetable-page, and guided-tour
  behavior.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Run `git diff --check`.
- [ ] Confirm no temporary test artifacts remain.

## Execution Notes

- Execute inline because no subagent delegation was requested.
- Preserve M1, M2, and M3 changes.
- Preserve the user-provided root `problem.md`.
- Do not stage or commit unless explicitly requested.
