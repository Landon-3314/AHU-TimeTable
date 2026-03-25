import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/course.dart';
import '../../models/event.dart';
import '../../models/timetable_view_data.dart';
import 'course_card.dart';
import 'event_card.dart';

class DayAgendaView extends StatelessWidget {
  const DayAgendaView({
    super.key,
    required this.pageData,
    required this.onCourseTap,
    required this.onEventTap,
    required this.coursePeriodTextBuilder,
    required this.eventMarkerLabel,
    required this.locationPendingLabel,
  });

  final TimetableDayPageData pageData;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Event> onEventTap;
  final String Function(Course course) coursePeriodTextBuilder;
  final String eventMarkerLabel;
  final String locationPendingLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: pageData.isEmpty
              ? EmptyScheduleState(
                  title: pageData.emptyTitle,
                  subtitle: pageData.emptySubtitle,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  itemCount: pageData.items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ScheduleHeaderCard(
                          title: pageData.headerTitle,
                          subtitle: pageData.headerSubtitle,
                        ),
                      );
                    }

                    final item = pageData.items[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: item.isCourse
                          ? CourseCard(
                              course: item.course!,
                              periodText: coursePeriodTextBuilder(item.course!),
                              accentColor: Color(item.course!.colorValue),
                              onTap: () => onCourseTap(item.course!),
                            )
                          : EventCard(
                              event: item.event!,
                              markerLabel: eventMarkerLabel,
                              locationPendingLabel: locationPendingLabel,
                              onTap: () => onEventTap(item.event!),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class DayWeekHeader extends StatelessWidget {
  const DayWeekHeader({
    super.key,
    required this.summaryLabel,
    required this.chips,
    required this.selectedWeekday,
    required this.onDaySelected,
  });

  final String summaryLabel;
  final List<TimetableDayChipData> chips;
  final int selectedWeekday;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            AppSpacing.sm,
          ),
          child: Text(
            summaryLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: AppSpacing.chipHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                for (final chip in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(chip.label),
                          Text(
                            chip.dateLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      selected: selectedWeekday == chip.weekday,
                      onSelected: (_) => onDaySelected(chip.weekday),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({
    super.key,
    required this.pageData,
    required this.onCourseTap,
    required this.onEventTap,
    required this.coursePeriodTextBuilder,
  });

  final TimetableWeekPageData pageData;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Event> onEventTap;
  final String Function(Course course) coursePeriodTextBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.listPagePadding,
      children: [
        Text(
          pageData.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          pageData.subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final section in pageData.sections) ...[
          _WeekdaySection(
            section: section,
            onCourseTap: onCourseTap,
            onEventTap: onEventTap,
            coursePeriodTextBuilder: coursePeriodTextBuilder,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({
    required this.section,
    required this.onCourseTap,
    required this.onEventTap,
    required this.coursePeriodTextBuilder,
  });

  final TimetableWeekSectionData section;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Event> onEventTap;
  final String Function(Course course) coursePeriodTextBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (section.isEmpty)
            Text(
              section.emptyText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          for (final item in section.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: item.isCourse
                  ? CourseCard(
                      course: item.course!,
                      periodText: coursePeriodTextBuilder(item.course!),
                      accentColor: Color(item.course!.colorValue),
                      onTap: () => onCourseTap(item.course!),
                    )
                  : CompactEventCard(
                      event: item.event!,
                      onTap: () => onEventTap(item.event!),
                    ),
            ),
        ],
      ),
    );
  }
}

class ScheduleHeaderCard extends StatelessWidget {
  const ScheduleHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class EmptyScheduleState extends StatelessWidget {
  const EmptyScheduleState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.surface),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
