import '../models/clock_time.dart';
import '../models/course.dart';
import '../models/event.dart';
import '../models/time_slot.dart';

enum ManagedNotificationKind { courseReminder, eventReminder, manualMute }

class ManagedNotification {
  const ManagedNotification({
    required this.id,
    required this.kind,
    required this.scheduledAt,
    required this.title,
    required this.body,
  });

  final int id;
  final ManagedNotificationKind kind;
  final DateTime scheduledAt;
  final String title;
  final String body;
}

class AutoMuteWindow {
  const AutoMuteWindow({
    required this.id,
    required this.courseName,
    required this.location,
    required this.startAt,
    required this.endAt,
    required this.shouldScheduleSilent,
  });

  final int id;
  final String courseName;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
  final bool shouldScheduleSilent;
}

class TodayCourseSnapshot {
  const TodayCourseSnapshot({
    required this.courseName,
    required this.location,
    required this.startAt,
    required this.endAt,
  });

  final String courseName;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
}

class CourseStatusWindow {
  const CourseStatusWindow({
    required this.id,
    required this.courseName,
    required this.location,
    required this.startAt,
    required this.endAt,
  });

  final int id;
  final String courseName;
  final String location;
  final DateTime startAt;
  final DateTime endAt;
}

class SchedulePlan {
  const SchedulePlan({
    required this.notifications,
    required this.courseAutomationWindows,
    required this.todayCourses,
    required this.courseStatusWindows,
    required this.canAutoMute,
    required this.autoMuteFallbackEnabled,
  });

  final List<ManagedNotification> notifications;
  final List<AutoMuteWindow> courseAutomationWindows;
  final List<TodayCourseSnapshot> todayCourses;
  final List<CourseStatusWindow> courseStatusWindows;
  final bool canAutoMute;
  final bool autoMuteFallbackEnabled;

  List<AutoMuteWindow> get muteWindows => courseAutomationWindows;
}

class SchedulePlanBuilder {
  const SchedulePlanBuilder._();

  static int semesterCoverageDays(int totalWeeks) {
    return totalWeeks.clamp(1, 52).toInt() * DateTime.daysPerWeek;
  }

  static SchedulePlan build({
    required List<Course> courses,
    required List<Event> events,
    required List<TimeSlot> timeSlots,
    required DateTime semesterStartDate,
    required int totalWeeks,
    required int courseReminderAdvanceMinutes,
    required int eventReminderAdvanceMinutes,
    required bool autoMuteEnabled,
    required bool canAutoMute,
    bool retainAutoMuteWindows = false,
    bool nativeMuteFallbackEnabled = false,
    DateTime? now,
    int horizonDays = 14,
    int? maxNotificationCount,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final notifications = <ManagedNotification>[];
    final muteWindows = <AutoMuteWindow>[];
    final todayCourses = <TodayCourseSnapshot>[];
    final courseStatusWindows = <CourseStatusWindow>[];
    final shouldFallbackToManualMute = autoMuteEnabled && !canAutoMute;
    final shouldRetainAutoMuteWindows = canAutoMute || retainAutoMuteWindows;

    for (var dayOffset = 0; dayOffset < horizonDays; dayOffset += 1) {
      final day = today.add(Duration(days: dayOffset));
      final weekIndex = _weekIndexOf(day, semesterStartDate);
      if (weekIndex == null || weekIndex < 1 || weekIndex > totalWeeks) {
        continue;
      }

      final dayOccurrences = <_CourseOccurrenceEntry>[];
      for (final course in courses) {
        if (course.weekday != day.weekday ||
            !course.weeks.contains(weekIndex) ||
            course.startPeriod < 1 ||
            course.startPeriod > timeSlots.length) {
          continue;
        }

        final occurrence = _courseOccurrence(
          course: course,
          day: day,
          timeSlots: timeSlots,
        );
        if (occurrence == null) {
          continue;
        }
        dayOccurrences.add(
          _CourseOccurrenceEntry(course: course, occurrence: occurrence),
        );
      }

      dayOccurrences.sort(
        (a, b) => a.occurrence.startAt.compareTo(b.occurrence.startAt),
      );

      for (final entry in dayOccurrences) {
        final course = entry.course;
        final occurrence = entry.occurrence;

        if (dayOffset == 0) {
          todayCourses.add(
            TodayCourseSnapshot(
              courseName: course.name,
              location: course.location.trim(),
              startAt: occurrence.startAt,
              endAt: occurrence.endAt,
            ),
          );
        }

        if (!occurrence.endAt.isAfter(current)) {
          continue;
        }

        courseStatusWindows.add(
          CourseStatusWindow(
            id: _stableId('course-status', occurrence.key),
            courseName: course.name,
            location: course.location.trim(),
            startAt: occurrence.startAt,
            endAt: occurrence.endAt,
          ),
        );

        if (courseReminderAdvanceMinutes > 0) {
          final reminderAt = occurrence.startAt.subtract(
            Duration(minutes: courseReminderAdvanceMinutes),
          );
          final effectiveReminderAt = _effectiveCourseReminderAt(
            reminderAt: reminderAt,
            courseStartAt: occurrence.startAt,
            current: current,
            dayOccurrences: dayOccurrences,
            canAutoMute: canAutoMute,
          );
          if (effectiveReminderAt != null) {
            notifications.add(
              ManagedNotification(
                id: _stableId('course-reminder', occurrence.key),
                kind: ManagedNotificationKind.courseReminder,
                scheduledAt: effectiveReminderAt,
                title: '即将上课: ${course.name}',
                body:
                    '上课地点: ${_locationOrFallback(course.location.trim(), '未知')}',
              ),
            );
          }
        }

        if (shouldRetainAutoMuteWindows) {
          muteWindows.add(
            AutoMuteWindow(
              id: _stableId('mute-window', occurrence.key),
              courseName: course.name,
              location: course.location.trim(),
              startAt: occurrence.startAt,
              endAt: occurrence.endAt,
              shouldScheduleSilent: occurrence.startAt.isAfter(current),
            ),
          );
        } else if (shouldFallbackToManualMute &&
            !nativeMuteFallbackEnabled &&
            occurrence.startAt.isAfter(current)) {
          notifications.add(
            ManagedNotification(
              id: _stableId('manual-mute', occurrence.key),
              kind: ManagedNotificationKind.manualMute,
              scheduledAt: occurrence.startAt,
              title: '上课提醒: 请手动静音',
              body: '${course.name} 即将开始，当前设备权限不足，无法自动静音。',
            ),
          );
        }
      }
    }

    if (eventReminderAdvanceMinutes > 0) {
      for (final event in events) {
        if (!event.enableAlarm || !event.dateTime.isAfter(current)) {
          continue;
        }
        final reminderAt = event.dateTime.subtract(
          Duration(minutes: eventReminderAdvanceMinutes),
        );
        if (!reminderAt.isAfter(current)) {
          continue;
        }
        final location = event.location.trim();
        notifications.add(
          ManagedNotification(
            id: _stableId('event-reminder', event.id),
            kind: ManagedNotificationKind.eventReminder,
            scheduledAt: reminderAt,
            title: '日程提醒: ${event.name}',
            body: location.isEmpty ? '即将开始，请注意时间' : '地点: $location',
          ),
        );
      }
    }

    todayCourses.sort((a, b) => a.startAt.compareTo(b.startAt));
    notifications.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    muteWindows.sort((a, b) => a.startAt.compareTo(b.startAt));
    courseStatusWindows.sort((a, b) => a.startAt.compareTo(b.startAt));

    return SchedulePlan(
      notifications: _limitNotifications(
        notifications,
        maxNotificationCount: maxNotificationCount,
      ),
      courseAutomationWindows: List.unmodifiable(muteWindows),
      todayCourses: List.unmodifiable(todayCourses),
      courseStatusWindows: List.unmodifiable(courseStatusWindows),
      canAutoMute: canAutoMute,
      autoMuteFallbackEnabled: shouldFallbackToManualMute,
    );
  }

  static List<ManagedNotification> _limitNotifications(
    List<ManagedNotification> notifications, {
    required int? maxNotificationCount,
  }) {
    if (maxNotificationCount == null ||
        notifications.length <= maxNotificationCount) {
      return List.unmodifiable(notifications);
    }
    return List.unmodifiable(notifications.take(maxNotificationCount));
  }

  static _CourseOccurrence? _courseOccurrence({
    required Course course,
    required DateTime day,
    required List<TimeSlot> timeSlots,
  }) {
    final endPeriod = course.endPeriod.clamp(1, timeSlots.length).toInt();
    if (endPeriod < course.startPeriod) {
      return null;
    }

    final startSlot = timeSlots[course.startPeriod - 1];
    final endSlot = timeSlots[endPeriod - 1];
    if (!_isValidClockTime(startSlot.startTime) ||
        !_isValidClockTime(endSlot.endTime)) {
      return null;
    }

    final startAt = DateTime(
      day.year,
      day.month,
      day.day,
      startSlot.startTime.hour,
      startSlot.startTime.minute,
    );
    var endAt = DateTime(
      day.year,
      day.month,
      day.day,
      endSlot.endTime.hour,
      endSlot.endTime.minute,
    );
    if (!endAt.isAfter(startAt)) {
      endAt = endAt.add(const Duration(days: 1));
    }

    final key = [
      course.id,
      course.sessionKey,
      DateTime(day.year, day.month, day.day).toIso8601String(),
      startAt.millisecondsSinceEpoch,
      endAt.millisecondsSinceEpoch,
    ].join('|');

    return _CourseOccurrence(key: key, startAt: startAt, endAt: endAt);
  }

  static bool _isValidClockTime(ClockTime time) => time.isValid24Hour;

  static DateTime? _effectiveCourseReminderAt({
    required DateTime reminderAt,
    required DateTime courseStartAt,
    required DateTime current,
    required List<_CourseOccurrenceEntry> dayOccurrences,
    required bool canAutoMute,
  }) {
    var effectiveReminderAt = reminderAt;
    if (canAutoMute) {
      for (final entry in dayOccurrences) {
        final other = entry.occurrence;
        if (!other.endAt.isAfter(current) ||
            !other.startAt.isBefore(courseStartAt) ||
            effectiveReminderAt.isBefore(other.startAt) ||
            effectiveReminderAt.isAfter(other.endAt)) {
          continue;
        }

        final candidate = other.endAt.add(const Duration(seconds: 5));
        if (!candidate.isAfter(courseStartAt)) {
          effectiveReminderAt = candidate;
        }
      }
    }

    if (!effectiveReminderAt.isAfter(current) ||
        effectiveReminderAt.isAfter(courseStartAt)) {
      return null;
    }
    return effectiveReminderAt;
  }

  static int? _weekIndexOf(DateTime day, DateTime semesterStartDate) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final normalizedStart = DateTime(
      semesterStartDate.year,
      semesterStartDate.month,
      semesterStartDate.day,
    );
    final diff = normalizedDay.difference(normalizedStart).inDays;
    if (diff < 0) {
      return null;
    }
    return (diff ~/ 7) + 1;
  }

  static int _stableId(String namespace, String source) {
    var hash = 0x811c9dc5;
    for (final codeUnit in '$namespace|$source'.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x3fffffff;
  }

  static String _locationOrFallback(String location, String fallback) {
    return location.isEmpty ? fallback : location;
  }
}

class _CourseOccurrence {
  const _CourseOccurrence({
    required this.key,
    required this.startAt,
    required this.endAt,
  });

  final String key;
  final DateTime startAt;
  final DateTime endAt;
}

class _CourseOccurrenceEntry {
  const _CourseOccurrenceEntry({
    required this.course,
    required this.occurrence,
  });

  final Course course;
  final _CourseOccurrence occurrence;
}
