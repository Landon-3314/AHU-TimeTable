import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../models/course.dart';
import '../../providers/course_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/app_ui.dart';
import 'timetable_detail_sheets.dart';

class _CourseRecordTile extends StatelessWidget {
  const _CourseRecordTile({
    required this.course,
    required this.settingsProvider,
    required this.periodText,
    required this.timeText,
    required this.weekdayText,
    required this.weeksText,
    required this.accentColor,
    required this.onTap,
  });

  final Course course;
  final SettingsProvider settingsProvider;
  final String periodText;
  final String timeText;
  final String weekdayText;
  final String weeksText;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = <_CourseRecordDetail>[
      _CourseRecordDetail(
        label: settingsProvider.t('teacher'),
        value: course.teacher.trim().isEmpty
            ? settingsProvider.t('not_set')
            : course.teacher.trim(),
      ),
      _CourseRecordDetail(
        label: settingsProvider.t('location'),
        value: course.location.trim().isEmpty
            ? settingsProvider.t('not_set')
            : course.location.trim(),
      ),
      _CourseRecordDetail(
        label: settingsProvider.t('periods'),
        value: periodText,
      ),
      _CourseRecordDetail(label: settingsProvider.t('time'), value: timeText),
      _CourseRecordDetail(
        label: settingsProvider.t('weekday'),
        value: weekdayText,
      ),
      _CourseRecordDetail(label: settingsProvider.t('weeks'), value: weeksText),
    ];

    return AppSurface(
      padding: EdgeInsets.zero,
      borderColor: accentColor.withValues(alpha: 0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: accentColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < details.length; index++) ...[
                      DetailRow(
                        label: details[index].label,
                        value: details[index].value,
                      ),
                      if (index != details.length - 1)
                        const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.edit_outlined, color: accentColor, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseRecordDetail {
  const _CourseRecordDetail({required this.label, required this.value});

  final String label;
  final String value;
}

class CourseGroupRecordList extends StatelessWidget {
  const CourseGroupRecordList({
    super.key,
    required this.group,
    required this.settingsProvider,
    required this.periodTextBuilder,
    required this.timeTextBuilder,
    required this.weekdayTextBuilder,
    required this.weeksTextBuilder,
  });

  final CourseGroup group;
  final SettingsProvider settingsProvider;
  final String Function(Course course) periodTextBuilder;
  final String Function(Course course) timeTextBuilder;
  final String Function(Course course) weekdayTextBuilder;
  final String Function(Course course) weeksTextBuilder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildShrinkWrappedRecordList(
            context,
            group.courses,
            bottomPadding: AppSpacing.xxl,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              group.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _RecordCountPill(text: '${group.recordCount}条'),
        ],
      ),
    );
  }

  Widget _buildShrinkWrappedRecordList(
    BuildContext context,
    List<Course> courses, {
    required double bottomPadding,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < courses.length; index++) ...[
            _buildRecordTile(context, courses[index]),
            if (index != courses.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordTile(BuildContext context, Course course) {
    return _CourseRecordTile(
      course: course,
      settingsProvider: settingsProvider,
      periodText: periodTextBuilder(course),
      timeText: timeTextBuilder(course),
      weekdayText: weekdayTextBuilder(course),
      weeksText: weeksTextBuilder(course),
      accentColor: Color(course.colorValue),
      onTap: () => Navigator.of(context).pop(course),
    );
  }
}

class _RecordCountPill extends StatelessWidget {
  const _RecordCountPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.secondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
