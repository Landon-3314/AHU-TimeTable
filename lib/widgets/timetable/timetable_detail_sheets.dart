import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme_tokens.dart';
import '../../models/clock_time.dart';
import '../../models/course.dart';
import '../../models/event.dart';
import '../../providers/course_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/timetable_view_data_service.dart';
import '../common/app_ui.dart';
import '../semester_initialization_guard.dart';

Future<void> showCourseDetailsSheet(
  BuildContext context,
  Course course, {
  int? sourceWeek,
}) async {
  final settingsProvider = context.read<SettingsProvider>();
  final courseProvider = context.read<CourseProvider>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final timeSlots = settingsProvider.timeSlots;
  final weekdayLabels = TimetableViewDataService.weekdayKeys;
  final startSlot =
      course.startPeriod > 0 && course.startPeriod <= timeSlots.length
      ? timeSlots[course.startPeriod - 1]
      : null;
  final endSlot = course.endPeriod > 0 && course.endPeriod <= timeSlots.length
      ? timeSlots[course.endPeriod - 1]
      : null;
  final courseTimeText = startSlot != null && endSlot != null
      ? '${settingsProvider.t('time')}: ${_formatClockTime(startSlot.startTime)} - ${_formatClockTime(endSlot.endTime)} '
            '(${_periodRangeLabel(settingsProvider, course.startPeriod, course.endPeriod)})'
      : _periodRangeLabel(
          settingsProvider,
          course.startPeriod,
          course.endPeriod,
        );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final tokens = appThemeTokensOf(sheetContext);
      final actionButtons = <Widget>[
        if (sourceWeek != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tokens.surfaceMuted,
                foregroundColor: colorScheme.secondary,
              ),
              onPressed: () async {
                if (!await ensureCurrentSemesterInitialized(sheetContext)) {
                  return;
                }
                if (!sheetContext.mounted) {
                  return;
                }
                Navigator.of(sheetContext).pop();
                final didReschedule = await navigator.pushNamed<bool>(
                  AppRoutes.rescheduleCourse,
                  arguments: RescheduleCourseRouteArgs(
                    course: course,
                    sourceWeek: sourceWeek,
                  ),
                );

                if (didReschedule != true) {
                  return;
                }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(settingsProvider.t('reschedule_success')),
                  ),
                );
              },
              child: Text(settingsProvider.t('reschedule_course')),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            onPressed: () async {
              if (!await ensureCurrentSemesterInitialized(sheetContext)) {
                return;
              }
              if (!sheetContext.mounted) {
                return;
              }
              Navigator.of(sheetContext).pop();
              await navigator.pushNamed(
                AppRoutes.addCourse,
                arguments: AddCourseRouteArgs(existingCourse: course),
              );
            },
            child: Text(settingsProvider.t('edit_course')),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () async {
              final confirmed = await _confirmDestructiveAction(
                sheetContext,
                title: settingsProvider.t('confirm_delete_course_title'),
                message: settingsProvider.t('confirm_delete_course_message'),
                confirmLabel: settingsProvider.t('delete_course'),
                cancelLabel: settingsProvider.t('cancel'),
              );
              if (!confirmed) {
                return;
              }
              if (!sheetContext.mounted) {
                return;
              }
              if (!await ensureCurrentSemesterInitialized(sheetContext)) {
                return;
              }
              if (!sheetContext.mounted) {
                return;
              }
              Navigator.of(sheetContext).pop();
              unawaited(
                Future<void>.delayed(AppDurations.sheetActionDelay).then((
                  _,
                ) async {
                  try {
                    final removed = await courseProvider.removeCourse(course);
                    if (removed == null) {
                      return;
                    }
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('已删除课程'),
                        action: SnackBarAction(
                          label: '撤销',
                          onPressed: () {
                            unawaited(() async {
                              try {
                                if (!context.mounted) {
                                  return;
                                }
                                if (!await ensureCurrentSemesterInitialized(
                                  context,
                                )) {
                                  return;
                                }
                                await courseProvider.restoreCourse(removed);
                              } catch (error) {
                                debugPrint(
                                  '[TimetableDetailSheets] Failed to restore '
                                  'course: $error',
                                );
                              }
                            }());
                          },
                        ),
                      ),
                    );
                  } catch (error) {
                    debugPrint(
                      '[TimetableDetailSheets] Failed to delete course: $error',
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('删除课程失败')),
                    );
                  }
                }),
              );
            },
            child: Text(settingsProvider.t('delete_course')),
          ),
        ),
      ];

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: AppSpacing.floatingSheetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xl),
                DetailRow(
                  label: settingsProvider.t('teacher'),
                  value: course.teacher.isEmpty
                      ? settingsProvider.t('not_set')
                      : course.teacher,
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('location'),
                  value: course.location.isEmpty
                      ? settingsProvider.t('not_set')
                      : course.location,
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('periods'),
                  value: _periodRangeLabel(
                    settingsProvider,
                    course.startPeriod,
                    course.endPeriod,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('time'),
                  value: courseTimeText,
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('weekday'),
                  value: settingsProvider.t(weekdayLabels[course.weekday - 1]),
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('weeks'),
                  value: course.weeks.join(', '),
                ),
                const SizedBox(height: AppSpacing.xxl),
                for (int index = 0; index < actionButtons.length; index++) ...[
                  actionButtons[index],
                  if (index != actionButtons.length - 1)
                    const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showEventDetailsSheet(BuildContext context, Event event) async {
  final settingsProvider = context.read<SettingsProvider>();
  final courseProvider = context.read<CourseProvider>();
  final messenger = ScaffoldMessenger.of(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            padding: AppSpacing.floatingSheetPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xl),
                DetailRow(
                  label: settingsProvider.t('time'),
                  value: DateFormat('yyyy/MM/dd HH:mm').format(event.dateTime),
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('location'),
                  value: event.location.isEmpty
                      ? settingsProvider.t('not_set')
                      : event.location,
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('note'),
                  value: event.note.isEmpty
                      ? settingsProvider.t('not_set')
                      : event.note,
                ),
                const SizedBox(height: AppSpacing.md),
                DetailRow(
                  label: settingsProvider.t('alarm'),
                  value: event.enableAlarm
                      ? settingsProvider.t('enabled')
                      : settingsProvider.t('disabled'),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: () async {
                      final confirmed = await _confirmDestructiveAction(
                        sheetContext,
                        title: settingsProvider.t('confirm_delete_event_title'),
                        message: settingsProvider.t(
                          'confirm_delete_event_message',
                        ),
                        confirmLabel: settingsProvider.t('delete_event'),
                        cancelLabel: settingsProvider.t('cancel'),
                      );
                      if (!confirmed) {
                        return;
                      }
                      if (!sheetContext.mounted) {
                        return;
                      }
                      if (!await ensureCurrentSemesterInitialized(
                        sheetContext,
                      )) {
                        return;
                      }
                      if (!sheetContext.mounted) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      unawaited(
                        Future<void>.delayed(
                          AppDurations.sheetActionDelay,
                        ).then((_) async {
                          try {
                            final removed = await courseProvider.deleteEvent(
                              event.id,
                            );
                            if (removed == null) {
                              return;
                            }
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('已删除日程'),
                                action: SnackBarAction(
                                  label: '撤销',
                                  onPressed: () {
                                    unawaited(() async {
                                      try {
                                        if (!context.mounted) {
                                          return;
                                        }
                                        if (!await ensureCurrentSemesterInitialized(
                                          context,
                                        )) {
                                          return;
                                        }
                                        await courseProvider.restoreEvent(
                                          removed,
                                        );
                                      } catch (error) {
                                        debugPrint(
                                          '[TimetableDetailSheets] Failed to '
                                          'restore event: $error',
                                        );
                                      }
                                    }());
                                  },
                                ),
                              ),
                            );
                          } catch (error) {
                            debugPrint(
                              '[TimetableDetailSheets] Failed to delete event: '
                              '$error',
                            );
                            messenger.showSnackBar(
                              const SnackBar(content: Text('删除日程失败')),
                            );
                          }
                        }),
                      );
                    },
                    child: Text(settingsProvider.t('delete_event')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

Future<bool> _confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  return showAppConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    danger: true,
  );
}

String _formatClockTime(ClockTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _periodRangeLabel(SettingsProvider provider, int start, int end) {
  return provider
      .t('period_range_format')
      .replaceAll('{start}', start.toString())
      .replaceAll('{end}', end.toString());
}
