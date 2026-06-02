# M4a Basic UX And Accessibility Design

## Scope

This milestone repairs four small but visible usability gaps without adding
new screens, navigation concepts, or theme infrastructure.

## Empty-State Actions

- Reuse the existing `AppEmptyState.action` slot.
- Day agenda empty states expose a compact action row with:
  - Add course.
  - Import courses.
- Week views expose the same action row when the entire week has no courses or
  events.
- Holiday empty states expose the same add-course and import-course actions.
- The course-overview empty state exposes add-course and import-course
  actions.
- Route handling remains owned by `TimetablePage`; presentation widgets only
  receive callbacks or action widgets.
- Import actions reuse the existing semester-initialization guard and import
  summary flow.

## Teaching-Week Quick Selection

- Add four compact quick actions above the teaching-week selector:
  - Select all.
  - Clear.
  - Odd weeks.
  - Even weeks.
- Each action replaces the selected-week set and keeps values ordered when a
  course is persisted.
- Existing drag selection remains available.
- Validation still prevents saving a course with no selected teaching weeks.

## Accessible Color Selection

- Keep the existing preset-color layout and selected state.
- Give every color option a stable, distinct semantics label containing its
  one-based option number.
- Preserve the selected semantics flag so screen readers announce the current
  choice.

## Guided-Tour Semantics Isolation

- While the guided tour overlay is visible, prevent screen readers from
  traversing underlying timetable content.
- Keep the overlay card content and its action button discoverable.
- Preserve the visible highlight and existing non-dismissible behavior.

## Verification

- Add focused widget tests for:
  - Week quick actions.
  - Empty-state navigation callbacks.
  - Distinct color-option semantics labels.
  - Guided-tour semantics isolation.
- Run focused widget tests after each red-green-refactor cycle.
- Pass full `flutter test`, `flutter analyze`, modified Dart formatting, and
  `git diff --check`.

## Deferred Work

- Conflict confirmation before save and import.
- Delete undo.
- Course-overview search and filtering.
- Dedicated exam view.
- Dark mode and localization completion.
- Android time-change rescheduling, diagnostic result truthfulness, and
  damaged-row diagnostics.
