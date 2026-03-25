import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/timetable_view_data.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/timetable_view_provider.dart';
import '../services/timetable_navigation_controller.dart';
import '../services/timetable_view_data_service.dart';
import '../widgets/timetable/holiday_list_view.dart';
import '../widgets/timetable/timetable_detail_sheets.dart';
import '../widgets/timetable/timetable_grid.dart';
import '../widgets/timetable/week_selector.dart';
import 'add_course_page.dart';
import 'import_course_page.dart';

const int holidayWeekIndex = 999;

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  static const TimetableViewDataService _viewDataService =
      TimetableViewDataService();

  late final TimetableNavigationController _navigationController;

  @override
  void initState() {
    super.initState();
    _navigationController = TimetableNavigationController(
      settingsProvider: context.read<SettingsProvider>(),
      timetableViewProvider: context.read<TimetableViewProvider>(),
      holidayWeekIndex: holidayWeekIndex,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _navigationController.syncInitialPosition(
        animateWeek: false,
        animateDay: false,
      );
    });
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final timetableViewProvider = context.watch<TimetableViewProvider>();
    final screenData = _viewDataService.build(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      totalWeeks: settingsProvider.totalWeeks,
      languageCode: settingsProvider.languageCode,
      translate: settingsProvider.t,
      getDateFor: settingsProvider.getDateFor,
      timeSlots: settingsProvider.timeSlots,
      holidayWeekIndex: holidayWeekIndex,
    );

    final currentWeek = timetableViewProvider.currentWeek
        .clamp(1, settingsProvider.totalWeeks)
        .toInt();
    final currentWeekday = timetableViewProvider.currentWeekday
        .clamp(1, 7)
        .toInt();
    final currentDayPage =
        screenData.dayPages[(currentWeek - 1) * 7 + (currentWeekday - 1)];
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return AnimatedBuilder(
      animation: _navigationController,
      builder: (context, _) {
        final displayWeek = _navigationController.currentDisplayWeek;
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                WeekSelector(
                  currentWeek: displayWeek,
                  options: screenData.weekOptions,
                  tooltip: settingsProvider.t('jump_to_week'),
                  onSelected: _navigationController.jumpToWeek,
                ),
                IconButton(
                  onPressed: _navigationController.jumpToToday,
                  icon: const Icon(Icons.today),
                  tooltip: settingsProvider.t('today'),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  final importedCount = await navigator.push<int>(
                    MaterialPageRoute<int>(
                      builder: (_) => const ImportCoursePage(),
                    ),
                  );

                  if (!mounted || importedCount == null) {
                    return;
                  }

                  final summaryMessage = settingsProvider.languageCode == 'en'
                      ? 'Successfully imported $importedCount courses'
                      : '总共添加了 $importedCount 门课';
                  messenger.showSnackBar(
                    SnackBar(content: Text(summaryMessage)),
                  );
                },
                icon: const Icon(Icons.cloud_download_outlined),
                tooltip: settingsProvider.t('import_from_system'),
              ),
              IconButton(
                onPressed: () async {
                  await navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddCoursePage(),
                    ),
                  );
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
                  selected: {_navigationController.mode},
                  onSelectionChanged: (selection) {
                    _navigationController.setMode(selection.first);
                  },
                ),
              ),
            ),
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _navigationController.mode == TimetableMode.day
                ? PageView.builder(
                    key: const ValueKey('day-view'),
                    controller: _navigationController.dayPageController,
                    itemCount: screenData.dayPages.length,
                    onPageChanged:
                        _navigationController.handleAbsoluteDayChanged,
                    itemBuilder: (context, index) {
                      final pageData = screenData.dayPages[index];
                      final pageWeekChips =
                          screenData.dayChipsByWeek[pageData.week] ??
                          const <TimetableDayChipData>[];
                      return DayAgendaView(
                        pageData: pageData,
                        chips: pageWeekChips,
                        selectedWeekday: pageData.week == currentWeek
                            ? currentDayPage.weekday
                            : pageData.weekday,
                        onDaySelected: (weekday) {
                          _navigationController.jumpToDay(
                            week: pageData.week,
                            weekday: weekday,
                          );
                        },
                        onCourseTap: (course) {
                          showCourseDetailsSheet(context, course);
                        },
                        onEventTap: (event) {
                          showEventDetailsSheet(context, event);
                        },
                        coursePeriodTextBuilder: _buildCoursePeriodText,
                        eventMarkerLabel: settingsProvider.t('event_marker'),
                        locationPendingLabel: settingsProvider.t(
                          'location_pending',
                        ),
                      );
                    },
                  )
                : PageView.builder(
                    key: const ValueKey('week-view'),
                    controller: _navigationController.weekPageController,
                    itemCount: screenData.weekPages.length + 1,
                    onPageChanged: (index) {
                      if (index == screenData.weekPages.length) {
                        _navigationController.handleWeekChanged(
                          holidayWeekIndex,
                        );
                        return;
                      }
                      _navigationController.handleWeekChanged(index + 1);
                    },
                    itemBuilder: (context, index) {
                      if (index == screenData.weekPages.length) {
                        return HolidayListView(
                          pageData: screenData.holidayPage,
                          onEventTap: (event) {
                            showEventDetailsSheet(context, event);
                          },
                        );
                      }

                      return TimetableGrid(
                        pageData: screenData.weekPages[index],
                        onCourseTap: (course) {
                          showCourseDetailsSheet(context, course);
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
    return context
        .read<SettingsProvider>()
        .t('period_range_format')
        .replaceAll('{start}', course.startPeriod.toString())
        .replaceAll('{end}', course.endPeriod.toString());
  }
}
