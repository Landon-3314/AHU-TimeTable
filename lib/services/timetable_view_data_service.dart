import 'package:intl/intl.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../models/time_slot.dart';
import '../models/timetable_view_data.dart';

class TimetableViewDataService {
  const TimetableViewDataService();

  static const List<String> weekdayKeys = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  TimetableScreenData build({
    required List<Course> courses,
    required List<Event> events,
    required int totalWeeks,
    required String languageCode,
    required String Function(String key) translate,
    required DateTime Function(int week, int weekday) getDateFor,
    required List<TimeSlot> timeSlots,
    required int holidayWeekIndex,
  }) {
    final dayChipsByWeek = <int, List<TimetableDayChipData>>{};
    final dayPages = <TimetableDayPageData>[];
    final weekPages = <TimetableWeekPageData>[];
    final weekOptions = <TimetableWeekOption>[];

    for (var week = 1; week <= totalWeeks; week += 1) {
      weekOptions.add(
        TimetableWeekOption(value: week, label: _weekLabel(translate, week)),
      );
      dayChipsByWeek[week] = _buildDayChips(
        week: week,
        translate: translate,
        getDateFor: getDateFor,
      );
      dayPages.addAll(
        _buildDayPages(
          week: week,
          courses: courses,
          events: events,
          translate: translate,
          getDateFor: getDateFor,
          timeSlots: timeSlots,
        ),
      );
      weekPages.add(
        _buildWeekPage(
          week: week,
          courses: courses,
          events: events,
          translate: translate,
          getDateFor: getDateFor,
          timeSlots: timeSlots,
        ),
      );
    }

    weekOptions.add(
      TimetableWeekOption(
        value: holidayWeekIndex,
        label: languageCode == 'en' ? 'Holiday' : '假期中',
        isHoliday: true,
      ),
    );

    return TimetableScreenData(
      weekOptions: weekOptions,
      dayChipsByWeek: dayChipsByWeek,
      dayPages: dayPages,
      weekPages: weekPages,
      holidayPage: _buildHolidayPage(
        events: events,
        totalWeeks: totalWeeks,
        languageCode: languageCode,
        getDateFor: getDateFor,
      ),
    );
  }

  List<TimetableDayChipData> _buildDayChips({
    required int week,
    required String Function(String key) translate,
    required DateTime Function(int week, int weekday) getDateFor,
  }) {
    const dateFormat = 'MM/dd';
    return List<TimetableDayChipData>.generate(weekdayKeys.length, (index) {
      final weekday = index + 1;
      final date = getDateFor(week, weekday);
      return TimetableDayChipData(
        weekday: weekday,
        label: _weekdayShortLabel(translate, weekdayKeys[index]),
        dateLabel: DateFormat(dateFormat).format(date),
      );
    });
  }

  List<TimetableDayPageData> _buildDayPages({
    required int week,
    required List<Course> courses,
    required List<Event> events,
    required String Function(String key) translate,
    required DateTime Function(int week, int weekday) getDateFor,
    required List<TimeSlot> timeSlots,
  }) {
    return List<TimetableDayPageData>.generate(weekdayKeys.length, (index) {
      final weekday = index + 1;
      final pageDate = getDateFor(week, weekday);
      final dayCourses =
          courses
              .where(
                (course) =>
                    course.weekday == weekday && course.weeks.contains(week),
              )
              .toList()
            ..sort(
              (left, right) => left.startPeriod.compareTo(right.startPeriod),
            );
      final dayEvents =
          events.where((event) => _isSameDay(event.dateTime, pageDate)).toList()
            ..sort((left, right) => left.dateTime.compareTo(right.dateTime));

      final items = <TimetableAgendaItemData>[
        ...dayCourses.map(
          (course) => TimetableAgendaItemData.course(
            course: course,
            sortTime: _courseStartDateTime(
              course: course,
              pageDate: pageDate,
              timeSlots: timeSlots,
            ),
          ),
        ),
        ...dayEvents.map(
          (event) => TimetableAgendaItemData.event(
            event: event,
            sortTime: event.dateTime,
          ),
        ),
      ]..sort((left, right) => left.sortTime.compareTo(right.sortTime));

      final weekdayLabel = _weekdayLabel(translate, weekdayKeys[index]);
      final dateLabel = DateFormat('MM/dd').format(pageDate);
      return TimetableDayPageData(
        absoluteIndex: (week - 1) * weekdayKeys.length + index,
        week: week,
        weekday: weekday,
        summaryLabel:
            '${_weekLabel(translate, week)} / $weekdayLabel / $dateLabel',
        headerTitle: weekdayLabel,
        headerSubtitle: '${_weekLabel(translate, week)} / $dateLabel',
        emptyTitle: weekdayLabel,
        emptySubtitle: translate('no_courses_for_day'),
        items: items,
      );
    });
  }

  TimetableWeekPageData _buildWeekPage({
    required int week,
    required List<Course> courses,
    required List<Event> events,
    required String Function(String key) translate,
    required DateTime Function(int week, int weekday) getDateFor,
    required List<TimeSlot> timeSlots,
  }) {
    final weekStart = getDateFor(week, 1);
    final weekEnd = getDateFor(week, 7);
    final weekStartDateTime = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEndDateTime = DateTime(
      weekEnd.year,
      weekEnd.month,
      weekEnd.day,
      23,
      59,
      59,
    );
    final weekCourses = courses
        .where((course) => course.weeks.contains(week))
        .toList();
    final weekEvents =
        events
            .where(
              (event) =>
                  !event.dateTime.isBefore(weekStartDateTime) &&
                  !event.dateTime.isAfter(weekEndDateTime),
            )
            .toList()
          ..sort((left, right) => left.dateTime.compareTo(right.dateTime));

    final sections = List<TimetableWeekSectionData>.generate(weekdayKeys.length, (
      index,
    ) {
      final weekday = index + 1;
      final dayDate = getDateFor(week, weekday);
      final items = <TimetableAgendaItemData>[
        ...weekCourses
            .where((course) => course.weekday == weekday)
            .map(
              (course) => TimetableAgendaItemData.course(
                course: course,
                sortTime: _courseStartDateTime(
                  course: course,
                  pageDate: dayDate,
                  timeSlots: timeSlots,
                ),
              ),
            ),
        ...weekEvents
            .where((event) => _isSameDay(event.dateTime, dayDate))
            .map(
              (event) => TimetableAgendaItemData.event(
                event: event,
                sortTime: event.dateTime,
              ),
            ),
      ]..sort((left, right) => left.sortTime.compareTo(right.sortTime));

      return TimetableWeekSectionData(
        title:
            '${_weekdayLabel(translate, weekdayKeys[index])} / ${DateFormat('MM/dd').format(dayDate)}',
        items: items,
        emptyText: translate('no_courses_today'),
      );
    });

    return TimetableWeekPageData(
      week: week,
      title: _weekLabel(translate, week),
      subtitle:
          '${DateFormat('MM/dd').format(weekStart)} - ${DateFormat('MM/dd').format(weekEnd)}',
      sections: sections,
    );
  }

  TimetableHolidayPageData _buildHolidayPage({
    required List<Event> events,
    required int totalWeeks,
    required String languageCode,
    required DateTime Function(int week, int weekday) getDateFor,
  }) {
    final semesterStart = getDateFor(1, 1);
    final semesterEndBase = getDateFor(totalWeeks, 7);
    final semesterEnd = DateTime(
      semesterEndBase.year,
      semesterEndBase.month,
      semesterEndBase.day,
      23,
      59,
      59,
    );
    final holidayEvents =
        events
            .where(
              (event) =>
                  event.dateTime.isBefore(semesterStart) ||
                  event.dateTime.isAfter(semesterEnd),
            )
            .toList()
          ..sort((left, right) => left.dateTime.compareTo(right.dateTime));

    return TimetableHolidayPageData(
      title: languageCode == 'en' ? 'Holiday' : '假期中',
      subtitle: languageCode == 'en'
          ? 'Events outside semester weeks'
          : '展示所有非教学周日程',
      emptyTitle: languageCode == 'en' ? 'Holiday' : '假期中',
      emptySubtitle: languageCode == 'en' ? 'No holiday events.' : '假期暂无日程',
      events: holidayEvents,
    );
  }

  String _weekdayLabel(String Function(String key) translate, String key) {
    return translate(key);
  }

  String _weekdayShortLabel(String Function(String key) translate, String key) {
    return switch (key) {
      'monday' => translate('mon_short'),
      'tuesday' => translate('tue_short'),
      'wednesday' => translate('wed_short'),
      'thursday' => translate('thu_short'),
      'friday' => translate('fri_short'),
      'saturday' => translate('sat_short'),
      'sunday' => translate('sun_short'),
      _ => translate(key),
    };
  }

  String _weekLabel(String Function(String key) translate, int week) {
    return translate('week_label_format').replaceAll('{week}', week.toString());
  }

  DateTime _courseStartDateTime({
    required Course course,
    required DateTime pageDate,
    required List<TimeSlot> timeSlots,
  }) {
    final startPeriod = course.startPeriod;
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

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
