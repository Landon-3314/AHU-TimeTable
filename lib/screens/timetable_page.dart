import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../core/app_routes.dart';
import '../models/clock_time.dart';
import '../models/course.dart';
import '../models/timetable_view_data.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/timetable_navigation_controller.dart';
import '../services/timetable_view_data_service.dart';
import '../widgets/common/guided_tour_overlay.dart';
import '../widgets/timetable/holiday_list_view.dart';
import '../widgets/timetable/timetable_detail_sheets.dart';
import '../widgets/timetable/timetable_grid.dart';
import '../widgets/timetable/week_selector.dart';
import '../widgets/timetable/course_group_record_list.dart';
import '../widgets/timetable/pill_tab_switcher.dart';
import '../widgets/timetable/timetable_empty_state_actions.dart';
import '../widgets/timetable/timetable_overview_sheet.dart';
import '../widgets/timetable/timetable_toolbar_menu.dart';
import '../widgets/semester_initialization_guard.dart';
import 'academic_account_page.dart';

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
  final GlobalKey _addCourseGuideKey = GlobalKey();
  // 折叠菜单内引导使用的 GlobalKey
  final GlobalKey _menuOverviewGuideKey = GlobalKey();
  final GlobalKey _menuAddCourseGuideKey = GlobalKey();
  bool _isToolbarGuideShowing = false;
  bool _isMenuGuideShowing = false;
  bool _isNarrowMode = false;

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
      translate: settingsProvider.t,
      getDateFor: settingsProvider.getDateFor,
      timeSlots: settingsProvider.timeSlots,
      holidayWeekIndex: AppConstants.holidayWeekIndex,
    );
    final showEmptyImportAction = !courseProvider.hasImportedTimetableCourses;
    return AnimatedBuilder(
      animation: _navigationController,
      builder: (context, _) {
        final navigationState = _navigationController.state;
        final currentDayPage =
            screenData.dayPages[navigationState.currentDayPageIndex];
        final currentWeekChips =
            screenData.dayChipsByWeek[currentDayPage.week] ??
            const <TimetableDayChipData>[];
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            if (_isNarrowMode != isNarrow) {
              _isNarrowMode = isNarrow;
            }
            return Scaffold(
              appBar: _buildAppBar(
                context,
                settingsProvider: settingsProvider,
                navigationState: navigationState,
                screenData: screenData,
                isNarrow: isNarrow,
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
                              controller:
                                  _navigationController.dayPageController,
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
                                  coursePeriodTextBuilder:
                                      _buildCoursePeriodText,
                                  eventMarkerLabel: settingsProvider.t(
                                    'event_marker',
                                  ),
                                  locationPendingLabel: settingsProvider.t(
                                    'location_pending',
                                  ),
                                  emptyAction: _buildEmptyStateActions(
                                    context,
                                    settingsProvider,
                                    showImportCourses: showEmptyImportAction,
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
                        onPageChanged:
                            _navigationController.handleWeekPageChanged,
                        itemBuilder: (context, index) {
                          if (index == screenData.weekPages.length) {
                            return HolidayListView(
                              pageData: screenData.holidayPage,
                              onEventTap: (event) {
                                showEventDetailsSheet(context, event);
                              },
                              emptyAction: _buildEmptyStateActions(
                                context,
                                settingsProvider,
                                addCourseLabel: settingsProvider.t(
                                  'add_schedule',
                                ),
                                showImportCourses: false,
                                onAddCourse: () => _openAddEvent(context),
                              ),
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
                            emptyAction: _buildEmptyStateActions(
                              context,
                              settingsProvider,
                              showImportCourses: true,
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required SettingsProvider settingsProvider,
    required TimetableNavigationState navigationState,
    required TimetableScreenData screenData,
    required bool isNarrow,
  }) {
    return AppBar(
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
          if (!isNarrow)
            TextButton(
              key: _overviewGuideKey,
              onPressed: () => _showCourseOverview(context),
              child: Text(
                '总览',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      actions: isNarrow
          ? [_buildNarrowToolbarMenu(context)]
          : [
              IconButton(
                key: _addCourseGuideKey,
                onPressed: () => _openAddCourse(context),
                icon: const Icon(Icons.add),
                tooltip: settingsProvider.t('add_course_or_event'),
              ),
            ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: PillTabSwitcher<TimetableMode>(
            key: const ValueKey('timetable-mode-switcher'),
            indicatorKey: const ValueKey('timetable-mode-switcher-indicator'),
            selectedValue: navigationState.mode,
            itemWidth: 88,
            items: [
              PillTabItem<TimetableMode>(
                value: TimetableMode.day,
                label: Text(settingsProvider.t('day_view')),
              ),
              PillTabItem<TimetableMode>(
                value: TimetableMode.week,
                label: Text(settingsProvider.t('week_view')),
              ),
            ],
            onSelected: _navigationController.setMode,
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowToolbarMenu(BuildContext context) {
    return Builder(
      builder: (buttonContext) {
        return IconButton(
          key: const ValueKey('narrow-toolbar-menu-button'),
          tooltip: '更多操作',
          onPressed: () => _openNarrowToolbarMenu(buttonContext),
          icon: const Icon(Icons.more_vert),
        );
      },
    );
  }

  Future<void> _openNarrowToolbarMenu(BuildContext buttonContext) async {
    final navigator = Navigator.of(context);
    final buttonRenderObject = buttonContext.findRenderObject();
    final overlayRenderObject = navigator.overlay?.context.findRenderObject();
    if (buttonRenderObject is! RenderBox ||
        overlayRenderObject is! RenderBox ||
        !buttonRenderObject.hasSize ||
        !overlayRenderObject.hasSize) {
      return;
    }

    final topLeft = buttonRenderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayRenderObject,
    );

    final settingsProvider = context.read<SettingsProvider>();
    // 检查是否需要在菜单弹出后展示引导
    final needMenuGuide = settingsProvider.shouldShowTimetableMenuGuide;
    final action = await navigator.push<TimetableToolbarAction>(
      TimetableToolbarMenuRoute(
        anchorRect: topLeft & buttonRenderObject.size,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        addCourseLabel: settingsProvider.t('add_course_or_event'),
        // 需要引导时传入 GlobalKey，让菜单项绑定 key
        overviewGuideKey: needMenuGuide ? _menuOverviewGuideKey : null,
        addCourseGuideKey: needMenuGuide ? _menuAddCourseGuideKey : null,
        onMenuReady: needMenuGuide ? _showMenuGuideIfNeeded : null,
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    _handleToolbarAction(context, action);
  }

  void _handleToolbarAction(
    BuildContext context,
    TimetableToolbarAction action,
  ) {
    switch (action) {
      case TimetableToolbarAction.overview:
        _showCourseOverview(context);
      case TimetableToolbarAction.addCourse:
        _openAddCourse(context);
    }
  }

  String _buildCoursePeriodText(Course course) {
    return _buildCoursePeriodTextFor(context.read<SettingsProvider>(), course);
  }

  Widget _buildEmptyStateActions(
    BuildContext context,
    SettingsProvider settingsProvider, {
    String? addCourseLabel,
    required bool showImportCourses,
    VoidCallback? onAddCourse,
  }) {
    return TimetableEmptyStateActions(
      addCourseLabel:
          addCourseLabel ?? settingsProvider.t('add_course_or_event'),
      importCoursesLabel: settingsProvider.t('import_from_system'),
      showImportCourses: showImportCourses,
      onAddCourse: onAddCourse ?? () => _openAddCourse(context),
      onImportCourses: () => _openAcademicAccount(context),
    );
  }

  Future<void> _openAddCourse(BuildContext context) async {
    if (!await ensureCurrentSemesterInitialized(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(AppRoutes.addCourse);
  }

  Future<void> _openAddEvent(BuildContext context) async {
    if (!await ensureCurrentSemesterInitialized(context)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).pushNamed(
      AppRoutes.addCourse,
      arguments: const AddCourseRouteArgs.addEvent(),
    );
  }

  Future<void> _openAcademicAccount(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const AcademicAccountPage()),
    );
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

  Future<void> _showCourseOverview(BuildContext context) async {
    final pageContext = context;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.8,
          child: TimetableOverviewSheet(
            groupCountLabelBuilder: _buildCourseGroupCountLabel,
            onAddCourse: () async {
              Navigator.of(sheetContext).pop();
              await _openAddCourse(pageContext);
            },
            onImportCourses: () async {
              Navigator.of(sheetContext).pop();
              await _openAcademicAccount(pageContext);
            },
            onCourseGroupTap: (group) async {
              if (!await ensureCurrentSemesterInitialized(pageContext)) {
                return;
              }
              if (!pageContext.mounted) {
                return;
              }
              final selectedCourse = await _showCourseGroupRecords(
                sheetContext,
                group,
              );
              if (selectedCourse == null || !sheetContext.mounted) {
                return;
              }
              await Navigator.of(sheetContext).pushNamed(
                AppRoutes.addCourse,
                arguments: AddCourseRouteArgs(existingCourse: selectedCourse),
              );
            },
          ),
        );
      },
    );
  }

  String _buildCourseGroupCountLabel(SettingsProvider _, CourseGroup group) {
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
            child: CourseGroupRecordList(
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

  Future<void> _showTimetableToolbarGuideIfNeeded() async {
    if (_isToolbarGuideShowing || !mounted) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.shouldShowTimetableToolbarGuide) {
      return;
    }

    _isToolbarGuideShowing = true;

    // 窄屏模式：只展示可见按钮的引导（周次选择器 + 今日按钮）
    // 宽屏模式：展示可见工具栏按钮引导
    final steps = _isNarrowMode
        ? [
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
          ]
        : [
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
              targetKey: _addCourseGuideKey,
              title: settingsProvider.t('guide_timetable_add_title'),
              body: settingsProvider.t('guide_timetable_add_body'),
            ),
          ];

    await showGuidedTourOverlay(
      context: context,
      steps: steps,
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
    // 宽屏模式已展示全部4步引导，菜单引导也视为已完成
    if (!_isNarrowMode) {
      if (!mounted) return;
      await context.read<SettingsProvider>().confirmTimetableMenuGuide();
    }
    _isToolbarGuideShowing = false;
  }

  /// 折叠菜单打开后，检查是否需要展示菜单内引导。
  /// 引导会叠加在菜单路由之上，高亮菜单中的各项。
  Future<void> _showMenuGuideIfNeeded() async {
    if (_isMenuGuideShowing || !mounted) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.shouldShowTimetableMenuGuide) {
      return;
    }

    _isMenuGuideShowing = true;

    // 等待一帧让菜单项完成布局，确保 GlobalKey 能找到 RenderBox
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) {
      return;
    }

    await showGuidedTourOverlay(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _menuOverviewGuideKey,
          title: settingsProvider.t('guide_timetable_overview_title'),
          body: settingsProvider.t('guide_timetable_overview_body'),
        ),
        GuidedTourStep(
          targetKey: _menuAddCourseGuideKey,
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

    await context.read<SettingsProvider>().confirmTimetableMenuGuide();
    _isMenuGuideShowing = false;
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
