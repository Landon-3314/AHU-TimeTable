import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import 'add_course_page.dart';
import 'import_course_page.dart';

enum _TimetableMode {
  day,
  week,
}

String _weekdayLabel(SettingsProvider provider, String key) => provider.t(key);

String _weekdayShortLabel(SettingsProvider provider, String key) {
  return switch (key) {
    'monday' => provider.t('mon_short'),
    'tuesday' => provider.t('tue_short'),
    'wednesday' => provider.t('wed_short'),
    'thursday' => provider.t('thu_short'),
    'friday' => provider.t('fri_short'),
    'saturday' => provider.t('sat_short'),
    'sunday' => provider.t('sun_short'),
    _ => provider.t(key),
  };
}

String _weekLabel(SettingsProvider provider, int week) {
  return provider
      .t('week_label_format')
      .replaceAll('{week}', week.toString());
}

String _periodRangeLabel(SettingsProvider provider, int start, int end) {
  return provider
      .t('period_range_format')
      .replaceAll('{start}', start.toString())
      .replaceAll('{end}', end.toString());
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime _courseStartDateTime(
  DateTime pageDate,
  int startPeriod,
  SettingsProvider settingsProvider,
) {
  final timeSlots = settingsProvider.timeSlots;
  if (startPeriod <= 0 || startPeriod > timeSlots.length) {
    return pageDate;
  }

  final slot = timeSlots[startPeriod - 1];
  return DateTime(
    pageDate.year,
    pageDate.month,
    pageDate.day,
    slot.startTime.hour,
    slot.startTime.minute,
  );
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  static const List<String> _weekdayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late final PageController _dayPageController;
  late final PageController _weekPageController;
  _TimetableMode _mode = _TimetableMode.day;
  bool _isSyncingControllers = false;

  @override
  void initState() {
    super.initState();
    final settingsProvider = context.read<SettingsProvider>();
    final courseProvider = context.read<CourseProvider>();
    final initialWeek = settingsProvider.currentRealWeek.clamp(
      1,
      settingsProvider.totalWeeks,
    ).toInt();
    final initialWeekday = settingsProvider.currentRealWeekday.clamp(1, 7).toInt();

    courseProvider.setCurrentWeekAndWeekday(
      week: initialWeek,
      weekday: initialWeekday,
    );

    _weekPageController = PageController(initialPage: initialWeek - 1);
    _dayPageController = PageController(
      initialPage: (initialWeek - 1) * 7 + (initialWeekday - 1),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncToWeekAndWeekday(
        week: initialWeek,
        weekday: initialWeekday,
        animateWeek: false,
        animateDay: false,
      );
    });
  }

  @override
  void dispose() {
    _dayPageController.dispose();
    _weekPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final currentWeek = courseProvider.currentWeek.clamp(
      1,
      settingsProvider.totalWeeks,
    ).toInt();
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WeekJumpButton(
              currentWeek: currentWeek,
              totalWeeks: settingsProvider.totalWeeks,
              onSelected: _jumpToWeek,
            ),
            IconButton(
              onPressed: _jumpToToday,
              icon: const Icon(Icons.today),
              tooltip: settingsProvider.t('today'),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ImportCoursePage(),
                ),
              );
            },
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: settingsProvider.t('import_from_system'),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
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
            child: SegmentedButton<_TimetableMode>(
              segments: [
                ButtonSegment<_TimetableMode>(
                  value: _TimetableMode.day,
                  label: Text(settingsProvider.t('day_view')),
                  icon: const Icon(Icons.view_day_outlined),
                ),
                ButtonSegment<_TimetableMode>(
                  value: _TimetableMode.week,
                  label: Text(settingsProvider.t('week_view')),
                  icon: const Icon(Icons.calendar_view_week_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() {
                  _mode = selection.first;
                });
              },
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _mode == _TimetableMode.day
            ? DayViewWidget(
                key: const ValueKey('day-view'),
                pageController: _dayPageController,
                weekdayKeys: _weekdayKeys,
                onDayChanged: _handleAbsoluteDayChanged,
              )
            : WeekViewWidget(
                key: const ValueKey('week-view'),
                pageController: _weekPageController,
                weekdayKeys: _weekdayKeys,
                totalWeeks: settingsProvider.totalWeeks,
                onWeekChanged: _handleWeekChangedFromWeekView,
              ),
      ),
    );
  }

  Future<void> _jumpToWeek(int selectedWeek) async {
    final provider = context.read<CourseProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final targetWeek = selectedWeek.clamp(1, settingsProvider.totalWeeks).toInt();
    final targetWeekday = provider.currentWeekday.clamp(1, 7).toInt();

    provider.setCurrentWeek(targetWeek);

    _isSyncingControllers = true;
    try {
      if (_weekPageController.hasClients) {
        _weekPageController.jumpToPage(targetWeek - 1);
      }

      if (_dayPageController.hasClients) {
        _dayPageController.jumpToPage((targetWeek - 1) * 7 + (targetWeekday - 1));
      }
    } finally {
      _isSyncingControllers = false;
    }
  }

  Future<void> _jumpToToday() async {
    final settingsProvider = context.read<SettingsProvider>();
    final provider = context.read<CourseProvider>();
    final targetWeek = settingsProvider.currentRealWeek.clamp(
      1,
      settingsProvider.totalWeeks,
    ).toInt();
    final targetWeekday = settingsProvider.currentRealWeekday.clamp(1, 7).toInt();

    provider.setCurrentWeekAndWeekday(
      week: targetWeek,
      weekday: targetWeekday,
    );

    _isSyncingControllers = true;
    try {
      if (_weekPageController.hasClients) {
        _weekPageController.jumpToPage(targetWeek - 1);
      }

      if (_dayPageController.hasClients) {
        _dayPageController.jumpToPage((targetWeek - 1) * 7 + (targetWeekday - 1));
      }
    } finally {
      _isSyncingControllers = false;
    }
  }

  void _handleAbsoluteDayChanged(int index) {
    final settingsProvider = context.read<SettingsProvider>();
    final targetWeek = ((index ~/ 7) + 1).clamp(1, settingsProvider.totalWeeks).toInt();
    final targetWeekday = ((index % 7) + 1).clamp(1, 7).toInt();

    context.read<CourseProvider>().setCurrentWeekAndWeekday(
          week: targetWeek,
          weekday: targetWeekday,
        );

    if (_isSyncingControllers) {
      return;
    }

    if (_weekPageController.hasClients &&
        _weekPageController.page?.round() != targetWeek - 1) {
      _isSyncingControllers = true;
      _weekPageController.jumpToPage(targetWeek - 1);
      _isSyncingControllers = false;
    }
  }

  void _handleWeekChangedFromWeekView(int week) {
    final settingsProvider = context.read<SettingsProvider>();
    final provider = context.read<CourseProvider>();
    final targetWeek = week.clamp(1, settingsProvider.totalWeeks).toInt();
    final currentWeekday = provider.currentWeekday.clamp(1, 7).toInt();

    provider.setCurrentWeek(targetWeek);

    if (_isSyncingControllers) {
      return;
    }

    if (_dayPageController.hasClients) {
      final targetDayIndex = (targetWeek - 1) * 7 + (currentWeekday - 1);
      if (_dayPageController.page?.round() != targetDayIndex) {
        _isSyncingControllers = true;
        _dayPageController.jumpToPage(targetDayIndex);
        _isSyncingControllers = false;
      }
    }
  }

  void _syncToWeekAndWeekday({
    required int week,
    required int weekday,
    required bool animateWeek,
    required bool animateDay,
  }) {
    final settingsProvider = context.read<SettingsProvider>();
    final safeWeek = week.clamp(1, settingsProvider.totalWeeks).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    final dayIndex = (safeWeek - 1) * 7 + (safeWeekday - 1);

    _isSyncingControllers = true;
    try {
      if (_weekPageController.hasClients) {
        if (animateWeek) {
          _weekPageController.animateToPage(
            safeWeek - 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _weekPageController.jumpToPage(safeWeek - 1);
        }
      }

      if (_dayPageController.hasClients) {
        if (animateDay) {
          _dayPageController.animateToPage(
            dayIndex,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _dayPageController.jumpToPage(dayIndex);
        }
      }
    } finally {
      _isSyncingControllers = false;
    }
  }
}

class DayViewWidget extends StatefulWidget {
  const DayViewWidget({
    super.key,
    required this.pageController,
    required this.weekdayKeys,
    required this.onDayChanged,
  });

  final PageController pageController;
  final List<String> weekdayKeys;
  final ValueChanged<int> onDayChanged;

  @override
  State<DayViewWidget> createState() => _DayViewWidgetState();
}

class _DayViewWidgetState extends State<DayViewWidget> {
  late int _currentWeekday;

  @override
  void initState() {
    super.initState();
    _currentWeekday = context.read<CourseProvider>().currentWeekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses.toList();
    final events = courseProvider.events.toList();
    final currentWeek = courseProvider.currentWeek.clamp(
      1,
      settingsProvider.totalWeeks,
    ).toInt();
    final dateFormat = DateFormat('MM/dd');
    final currentDate = settingsProvider.getDateFor(currentWeek, _currentWeekday + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            '${_weekLabel(settingsProvider, currentWeek)} / '
            '${_weekdayLabel(settingsProvider, widget.weekdayKeys[_currentWeekday])} / '
            '${dateFormat.format(currentDate)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SizedBox(
          height: 64,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (int index = 0; index < widget.weekdayKeys.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_weekdayShortLabel(settingsProvider, widget.weekdayKeys[index])),
                          Text(
                            dateFormat.format(
                              settingsProvider.getDateFor(currentWeek, index + 1),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      selected: _currentWeekday == index,
                      onSelected: (_) async {
                        setState(() {
                          _currentWeekday = index;
                        });
                        await widget.pageController.animateToPage(
                          (currentWeek - 1) * 7 + index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: PageView.builder(
            controller: widget.pageController,
            itemCount: settingsProvider.totalWeeks * 7,
            onPageChanged: (index) {
              final targetWeek = (index ~/ 7) + 1;
              final targetWeekday = (index % 7) + 1;
              setState(() {
                _currentWeekday = targetWeekday - 1;
              });
              widget.onDayChanged(index);
              context.read<CourseProvider>().setCurrentWeek(targetWeek);
            },
            itemBuilder: (context, index) {
              final targetWeek = (index ~/ 7) + 1;
              final targetWeekday = (index % 7) + 1;
              final pageDate = settingsProvider.getDateFor(targetWeek, targetWeekday);
              final dayCourses = courses
                  .where(
                    (course) =>
                        course.weekday == targetWeekday &&
                        course.weeks.contains(targetWeek),
                  )
                  .toList()
                ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
              final dayEvents = events
                  .where((event) => DateUtils.isSameDay(event.dateTime, pageDate))
                  .toList()
                ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
              final dayItems = <_DayScheduleItem>[
                ...dayCourses.map(
                  (course) => _DayScheduleItem.course(
                    course,
                    _courseStartDateTime(pageDate, course.startPeriod, settingsProvider),
                  ),
                ),
                ...dayEvents.map(
                  (event) => _DayScheduleItem.event(event, event.dateTime),
                ),
              ]..sort((a, b) => a.sortTime.compareTo(b.sortTime));

              if (dayItems.isEmpty) {
                return _EmptyDayState(
                  title: _weekdayLabel(settingsProvider, widget.weekdayKeys[targetWeekday - 1]),
                  subtitle:
                      '${settingsProvider.t('no_courses_for_day')} (${DateFormat('MM/dd').format(pageDate)} / ${_weekLabel(settingsProvider, targetWeek)})',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: dayItems.length + 1,
                itemBuilder: (context, itemIndex) {
                  if (itemIndex == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DayHeaderCard(
                        title: _weekdayLabel(
                          settingsProvider,
                          widget.weekdayKeys[targetWeekday - 1],
                        ),
                        subtitle:
                            '${_weekLabel(settingsProvider, targetWeek)} / ${DateFormat('MM/dd').format(pageDate)}',
                      ),
                    );
                  }

                  final item = dayItems[itemIndex - 1];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: item.when(
                      course: (course) => CourseListCard(
                        course: course,
                        accentColor: course.color,
                        onTap: () => showCourseDetailsSheet(context, course),
                      ),
                      event: (event) => EventListCard(
                        event: event,
                        onTap: () => showEventDetailsSheet(context, event),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayHeaderCard extends StatelessWidget {
  const _DayHeaderCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}

class WeekViewWidget extends StatelessWidget {
  const WeekViewWidget({
    super.key,
    required this.pageController,
    required this.weekdayKeys,
    required this.totalWeeks,
    required this.onWeekChanged,
  });

  final PageController pageController;
  final List<String> weekdayKeys;
  final int totalWeeks;
  final ValueChanged<int> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final courses = context.watch<CourseProvider>().courses.toList();
    final dateFormat = DateFormat('MM/dd');

    return PageView.builder(
      controller: pageController,
      itemCount: totalWeeks,
      onPageChanged: (index) => onWeekChanged(index + 1),
      itemBuilder: (context, index) {
        final week = index + 1;
        final weekStart = settingsProvider.getDateFor(week, 1);
        final weekEnd = settingsProvider.getDateFor(week, 7);
        final weekCourses = courses.where((course) => course.weeks.contains(week)).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          children: [
            Text(
              _weekLabel(settingsProvider, week),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 16),
            for (int weekday = 1; weekday <= 7; weekday++) ...[
              _WeekdaySection(
                title:
                    '${_weekdayLabel(settingsProvider, weekdayKeys[weekday - 1])} / ${dateFormat.format(settingsProvider.getDateFor(week, weekday))}',
                courses: weekCourses
                    .where((course) => course.weekday == weekday)
                    .toList()
                  ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod)),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({
    required this.title,
    required this.courses,
  });

  final String title;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (courses.isEmpty)
            Text(
              provider.t('no_courses_today'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          for (final course in courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CourseListCard(
                course: course,
                accentColor: course.color,
                onTap: () => showCourseDetailsSheet(context, course),
              ),
            ),
        ],
      ),
    );
  }
}

class CourseListCard extends StatelessWidget {
  const CourseListCard({
    super.key,
    required this.course,
    required this.accentColor,
    required this.onTap,
  });

  final Course course;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentColor.withOpacity(0.18)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _teacherLocationText(course),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _periodRangeLabel(provider, course.startPeriod, course.endPeriod),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accentColor.withOpacity(0.95),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _teacherLocationText(Course course) {
    if (course.teacher.trim().isEmpty) {
      return course.location;
    }
    if (course.location.trim().isEmpty) {
      return course.teacher;
    }
    return '${course.teacher} / ${course.location}';
  }
}

class EventListCard extends StatelessWidget {
  const EventListCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();
    const accentColor = Color(0xFFF59E0B);

    return Card(
      elevation: 0,
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFCD34D)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${provider.t('event_marker')} ${event.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.location.isEmpty
                          ? provider.t('location_pending')
                          : event.location,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('HH:mm').format(event.dateTime),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekJumpButton extends StatelessWidget {
  const _WeekJumpButton({
    required this.currentWeek,
    required this.totalWeeks,
    required this.onSelected,
  });

  final int currentWeek;
  final int totalWeeks;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();

    return PopupMenuButton<int>(
      tooltip: provider.t('jump_to_week'),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (int week = 1; week <= totalWeeks; week++)
          PopupMenuItem<int>(
            value: week,
            child: Row(
              children: [
                Expanded(child: Text(_weekLabel(provider, week))),
                if (week == currentWeek) const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: Text(
            _weekLabel(provider, currentWeek),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

Future<void> showCourseDetailsSheet(BuildContext context, Course course) async {
  final provider = context.read<SettingsProvider>();
  final timeSlots = provider.timeSlots;
  final startSlot = course.startPeriod > 0 && course.startPeriod <= timeSlots.length
      ? timeSlots[course.startPeriod - 1]
      : null;
  final endSlot = course.endPeriod > 0 && course.endPeriod <= timeSlots.length
      ? timeSlots[course.endPeriod - 1]
      : null;
  final courseTimeText = startSlot != null && endSlot != null
      ? '${provider.t('time')}: ${_formatTimeOfDay(startSlot.startTime)} - ${_formatTimeOfDay(endSlot.endTime)} '
          '(${_periodRangeLabel(provider, course.startPeriod, course.endPeriod)})'
      : _periodRangeLabel(provider, course.startPeriod, course.endPeriod);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                label: provider.t('teacher'),
                value: course.teacher.isEmpty ? provider.t('not_set') : course.teacher,
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('location'),
                value: course.location.isEmpty ? provider.t('not_set') : course.location,
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('periods'),
                value: _periodRangeLabel(provider, course.startPeriod, course.endPeriod),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('time'),
                value: courseTimeText,
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('weekday'),
                value: _weekdayLabel(provider, _TimetablePageState._weekdayKeys[course.weekday - 1]),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('weeks'),
                value: course.weeks.join(', '),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AddCoursePage(existingCourse: course),
                      ),
                    );
                  },
                  child: Text(provider.t('edit_course')),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD64545),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await context.read<CourseProvider>().removeCourse(course);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Text(provider.t('delete_course')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showEventDetailsSheet(BuildContext context, Event event) async {
  final provider = context.read<SettingsProvider>();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              const SizedBox(height: 16),
              _DetailRow(
                label: provider.t('time'),
                value: DateFormat('yyyy/MM/dd HH:mm').format(event.dateTime),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('location'),
                value: event.location.isEmpty ? provider.t('not_set') : event.location,
              ),
              const SizedBox(height: 10),
              _DetailRow(
                label: provider.t('alarm'),
                value: event.enableAlarm ? provider.t('enabled') : provider.t('disabled'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD64545),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await context.read<CourseProvider>().deleteEvent(event.id);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: Text(provider.t('delete_event')),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DayScheduleItem {
  const _DayScheduleItem._({
    required this.sortTime,
    this.course,
    this.event,
  });

  factory _DayScheduleItem.course(Course course, DateTime sortTime) {
    return _DayScheduleItem._(course: course, sortTime: sortTime);
  }

  factory _DayScheduleItem.event(Event event, DateTime sortTime) {
    return _DayScheduleItem._(event: event, sortTime: sortTime);
  }

  final DateTime sortTime;
  final Course? course;
  final Event? event;

  T when<T>({
    required T Function(Course course) course,
    required T Function(Event event) event,
  }) {
    if (this.course != null) {
      return course(this.course!);
    }
    return event(this.event!);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

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
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

