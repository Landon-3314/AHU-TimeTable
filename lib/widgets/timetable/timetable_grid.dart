import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/course.dart';
import '../../models/event.dart';
import '../../models/timetable_view_data.dart';
import '../long_screenshot_scroll_capture.dart';
import 'course_card.dart';
import 'event_card.dart';

class DayAgendaView extends StatefulWidget {
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
  State<DayAgendaView> createState() => _DayAgendaViewState();
}

class _DayAgendaViewState extends State<DayAgendaView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: widget.pageData.isEmpty
              ? EmptyScheduleState(
                  title: widget.pageData.emptyTitle,
                  subtitle: widget.pageData.emptySubtitle,
                )
              : LongScreenshotScrollCapture(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.sm,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    itemCount: widget.pageData.items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ScheduleHeaderCard(
                            title: widget.pageData.headerTitle,
                            subtitle: widget.pageData.headerSubtitle,
                          ),
                        );
                      }

                      final item = widget.pageData.items[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: item.isCourse
                            ? CourseCard(
                                course: item.course!,
                                periodText: widget.coursePeriodTextBuilder(
                                  item.course!,
                                ),
                                accentColor: Color(item.course!.colorValue),
                                onTap: () => widget.onCourseTap(item.course!),
                              )
                            : EventCard(
                                event: item.event!,
                                markerLabel: widget.eventMarkerLabel,
                                locationPendingLabel:
                                    widget.locationPendingLabel,
                                onTap: () => widget.onEventTap(item.event!),
                              ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class DayWeekHeader extends StatefulWidget {
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
  State<DayWeekHeader> createState() => _DayWeekHeaderState();
}

class _DayWeekHeaderState extends State<DayWeekHeader> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewKey = GlobalKey();
  final Map<int, GlobalKey> _chipKeys = <int, GlobalKey>{};
  bool _visibilityCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _syncChipKeys();
    _scheduleSelectedChipVisibility();
  }

  @override
  void didUpdateWidget(DayWeekHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncChipKeys();
    if (oldWidget.selectedWeekday != widget.selectedWeekday ||
        !_hasSameChipWeekdays(oldWidget.chips, widget.chips)) {
      _scheduleSelectedChipVisibility();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncChipKeys() {
    final weekdays = widget.chips.map((chip) => chip.weekday).toSet();
    _chipKeys.removeWhere((weekday, _) => !weekdays.contains(weekday));
    for (final weekday in weekdays) {
      _chipKeys.putIfAbsent(weekday, GlobalKey.new);
    }
  }

  bool _hasSameChipWeekdays(
    List<TimetableDayChipData> previous,
    List<TimetableDayChipData> next,
  ) {
    if (previous.length != next.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index += 1) {
      if (previous[index].weekday != next[index].weekday) {
        return false;
      }
    }
    return true;
  }

  void _scheduleSelectedChipVisibility() {
    if (_visibilityCheckScheduled) {
      return;
    }
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted) {
        return;
      }
      _ensureSelectedChipVisible();
    });
  }

  void _ensureSelectedChipVisible() {
    if (!_scrollController.hasClients) {
      return;
    }

    final viewportObject = _scrollViewKey.currentContext?.findRenderObject();
    final chipObject = _chipKeys[widget.selectedWeekday]?.currentContext
        ?.findRenderObject();
    if (viewportObject is! RenderBox || chipObject is! RenderBox) {
      return;
    }

    final chipOffset = chipObject.localToGlobal(
      Offset.zero,
      ancestor: viewportObject,
    );
    final chipLeft = chipOffset.dx;
    final chipRight = chipLeft + chipObject.size.width;
    final viewportWidth = viewportObject.size.width;

    final currentOffset = _scrollController.offset;
    double targetOffset = currentOffset;
    if (chipLeft < 0) {
      targetOffset = currentOffset + chipLeft;
    } else if (chipRight > viewportWidth) {
      targetOffset = currentOffset + (chipRight - viewportWidth);
    } else {
      return;
    }

    final position = _scrollController.position;
    targetOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((targetOffset - currentOffset).abs() < 0.5) {
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: AppDurations.pageSync,
      curve: Curves.easeOutCubic,
    );
  }

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
            widget.summaryLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: AppSpacing.chipHeight,
          child: SingleChildScrollView(
            key: _scrollViewKey,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              children: [
                for (final chip in widget.chips)
                  Padding(
                    key: _chipKeys[chip.weekday],
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
                      selected: widget.selectedWeekday == chip.weekday,
                      onSelected: (_) => widget.onDaySelected(chip.weekday),
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

class TimetableGrid extends StatefulWidget {
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
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LongScreenshotScrollCapture(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: AppSpacing.listPagePadding,
        children: [
          Text(
            widget.pageData.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.pageData.subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final section in widget.pageData.sections) ...[
            _WeekdaySection(
              section: section,
              onCourseTap: widget.onCourseTap,
              onEventTap: widget.onEventTap,
              coursePeriodTextBuilder: widget.coursePeriodTextBuilder,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
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
