import 'course.dart';
import 'event.dart';

class TimetableWeekOption {
  const TimetableWeekOption({
    required this.value,
    required this.label,
    this.isHoliday = false,
  });

  final int value;
  final String label;
  final bool isHoliday;
}

class TimetableDayChipData {
  const TimetableDayChipData({
    required this.weekday,
    required this.label,
    required this.dateLabel,
  });

  final int weekday;
  final String label;
  final String dateLabel;
}

class TimetableDayPageData {
  const TimetableDayPageData({
    required this.absoluteIndex,
    required this.week,
    required this.weekday,
    required this.summaryLabel,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.items,
  });

  final int absoluteIndex;
  final int week;
  final int weekday;
  final String summaryLabel;
  final String headerTitle;
  final String headerSubtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final List<TimetableAgendaItemData> items;

  bool get isEmpty => items.isEmpty;
}

class TimetableWeekPageData {
  const TimetableWeekPageData({
    required this.week,
    required this.title,
    required this.subtitle,
    required this.sections,
  });

  final int week;
  final String title;
  final String subtitle;
  final List<TimetableWeekSectionData> sections;

  bool get isEmpty => sections.every((section) => section.isEmpty);
}

class TimetableWeekSectionData {
  const TimetableWeekSectionData({
    required this.title,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final List<TimetableAgendaItemData> items;
  final String emptyText;

  bool get isEmpty => items.isEmpty;
}

class TimetableHolidayPageData {
  const TimetableHolidayPageData({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.events,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Event> events;

  bool get isEmpty => events.isEmpty;
}

class TimetableAgendaItemData {
  const TimetableAgendaItemData._({
    required this.sortTime,
    this.course,
    this.event,
  });

  factory TimetableAgendaItemData.course({
    required Course course,
    required DateTime sortTime,
  }) {
    return TimetableAgendaItemData._(course: course, sortTime: sortTime);
  }

  factory TimetableAgendaItemData.event({
    required Event event,
    required DateTime sortTime,
  }) {
    return TimetableAgendaItemData._(event: event, sortTime: sortTime);
  }

  final DateTime sortTime;
  final Course? course;
  final Event? event;

  bool get isCourse => course != null;
}

class TimetableScreenData {
  const TimetableScreenData({
    required this.weekOptions,
    required this.dayChipsByWeek,
    required this.dayPages,
    required this.weekPages,
    required this.holidayPage,
  });

  final List<TimetableWeekOption> weekOptions;
  final Map<int, List<TimetableDayChipData>> dayChipsByWeek;
  final List<TimetableDayPageData> dayPages;
  final List<TimetableWeekPageData> weekPages;
  final TimetableHolidayPageData holidayPage;
}
