import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../core/app_routes.dart';
import '../models/clock_time.dart';
import '../models/course.dart';
import '../models/timetable_view_data.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/timetable_navigation_controller.dart';
import '../services/timetable_view_data_service.dart';
import '../widgets/semester_start_date_dialog.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/guided_tour_overlay.dart';
import '../widgets/timetable/holiday_list_view.dart';
import '../widgets/timetable/course_overview_panel.dart';
import '../widgets/timetable/timetable_detail_sheets.dart';
import '../widgets/timetable/timetable_grid.dart';
import '../widgets/timetable/week_selector.dart';
import 'import_course_page.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  static const TimetableViewDataService _viewDataService =
      TimetableViewDataService();

  late final SettingsProvider _settingsProvider;
  late final TimetableNavigationController _navigationController;
  late DateTime _lastSemesterStartDate;
  late int _lastTotalWeeks;
  final GlobalKey _weekSelectorGuideKey = GlobalKey();
  final GlobalKey _todayGuideKey = GlobalKey();
  final GlobalKey _overviewGuideKey = GlobalKey();
  final GlobalKey _importGuideKey = GlobalKey();
  final GlobalKey _addCourseGuideKey = GlobalKey();
  bool _isToolbarGuideShowing = false;

  @override
  void initState() {
    super.initState();
    _settingsProvider = context.read<SettingsProvider>();
    _lastSemesterStartDate = _settingsProvider.semesterStartDate;
    _lastTotalWeeks = _settingsProvider.totalWeeks;
    _settingsProvider.addListener(_handleSettingsChanged);
    _navigationController = TimetableNavigationController(
      settingsProvider: _settingsProvider,
      timetableViewProvider: context.read(),
      holidayWeekIndex: AppConstants.holidayWeekIndex,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _navigationController.syncInitialPosition();
      _showTimetableToolbarGuideIfNeeded();
    });
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_handleSettingsChanged);
    _navigationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final screenData = _viewDataService.build(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      totalWeeks: settingsProvider.totalWeeks,
      languageCode: settingsProvider.languageCode,
      translate: settingsProvider.t,
      getDateFor: settingsProvider.getDateFor,
      timeSlots: settingsProvider.timeSlots,
      holidayWeekIndex: AppConstants.holidayWeekIndex,
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return AnimatedBuilder(
      animation: _navigationController,
      builder: (context, _) {
        final navigationState = _navigationController.state;
        final currentDayPage =
            screenData.dayPages[navigationState.currentDayPageIndex];
        final currentWeekChips =
            screenData.dayChipsByWeek[currentDayPage.week] ??
            const <TimetableDayChipData>[];
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WeekSelector(
                  key: _weekSelectorGuideKey,
                  currentWeek: navigationState.currentDisplayWeek,
                  options: screenData.weekOptions,
                  tooltip: settingsProvider.t('jump_to_week'),
                  onSelected: _navigationController.jumpToWeek,
                ),
                IconButton(
                  key: _todayGuideKey,
                  onPressed: _navigationController.jumpToToday,
                  icon: const Icon(Icons.today),
                  tooltip: settingsProvider.t('today'),
                ),
                TextButton(
                  key: _overviewGuideKey,
                  onPressed: () => _showCourseOverview(context),
                  child: Text(
                    '总览',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                key: _importGuideKey,
                onPressed: () async {
                  final canImport =
                      await _ensureSemesterInitializedBeforeImport(context);
                  if (!canImport || !mounted) {
                    return;
                  }

                  final importResult = await navigator
                      .pushNamed<AcademicImportResult>(AppRoutes.importCourses);

                  if (!mounted || importResult == null) {
                    return;
                  }

                  final summaryMessage = _buildImportSummaryMessage(
                    settingsProvider,
                    importResult,
                  );
                  messenger
                    ..removeCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(summaryMessage)));
                },
                icon: const Icon(Icons.cloud_download_outlined),
                tooltip: settingsProvider.t('import_from_system'),
              ),
              IconButton(
                key: _addCourseGuideKey,
                onPressed: () async {
                  await navigator.pushNamed(AppRoutes.addCourse);
                },
                icon: const Icon(Icons.add),
                tooltip: settingsProvider.t('add_course'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SegmentedButton<TimetableMode>(
                  selectedIcon: const SizedBox.shrink(),
                  segments: [
                    ButtonSegment<TimetableMode>(
                      value: TimetableMode.day,
                      label: Text(settingsProvider.t('day_view')),
                      icon: const Icon(Icons.view_day_outlined),
                    ),
                    ButtonSegment<TimetableMode>(
                      value: TimetableMode.week,
                      label: Text(settingsProvider.t('week_view')),
                      icon: const Icon(Icons.calendar_view_week_outlined),
                    ),
                  ],
                  selected: {navigationState.mode},
                  onSelectionChanged: (selection) {
                    _navigationController.setMode(selection.first);
                  },
                ),
              ),
            ),
          ),
          body: AnimatedSwitcher(
            duration: AppDurations.switcher,
            child: navigationState.mode == TimetableMode.day
                ? Column(
                    key: const ValueKey('day-view'),
                    children: [
                      DayWeekHeader(
                        summaryLabel: currentDayPage.summaryLabel,
                        chips: currentWeekChips,
                        selectedWeekday: navigationState.currentWeekday,
                        onDaySelected: (weekday) {
                          _navigationController.jumpToDay(
                            week: navigationState.currentWeek,
                            weekday: weekday,
                          );
                        },
                      ),
                      Expanded(
                        child: PageView.builder(
                          controller: _navigationController.dayPageController,
                          itemCount: screenData.dayPages.length,
                          onPageChanged:
                              _navigationController.handleDayPageChanged,
                          itemBuilder: (context, index) {
                            final pageData = screenData.dayPages[index];
                            return DayAgendaView(
                              pageData: pageData,
                              onCourseTap: (course) {
                                showCourseDetailsSheet(
                                  context,
                                  course,
                                  sourceWeek: pageData.week,
                                );
                              },
                              onEventTap: (event) {
                                showEventDetailsSheet(context, event);
                              },
                              coursePeriodTextBuilder: _buildCoursePeriodText,
                              eventMarkerLabel: settingsProvider.t(
                                'event_marker',
                              ),
                              locationPendingLabel: settingsProvider.t(
                                'location_pending',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : PageView.builder(
                    key: const ValueKey('week-view'),
                    controller: _navigationController.weekPageController,
                    itemCount: screenData.weekPages.length + 1,
                    onPageChanged: _navigationController.handleWeekPageChanged,
                    itemBuilder: (context, index) {
                      if (index == screenData.weekPages.length) {
                        return HolidayListView(
                          pageData: screenData.holidayPage,
                          onEventTap: (event) {
                            showEventDetailsSheet(context, event);
                          },
                        );
                      }

                      final pageData = screenData.weekPages[index];
                      return TimetableGrid(
                        pageData: pageData,
                        onCourseTap: (course) {
                          showCourseDetailsSheet(
                            context,
                            course,
                            sourceWeek: pageData.week,
                          );
                        },
                        onEventTap: (event) {
                          showEventDetailsSheet(context, event);
                        },
                        coursePeriodTextBuilder: _buildCoursePeriodText,
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  String _buildCoursePeriodText(Course course) {
    return _buildCoursePeriodTextFor(context.read<SettingsProvider>(), course);
  }

  String _buildCoursePeriodTextFor(
    SettingsProvider settingsProvider,
    Course course,
  ) {
    return settingsProvider
        .t('period_range_format')
        .replaceAll('{start}', course.startPeriod.toString())
        .replaceAll('{end}', course.endPeriod.toString());
  }

  String _buildImportSummaryMessage(
    SettingsProvider settingsProvider,
    AcademicImportResult result,
  ) {
    if (result.kind == AcademicImportKind.exam) {
      return settingsProvider.languageCode == 'en'
          ? 'Successfully imported ${result.importedCount} exams'
          : '成功导入 ${result.importedCount} 场考试';
    }

    return settingsProvider.languageCode == 'en'
        ? 'Successfully imported ${result.importedCount} courses'
        : '总共添加了 ${result.importedCount} 门课';
  }

  Future<void> _showCourseOverview(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
          child: Consumer<CourseProvider>(
            builder: (context, courseProvider, _) {
              final courseGroups = courseProvider.sortedCourseGroups;
              final settingsProvider = context.watch<SettingsProvider>();
              return CourseOverviewPanel(
                courseGroups: courseGroups,
                groupCountLabelBuilder: (group) =>
                    _buildCourseGroupCountLabel(settingsProvider, group),
                onCourseGroupTap: (group) async {
                  final selectedCourse = await _showCourseGroupRecords(
                    context,
                    group,
                  );
                  if (selectedCourse == null || !context.mounted) {
                    return;
                  }
                  await Navigator.of(context).pushNamed(
                    AppRoutes.addCourse,
                    arguments: AddCourseRouteArgs(
                      existingCourse: selectedCourse,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _buildCourseGroupCountLabel(
    SettingsProvider settingsProvider,
    CourseGroup group,
  ) {
    if (settingsProvider.languageCode == 'en') {
      return group.recordCount == 1 ? '1 slot' : '${group.recordCount} slots';
    }
    return '${group.recordCount}个时段';
  }

  Future<Course?> _showCourseGroupRecords(
    BuildContext context,
    CourseGroup group,
  ) {
    final settingsProvider = context.read<SettingsProvider>();
    return showModalBottomSheet<Course>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: _CourseGroupRecordList(
              group: group,
              settingsProvider: settingsProvider,
              periodTextBuilder: (course) =>
                  _buildCoursePeriodTextFor(settingsProvider, course),
              timeTextBuilder: (course) =>
                  _buildCourseTimeText(settingsProvider, course),
              weekdayTextBuilder: (course) =>
                  _buildWeekdayText(settingsProvider, course.weekday),
              weeksTextBuilder: (course) =>
                  _buildCourseWeeksDetailText(settingsProvider, course),
            ),
          ),
        );
      },
    );
  }

  String _buildCourseTimeText(
    SettingsProvider settingsProvider,
    Course course,
  ) {
    final timeSlots = settingsProvider.timeSlots;
    final startSlot =
        course.startPeriod > 0 && course.startPeriod <= timeSlots.length
        ? timeSlots[course.startPeriod - 1]
        : null;
    final endSlot = course.endPeriod > 0 && course.endPeriod <= timeSlots.length
        ? timeSlots[course.endPeriod - 1]
        : null;
    final periodText = _buildCoursePeriodTextFor(settingsProvider, course);
    if (startSlot == null || endSlot == null) {
      return periodText;
    }

    return '${settingsProvider.t('time')}: '
        '${_formatClockTime(startSlot.startTime)} - '
        '${_formatClockTime(endSlot.endTime)} '
        '($periodText)';
  }

  String _buildWeekdayText(SettingsProvider settingsProvider, int weekday) {
    final index = weekday - 1;
    if (index < 0 || index >= TimetableViewDataService.weekdayKeys.length) {
      return settingsProvider.t('not_set');
    }
    return settingsProvider.t(TimetableViewDataService.weekdayKeys[index]);
  }

  String _buildCourseWeeksDetailText(
    SettingsProvider settingsProvider,
    Course course,
  ) {
    if (course.weeks.isEmpty) {
      return settingsProvider.t('not_set');
    }
    return course.weeks.join(', ');
  }

  String _formatClockTime(ClockTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<bool> _ensureSemesterInitializedBeforeImport(
    BuildContext context,
  ) async {
    final settingsProvider = context.read<SettingsProvider>();
    final courseProvider = context.read<CourseProvider>();
    if (settingsProvider.isCurrentSemesterInitialized) {
      return true;
    }

    final shouldInitialize = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('当前学期尚未初始化'),
          content: const Text('当前学期尚未初始化，请先完成学期开始日期设置后再导入课程。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去初始化'),
            ),
          ],
        );
      },
    );
    if (shouldInitialize != true || !context.mounted) {
      return false;
    }

    final selectedDate = await showSemesterStartDateDialog(
      context: context,
      initialDate: settingsProvider.semesterStartDate,
      canCancel: settingsProvider.semesters.length > 1,
    );
    if (selectedDate == null || !context.mounted) {
      return false;
    }

    if (settingsProvider.currentSemesterId == null) {
      await settingsProvider.createSemesterWithInitialData(
        startDate: selectedDate,
      );
    } else {
      await settingsProvider.completeInitialSemesterStartDate(selectedDate);
    }

    await courseProvider.reloadForCurrentSemester(refreshReminders: false);
    await AppServices.refreshSchedules(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      settings: settingsProvider,
    );
    return settingsProvider.isCurrentSemesterInitialized;
  }

  Future<void> _showTimetableToolbarGuideIfNeeded() async {
    if (_isToolbarGuideShowing || !mounted) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.shouldShowTimetableToolbarGuide ||
        settingsProvider.shouldShowSemesterStartDatePrompt) {
      return;
    }

    _isToolbarGuideShowing = true;
    await showGuidedTourOverlay(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _weekSelectorGuideKey,
          title: settingsProvider.t('guide_timetable_week_title'),
          body: settingsProvider.t('guide_timetable_week_body'),
        ),
        GuidedTourStep(
          targetKey: _todayGuideKey,
          title: settingsProvider.t('guide_timetable_today_title'),
          body: settingsProvider.t('guide_timetable_today_body'),
        ),
        GuidedTourStep(
          targetKey: _overviewGuideKey,
          title: settingsProvider.t('guide_timetable_overview_title'),
          body: settingsProvider.t('guide_timetable_overview_body'),
        ),
        GuidedTourStep(
          targetKey: _importGuideKey,
          title: settingsProvider.t('guide_timetable_import_title'),
          body: settingsProvider.t('guide_timetable_import_body'),
        ),
        GuidedTourStep(
          targetKey: _addCourseGuideKey,
          title: settingsProvider.t('guide_timetable_add_title'),
          body: settingsProvider.t('guide_timetable_add_body'),
        ),
      ],
      nextLabel: settingsProvider.t('guide_next'),
      doneLabel: settingsProvider.t('guide_done'),
      stepLabelBuilder: (currentStep, totalSteps) {
        return settingsProvider
            .t('guide_step_counter')
            .replaceAll('{current}', currentStep.toString())
            .replaceAll('{total}', totalSteps.toString());
      },
    );

    if (!mounted) {
      return;
    }

    await context.read<SettingsProvider>().confirmTimetableToolbarGuide();
    _isToolbarGuideShowing = false;
  }

  void _handleSettingsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showTimetableToolbarGuideIfNeeded();
    });

    final nextSemesterStartDate = _settingsProvider.semesterStartDate;
    final nextTotalWeeks = _settingsProvider.totalWeeks;
    final semesterChanged = !_isSameDate(
      _lastSemesterStartDate,
      nextSemesterStartDate,
    );
    final totalWeeksChanged = _lastTotalWeeks != nextTotalWeeks;
    if (!semesterChanged && !totalWeeksChanged) {
      return;
    }

    _lastSemesterStartDate = nextSemesterStartDate;
    _lastTotalWeeks = nextTotalWeeks;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _navigationController.jumpToToday();
    });
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

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

class _CourseGroupRecordList extends StatelessWidget {
  const _CourseGroupRecordList({
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
          _RecordCountPill(
            text: settingsProvider.languageCode == 'en'
                ? '${group.recordCount} records'
                : '${group.recordCount}条',
          ),
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
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
