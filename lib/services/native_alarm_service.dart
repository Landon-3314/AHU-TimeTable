import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';

class NativeAlarmService {
  NativeAlarmService._();

  static final NativeAlarmService instance = NativeAlarmService._();
  static const MethodChannel _channel = MethodChannel(
    'com.timetable/native_alarm',
  );

  Future<bool> ensureExactAlarmPermission() async {
    try {
      final hasPermission =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      if (hasPermission) {
        return true;
      }
      await _channel.invokeMethod<void>('requestExactAlarmPermission');
      final recheck =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;
      return recheck;
    } catch (e) {
      debugPrint('[NativeAlarm] ensureExactAlarmPermission failed: $e');
      return false;
    }
  }

  Future<bool> ensureIgnoreBatteryOptimizations() async {
    try {
      final ignoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
      if (ignoring) {
        return true;
      }
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
      final recheck =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
      return recheck;
    } catch (e) {
      debugPrint('[NativeAlarm] ensureIgnoreBatteryOptimizations failed: $e');
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[NativeAlarm] requestIgnoreBatteryOptimization failed: $e');
    }
  }

  Future<void> scheduleClasses({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
    int horizonDays = 14,
  }) async {
    try {
      final now = DateTime.now();
      final timeSlots = settings.timeSlots;
      final payload = <Map<String, dynamic>>[];
      var courseIndex = 0;

      for (int dayOffset = 0; dayOffset < horizonDays; dayOffset++) {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: dayOffset));
        final weekIndex = _weekIndexOf(day, settings.semesterStartDate);
        if (weekIndex == null ||
            weekIndex < 1 ||
            weekIndex > settings.totalWeeks) {
          continue;
        }

        for (final course in courses) {
          if (course.weekday != day.weekday ||
              !course.weeks.contains(weekIndex)) {
            continue;
          }
          if (course.startPeriod < 1 || course.startPeriod > timeSlots.length) {
            continue;
          }

          final startSlot = timeSlots[course.startPeriod - 1];
          final endIndex =
              course.endPeriod.clamp(1, timeSlots.length).toInt() - 1;
          final endSlot = timeSlots[endIndex];

          final startTime = DateTime(
            day.year,
            day.month,
            day.day,
            startSlot.startTime.hour,
            startSlot.startTime.minute,
          );
          final endTime = DateTime(
            day.year,
            day.month,
            day.day,
            endSlot.endTime.hour,
            endSlot.endTime.minute,
          );

          if (!endTime.isAfter(now)) {
            continue;
          }

          int? reminderAtMillis;
          if (settings.reminderAdvanceMinutes > 0) {
            final reminderAt = startTime.subtract(
              Duration(minutes: settings.reminderAdvanceMinutes),
            );
            if (reminderAt.isAfter(now)) {
              reminderAtMillis = reminderAt.millisecondsSinceEpoch;
            }
          }

          payload.add({
            'courseIndex': courseIndex++,
            'silentAtMillis': startTime.millisecondsSinceEpoch,
            'restoreAtMillis': endTime.millisecondsSinceEpoch,
            'reminderAtMillis': reminderAtMillis,
            'title': '\u5373\u5c06\u4e0a\u8bfe: ${course.name}',
            'content':
                '\u4e0a\u8bfe\u5730\u70b9: ${course.location.isEmpty ? "\u672a\u77e5" : course.location}',
            'reminderAction': 'com.timetable.ACTION_REMIND_CLASS',
          });
        }
      }

      if (settings.eventReminderAdvanceMinutes > 0) {
        for (final event in events) {
          if (!event.enableAlarm) {
            continue;
          }
          final eventTime = event.dateTime;
          if (!eventTime.isAfter(now)) {
            continue;
          }

          final reminderAt = eventTime.subtract(
            Duration(minutes: settings.eventReminderAdvanceMinutes),
          );
          if (!reminderAt.isAfter(now)) {
            continue;
          }

          payload.add({
            'courseIndex': courseIndex++,
            'silentAtMillis': eventTime.millisecondsSinceEpoch,
            'restoreAtMillis': eventTime.millisecondsSinceEpoch,
            'reminderAtMillis': reminderAt.millisecondsSinceEpoch,
            'title': '\u65e5\u7a0b\u63d0\u9192: ${event.name}',
            'content': event.location.isEmpty
                ? '\u5373\u5c06\u5f00\u59cb\uff0c\u8bf7\u6ce8\u610f\u65f6\u95f4'
                : '\u5730\u70b9: ${event.location}',
            'reminderAction': 'com.timetable.ACTION_REMIND_SCHEDULE',
          });
        }
      }

      await _channel.invokeMethod<void>('scheduleAllClasses', {
        'classes': payload,
      });
    } catch (e) {
      debugPrint('[NativeAlarm] scheduleClasses failed: $e');
    }
  }

  Future<void> cancelAllClasses() async {
    try {
      await _channel.invokeMethod<void>('cancelAllClasses');
    } catch (e) {
      debugPrint('[NativeAlarm] cancelAllClasses failed: $e');
    }
  }

  int? _weekIndexOf(DateTime day, DateTime semesterStartDate) {
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
}
