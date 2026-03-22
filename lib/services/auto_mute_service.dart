import 'dart:io';

import 'package:flutter/services.dart';

import '../models/course.dart';
import '../models/time_slot.dart';
import '../providers/settings_provider.dart';

class AutoMuteService {
  AutoMuteService._();

  static final AutoMuteService instance = AutoMuteService._();
  static const MethodChannel _channel = MethodChannel('app.auto_mute');

  Future<bool> isSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final value = await _channel.invokeMethod<bool>('isSupported');
    return value ?? false;
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final value = await _channel.invokeMethod<bool>('hasPermission');
    return value ?? false;
  }

  Future<void> openPermissionSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('openPermissionSettings');
  }

  Future<void> setSilentNow() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('setSilentNow');
  }

  Future<void> scheduleMuteTasks(
    List<Course> courses,
    SettingsProvider settings,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }

    if (!settings.autoMuteEnabled) {
      await _channel.invokeMethod<void>('replaceTasks', {
        'tasks': <Map<String, Object?>>[],
      });
      return;
    }

    final permissionGranted = await hasPermission();
    if (!permissionGranted) {
      await _channel.invokeMethod<void>('replaceTasks', {
        'tasks': <Map<String, Object?>>[],
      });
      return;
    }

    final now = DateTime.now();
    final currentWeek = settings.currentRealWeek;
    final currentWeekday = settings.currentRealWeekday;
    final slots = settings.timeSlots;
    final tasks = <Map<String, Object?>>[];

    final todaysCourses = courses
        .where(
          (course) =>
              course.weekday == currentWeekday &&
              course.weeks.contains(currentWeek),
        )
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    for (final course in todaysCourses) {
      final startTime = _buildCourseDateTime(
        settings: settings,
        slots: slots,
        week: currentWeek,
        weekday: currentWeekday,
        period: course.startPeriod,
      );
      final endTime = _buildCourseDateTime(
        settings: settings,
        slots: slots,
        week: currentWeek,
        weekday: currentWeekday,
        period: course.endPeriod,
        useEndTime: true,
      );

      if (startTime == null || endTime == null) {
        continue;
      }

      if (startTime.isBefore(now) && endTime.isAfter(now)) {
        await setSilentNow();
      }

      if (startTime.isAfter(now)) {
        tasks.add({
          'id': _alarmIdFor(course, currentWeek, true),
          'timestamp': startTime.millisecondsSinceEpoch,
          'mode': 'vibrate',
        });
      }

      if (endTime.isAfter(now)) {
        tasks.add({
          'id': _alarmIdFor(course, currentWeek, false),
          'timestamp': endTime.millisecondsSinceEpoch,
          'mode': 'normal',
        });
      }
    }

    await _channel.invokeMethod<void>('replaceTasks', {
      'tasks': tasks,
    });
  }

  DateTime? _buildCourseDateTime({
    required SettingsProvider settings,
    required List<TimeSlot> slots,
    required int week,
    required int weekday,
    required int period,
    bool useEndTime = false,
  }) {
    if (period <= 0 || period > slots.length) {
      return null;
    }

    final slot = slots[period - 1];
    final courseDate = settings.getDateFor(week, weekday);
    final time = useEndTime ? slot.endTime : slot.startTime;

    return DateTime(
      courseDate.year,
      courseDate.month,
      courseDate.day,
      time.hour,
      time.minute,
    );
  }

  int _alarmIdFor(Course course, int week, bool isMute) {
    return Object.hash(
          course.name,
          course.teacher,
          course.location,
          course.weekday,
          course.startPeriod,
          course.endPeriod,
          week,
          isMute ? 'mute' : 'normal',
        ) &
        0x7fffffff;
  }
}
