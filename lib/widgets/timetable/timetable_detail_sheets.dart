import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../models/clock_time.dart';
import '../../models/course.dart';
import '../../models/event.dart';
import '../../providers/course_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/timetable_view_data_service.dart';

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
      final actionButtons = <Widget>[
        if (sourceWeek != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surfaceMuted,
                foregroundColor: AppColors.primary,
              ),
              onPressed: () async {
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
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () async {
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
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () {
              Navigator.of(sheetContext).pop();
              unawaited(
                Future<void>.delayed(
                  AppDurations.sheetActionDelay,
                ).then((_) => courseProvider.removeCourse(course)),
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
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: AppSpacing.floatingSheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name,
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                    foregroundColor: AppColors.onPrimary,
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      Future<void>.delayed(
                        AppDurations.sheetActionDelay,
                      ).then((_) => courseProvider.deleteEvent(event.id)),
                    );
                  },
                  child: Text(settingsProvider.t('delete_event')),
                ),
              ),
            ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
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
