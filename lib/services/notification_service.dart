import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/event.dart';
import '../models/time_slot.dart';
import '../providers/settings_provider.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _courseReminderChannel =
      AndroidNotificationChannel(
    'course_reminders',
    'Course Reminders',
    description: 'Notifications for upcoming classes',
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _timeZoneChannel = MethodChannel('app.timezone');

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: initializationSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_courseReminderChannel);
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleAllCourseReminders(
    List<Course> courses,
    SettingsProvider settings,
  ) async {
    await initialize();
    await _plugin.cancelAll();
    await _scheduleCourseReminders(courses, settings);
  }

  Future<void> scheduleEventReminders(
    List<Event> events,
    int advanceMinutes,
  ) async {
    await initialize();
    await _plugin.cancelAll();
    await _scheduleEventReminders(events, advanceMinutes);
  }

  Future<void> refreshAllReminders({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    await initialize();
    await _plugin.cancelAll();
    await _scheduleCourseReminders(courses, settings);
    await _scheduleEventReminders(events, settings.reminderAdvanceMinutes);
  }

  Future<void> _scheduleCourseReminders(
    List<Course> courses,
    SettingsProvider settings,
  ) async {
    final advanceMinutes = settings.reminderAdvanceMinutes;
    if (advanceMinutes <= 0) {
      return;
    }

    final slots = settings.timeSlots;
    final now = DateTime.now();

    for (final course in courses) {
      for (final week in course.weeks) {
        final classStartTime = _buildClassStartTime(
          course: course,
          week: week,
          settings: settings,
          slots: slots,
        );

        if (classStartTime == null) {
          continue;
        }

        final scheduledTime = classStartTime.subtract(
          Duration(minutes: advanceMinutes),
        );
        if (!scheduledTime.isAfter(now)) {
          continue;
        }

        await _plugin.zonedSchedule(
          id: _notificationIdFor(course, week),
          title: '\u5373\u5c06\u4e0a\u8bfe\uff1a${course.name}',
          body:
              '\u5730\u70b9\uff1a${course.location.isEmpty ? '\u5f85\u5b9a' : course.location}',
          scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _courseReminderChannel.id,
              _courseReminderChannel.name,
              channelDescription: _courseReminderChannel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> _scheduleEventReminders(
    List<Event> events,
    int advanceMinutes,
  ) async {
    if (advanceMinutes <= 0) {
      return;
    }

    final now = DateTime.now();

    for (final event in events) {
      if (!event.enableAlarm) {
        continue;
      }

      final scheduledTime = event.dateTime.subtract(
        Duration(minutes: advanceMinutes),
      );
      if (!scheduledTime.isAfter(now)) {
        continue;
      }

      await _plugin.zonedSchedule(
        id: _eventNotificationIdFor(event),
        title: '\u65e5\u7a0b\u63d0\u9192\uff1a${event.name}',
        body:
            '\u65f6\u95f4\uff1a${_formatHourMinute(event.dateTime)} \u5730\u70b9\uff1a${event.location.isEmpty ? '\u5f85\u5b9a' : event.location}',
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _courseReminderChannel.id,
            _courseReminderChannel.name,
            channelDescription: _courseReminderChannel.description,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  DateTime? _buildClassStartTime({
    required Course course,
    required int week,
    required SettingsProvider settings,
    required List<TimeSlot> slots,
  }) {
    if (course.startPeriod <= 0 || course.startPeriod > slots.length) {
      return null;
    }

    final slot = slots[course.startPeriod - 1];
    final classDate = settings.getDateFor(week, course.weekday);

    return DateTime(
      classDate.year,
      classDate.month,
      classDate.day,
      slot.startTime.hour,
      slot.startTime.minute,
    );
  }

  int _notificationIdFor(Course course, int week) {
    return Object.hash(
          course.name,
          course.teacher,
          course.location,
          course.weekday,
          course.startPeriod,
          course.endPeriod,
          week,
        ) &
        0x7fffffff;
  }

  int _eventNotificationIdFor(Event event) {
    return (Object.hash(event.id, event.dateTime.toIso8601String()) &
            0x7fffffff) ^
        0x10000000;
  }

  String _formatHourMinute(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final timeZoneName =
          await _timeZoneChannel.invokeMethod<String>('getLocalTimezone');
      if (timeZoneName != null && timeZoneName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      }
    } catch (_) {
      // Fall through to deterministic fallback below.
    }

    try {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }
}
