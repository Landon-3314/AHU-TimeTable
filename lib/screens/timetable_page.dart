import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../core/app_routes.dart';
import '../core/app_theme_tokens.dart';
import '../models/clock_time.dart';
import '../models/course.dart';
import '../models/timetable_view_data.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/timetable_navigation_controller.dart';
import '../services/timetable_view_data_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/guided_tour_overlay.dart';
import '../widgets/timetable/holiday_list_view.dart';
import '../widgets/timetable/course_overview_panel.dart';
import '../widgets/timetable/timetable_detail_sheets.dart';
import '../widgets/timetable/timetable_grid.dart';
import '../widgets/timetable/week_selector.dart';
import '../widgets/semester_initialization_guard.dart';
import 'academic_account_page.dart';
import 'exam_overview_page.dart';

enum _TimetableToolbarAction { overview, addCourse }

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
                                showImportCourses: true,
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
                tooltip: settingsProvider.t('add_course'),
              ),
            ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _PillTabSwitcher<TimetableMode>(
            key: const ValueKey('timetable-mode-switcher'),
            indicatorKey: const ValueKey('timetable-mode-switcher-indicator'),
            selectedValue: navigationState.mode,
            itemWidth: 88,
            items: [
              _PillTabItem<TimetableMode>(
                value: TimetableMode.day,
                label: Text(settingsProvider.t('day_view')),
              ),
              _PillTabItem<TimetableMode>(
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

    // 检查是否需要在菜单弹出后展示引导
    final needMenuGuide = context
        .read<SettingsProvider>()
        .shouldShowTimetableMenuGuide;

    final action = await navigator.push<_TimetableToolbarAction>(
      _TimetableToolbarMenuRoute(
        anchorRect: topLeft & buttonRenderObject.size,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
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
    _TimetableToolbarAction action,
  ) {
    switch (action) {
      case _TimetableToolbarAction.overview:
        _showCourseOverview(context);
      case _TimetableToolbarAction.addCourse:
        _openAddCourse(context);
    }
  }

  String _buildCoursePeriodText(Course course) {
    return _buildCoursePeriodTextFor(context.read<SettingsProvider>(), course);
  }

  Widget _buildEmptyStateActions(
    BuildContext context,
    SettingsProvider settingsProvider, {
    required bool showImportCourses,
  }) {
    return _EmptyStateActions(
      addCourseLabel: settingsProvider.t('add_course'),
      importCoursesLabel: settingsProvider.t('import_from_system'),
      showImportCourses: showImportCourses,
      onAddCourse: () => _openAddCourse(context),
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
          child: _TimetableOverviewSheet(
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

enum _TimetableOverviewPage { courses, exams }

class _TimetableOverviewSheet extends StatefulWidget {
  const _TimetableOverviewSheet({
    required this.groupCountLabelBuilder,
    required this.onAddCourse,
    required this.onImportCourses,
    required this.onCourseGroupTap,
  });

  final String Function(SettingsProvider settingsProvider, CourseGroup group)
  groupCountLabelBuilder;
  final VoidCallback onAddCourse;
  final VoidCallback onImportCourses;
  final ValueChanged<CourseGroup> onCourseGroupTap;

  @override
  State<_TimetableOverviewSheet> createState() =>
      _TimetableOverviewSheetState();
}

class _TimetableOverviewSheetState extends State<_TimetableOverviewSheet> {
  final PageController _pageController = PageController();
  _TimetableOverviewPage _selectedPage = _TimetableOverviewPage.courses;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(_TimetableOverviewPage page) {
    if (page == _selectedPage) {
      return;
    }
    _pageController.animateToPage(
      page.index,
      duration: AppDurations.switcher,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: _TimetableOverviewTabs(
            selectedPage: _selectedPage,
            onSelected: _selectPage,
          ),
        ),
        Expanded(
          child: PageView(
            key: const ValueKey('overview-pages'),
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedPage = _TimetableOverviewPage.values[index];
              });
            },
            children: [
              CourseOverviewPanel(
                courseGroups: courseProvider.sortedCourseGroups,
                groupCountLabelBuilder: (group) =>
                    widget.groupCountLabelBuilder(settingsProvider, group),
                emptyAction: _EmptyStateActions(
                  addCourseLabel: settingsProvider.t('add_course'),
                  importCoursesLabel: settingsProvider.t('import_from_system'),
                  showImportCourses: true,
                  onAddCourse: widget.onAddCourse,
                  onImportCourses: widget.onImportCourses,
                ),
                onCourseGroupTap: widget.onCourseGroupTap,
              ),
              ExamOverviewPanel(onImport: widget.onImportCourses),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimetableOverviewTabs extends StatelessWidget {
  const _TimetableOverviewTabs({
    required this.selectedPage,
    required this.onSelected,
  });

  final _TimetableOverviewPage selectedPage;
  final ValueChanged<_TimetableOverviewPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return _PillTabSwitcher<_TimetableOverviewPage>(
      key: const ValueKey('overview-tabs'),
      indicatorKey: const ValueKey('overview-tabs-indicator'),
      selectedValue: selectedPage,
      itemWidth: 76,
      items: const [
        _PillTabItem<_TimetableOverviewPage>(
          key: ValueKey('overview-tab-courses'),
          value: _TimetableOverviewPage.courses,
          label: Text('课程'),
        ),
        _PillTabItem<_TimetableOverviewPage>(
          key: ValueKey('overview-tab-exams'),
          value: _TimetableOverviewPage.exams,
          label: Text('考试'),
        ),
      ],
      onSelected: onSelected,
    );
  }
}

class _PillTabSwitcher<T> extends StatelessWidget {
  const _PillTabSwitcher({
    super.key,
    required this.indicatorKey,
    required this.selectedValue,
    required this.itemWidth,
    required this.items,
    required this.onSelected,
  });

  final Key indicatorKey;
  final T selectedValue;
  final double itemWidth;
  final List<_PillTabItem<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final selectedIndex = items.indexWhere(
      (item) => item.value == selectedValue,
    );
    assert(selectedIndex >= 0);
    final indicatorAlignment = items.length == 1
        ? Alignment.center
        : Alignment(-1 + (2 * selectedIndex / (items.length - 1)), 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: tokens.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: SizedBox(
          width: itemWidth * items.length,
          height: 36,
          child: Stack(
            children: [
              AnimatedAlign(
                duration: AppDurations.fast,
                curve: Curves.easeOutCubic,
                alignment: indicatorAlignment,
                child: DecoratedBox(
                  key: indicatorKey,
                  decoration: BoxDecoration(
                    color: tokens.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SizedBox(width: itemWidth, height: 36),
                ),
              ),
              Row(
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      height: 36,
                      child: _PillTab(
                        item: item,
                        selected: item.value == selectedValue,
                        onTap: () => onSelected(item.value),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillTabItem<T> {
  const _PillTabItem({this.key, required this.value, required this.label});

  final Key? key;
  final T value;
  final Widget label;
}

class _PillTab<T> extends StatelessWidget {
  const _PillTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _PillTabItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = appThemeTokensOf(context);
    final label = item.label;
    return Semantics(
      key: item.key,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: selected ? colorScheme.secondary : tokens.textSecondary,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableToolbarMenuRoute extends PopupRoute<_TimetableToolbarAction> {
  _TimetableToolbarMenuRoute({
    required this.anchorRect,
    required String barrierLabel,
    this.overviewGuideKey,
    this.addCourseGuideKey,
    this.onMenuReady,
  }) : _barrierLabel = barrierLabel;

  final Rect anchorRect;
  final String _barrierLabel;
  final GlobalKey? overviewGuideKey;
  final GlobalKey? addCourseGuideKey;
  final VoidCallback? onMenuReady;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => _barrierLabel;

  @override
  Duration get transitionDuration => AppDurations.switcher;

  @override
  Duration get reverseTransitionDuration => AppDurations.switcher;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return CustomSingleChildLayout(
      delegate: _TimetableToolbarMenuLayout(anchorRect: anchorRect),
      child: _TimetableToolbarMenu(
        animation: animation,
        overviewGuideKey: overviewGuideKey,
        addCourseGuideKey: addCourseGuideKey,
        onMenuReady: onMenuReady,
      ),
    );
  }
}

class _TimetableToolbarMenuLayout extends SingleChildLayoutDelegate {
  const _TimetableToolbarMenuLayout({required this.anchorRect});

  static const double _screenPadding = AppSpacing.sm;
  static const double _anchorGap = AppSpacing.xs;

  final Rect anchorRect;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        math.max(0, constraints.maxWidth - _screenPadding * 2),
        math.max(0, constraints.maxHeight - _screenPadding * 2),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math.max(_screenPadding, size.width - childSize.width);
    final left = (anchorRect.right - childSize.width)
        .clamp(_screenPadding, maxLeft)
        .toDouble();
    final maxTop = math.max(_screenPadding, size.height - childSize.height);
    final belowAnchor = anchorRect.bottom + _anchorGap;
    final aboveAnchor = anchorRect.top - _anchorGap - childSize.height;
    final preferredTop = belowAnchor + childSize.height <= size.height
        ? belowAnchor
        : aboveAnchor;
    final top = preferredTop.clamp(_screenPadding, maxTop).toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(covariant _TimetableToolbarMenuLayout oldDelegate) {
    return anchorRect != oldDelegate.anchorRect;
  }
}

class _TimetableToolbarMenu extends StatefulWidget {
  const _TimetableToolbarMenu({
    required this.animation,
    this.overviewGuideKey,
    this.addCourseGuideKey,
    this.onMenuReady,
  });

  static const _contentFadeInCurve = Interval(
    40 / 220,
    160 / 220,
    curve: Curves.easeOutCubic,
  );
  static const _contentFadeOutCurve = Interval(
    60 / 220,
    1,
    curve: Curves.easeInCubic,
  );

  final Animation<double> animation;
  final GlobalKey? overviewGuideKey;
  final GlobalKey? addCourseGuideKey;
  final VoidCallback? onMenuReady;

  @override
  State<_TimetableToolbarMenu> createState() => _TimetableToolbarMenuState();
}

class _TimetableToolbarMenuState extends State<_TimetableToolbarMenu> {
  bool _guideTriggered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: widget.animation,
      child: _TimetableToolbarMenuItems(
        onSelected: (action) => Navigator.of(context).pop(action),
        overviewGuideKey: widget.overviewGuideKey,
        addCourseGuideKey: widget.addCourseGuideKey,
      ),
      builder: (context, child) {
        final isClosing = widget.animation.status == AnimationStatus.reverse;
        final revealProgress =
            (isClosing ? Curves.easeInCubic : Curves.easeOutCubic).transform(
              widget.animation.value,
            );
        final contentProgress =
            (isClosing
                    ? _TimetableToolbarMenu._contentFadeOutCurve
                    : _TimetableToolbarMenu._contentFadeInCurve)
                .transform(widget.animation.value);

        // 菜单展开完成后触发引导回调（仅触发一次）
        if (!_guideTriggered &&
            widget.onMenuReady != null &&
            widget.animation.status == AnimationStatus.completed) {
          _guideTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onMenuReady?.call();
          });
        }
        return Opacity(
          key: const ValueKey('narrow-toolbar-menu-container-opacity'),
          opacity: revealProgress,
          child: DecoratedBox(
            key: const ValueKey('narrow-toolbar-menu-shadow'),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              border: Border.all(color: tokens.divider),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.topRight,
                widthFactor: 0.14 + 0.86 * revealProgress,
                heightFactor: 0.11 + 0.89 * revealProgress,
                child: IntrinsicWidth(
                  child: Material(
                    key: const ValueKey('narrow-toolbar-menu-card'),
                    color: tokens.surfaceRaised,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Opacity(
                        key: const ValueKey(
                          'narrow-toolbar-menu-content-opacity',
                        ),
                        opacity: contentProgress,
                        child: Transform.translate(
                          offset: Offset(0, -4 * (1 - contentProgress)),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimetableToolbarMenuItems extends StatelessWidget {
  const _TimetableToolbarMenuItems({
    required this.onSelected,
    this.overviewGuideKey,
    this.addCourseGuideKey,
  });

  final ValueChanged<_TimetableToolbarAction> onSelected;
  final GlobalKey? overviewGuideKey;
  final GlobalKey? addCourseGuideKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key:
              overviewGuideKey ??
              const ValueKey('narrow-toolbar-menu-action-overview'),
          child: _TimetableToolbarMenuItem(
            icon: Icons.dashboard_outlined,
            label: '总览',
            onTap: () => onSelected(_TimetableToolbarAction.overview),
          ),
        ),
        KeyedSubtree(
          key:
              addCourseGuideKey ??
              const ValueKey('narrow-toolbar-menu-action-add-course'),
          child: _TimetableToolbarMenuItem(
            icon: Icons.add,
            label: '添加课程/日程',
            onTap: () => onSelected(_TimetableToolbarAction.addCourse),
          ),
        ),
      ],
    );
  }
}

class _TimetableToolbarMenuItem extends StatelessWidget {
  const _TimetableToolbarMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(icon, color: colorScheme.secondary, size: 18),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateActions extends StatelessWidget {
  const _EmptyStateActions({
    required this.addCourseLabel,
    required this.importCoursesLabel,
    required this.showImportCourses,
    required this.onAddCourse,
    required this.onImportCourses,
  });

  final String addCourseLabel;
  final String importCoursesLabel;
  final bool showImportCourses;
  final VoidCallback onAddCourse;
  final VoidCallback onImportCourses;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: onAddCourse,
          icon: const Icon(Icons.add),
          label: Text(addCourseLabel),
        ),
        if (showImportCourses)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: onImportCourses,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(importCoursesLabel),
          ),
      ],
    );
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
