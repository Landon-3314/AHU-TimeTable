import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import '../models/clock_time.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import 'schedule_calculator.dart';

const String _serviceTitle = '课表服务准备就绪';
const String _serviceContent = '正在守护您的上课静音';
const int _serviceNotificationId = 888;
const String _serviceChannelId = 'class_mute_foreground';

const String _coursesKey = 'courses.items';
const String _semesterStartDateKey = 'settings.semesterStartDate';
const String _totalWeeksKey = 'settings.totalWeeks';
const String _autoMuteEnabledKey = 'settings.autoMuteEnabled';
const String _backgroundServiceEnabledKey = 'settings.backgroundServiceEnabled';
const String _classDurationKey = 'settings.classDuration';
const String _shortBreakKey = 'settings.shortBreak';
const String _bigBreakKey = 'settings.bigBreak';
const String _bigBreakAfterPeriodKey = 'settings.bigBreakAfterPeriod';
const String _morningStartTimeKey = 'settings.morningStartTime';
const String _morningClassesKey = 'settings.morningClasses';
const String _afternoonStartTimeKey = 'settings.afternoonStartTime';
const String _afternoonClassesKey = 'settings.afternoonClasses';
const String _eveningStartTimeKey = 'settings.eveningStartTime';
const String _eveningClassesKey = 'settings.eveningClasses';

class BackgroundServiceManager {
  BackgroundServiceManager._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _configured = false;

  static Future<void> initialize() async {
    if (_configured) {
      return;
    }

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const channel = AndroidNotificationChannel(
      _serviceChannelId,
      '上课静音保活服务',
      description: '用于维持后台计算上课时间的常驻通知',
      importance: Importance.low,
    );

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_bg_service_small'),
      ),
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _serviceChannelId,
        initialNotificationTitle: _serviceTitle,
        initialNotificationContent: _serviceContent,
        foregroundServiceNotificationId: _serviceNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );

    _configured = true;
  }

  static Future<void> setEnabled(bool enabled) async {
    await initialize();
    final running = await _service.isRunning();

    if (enabled) {
      if (!running) {
        await _service.startService();
      }
      _service.invoke('refresh_schedule');
    } else {
      if (running) {
        _service.invoke('stop_service');
      }
    }
  }

  static Future<void> requestRefresh() async {
    await initialize();
    if (await _service.isRunning()) {
      _service.invoke('refresh_schedule');
    }
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  final brain = _ScheduleBrain(service);

  service.on('refresh_schedule').listen((_) async {
    await brain.refresh(trigger: 'refresh_schedule');
  });

  service.on('test_1_min_mute').listen((_) {
    debugPrint('[DND Debug - Background] 后台已收到 1 分钟测试指令，开始倒计时...');
    brain.startOneMinuteTestMute();
  });

  service.on('stop_service').listen((_) async {
    await brain.dispose();
    service.stopSelf();
  });

  service.on('stopService').listen((_) async {
    await brain.dispose();
    service.stopSelf();
  });

  await brain.start();
}

class _ScheduleBrain {
  _ScheduleBrain(this._service);

  final ServiceInstance _service;
  final ScheduleCalculator _calculator = const ScheduleCalculator();

  Timer? _preciseTimer;
  Timer? _heartbeatTimer;
  Timer? _testMuteTimer;
  bool _mutedByService = false;

  Future<void> start() async {
    await refresh(trigger: 'start');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await refresh(trigger: 'heartbeat');
    });
  }

  void startOneMinuteTestMute() {
    _testMuteTimer?.cancel();
    _testMuteTimer = Timer(const Duration(minutes: 1), () async {
      debugPrint('[DND Debug - Background] 1 分钟倒计时结束，准备执行静音');
      await _setSilentMode();
      await _updateForeground('上课中，已自动为您静音（测试触发）');
    });
  }

  Future<void> refresh({required String trigger}) async {
    final snapshot = await _loadSnapshot();

    if (!snapshot.backgroundServiceEnabled || !snapshot.autoMuteEnabled) {
      if (_mutedByService) {
        await _setNormalMode();
        _mutedByService = false;
      }
      await _updateForeground('自动静音已关闭');
      _preciseTimer?.cancel();
      return;
    }

    final now = DateTime.now();
    final today = _buildTodayWindows(now: now, snapshot: snapshot);

    debugPrint('=== 后台调度器状态更新 ===');
    debugPrint('触发来源: $trigger');
    debugPrint('当前时间: $now');
    debugPrint('今日课程数量: ${today.length}');
    if (today.isNotEmpty) {
      debugPrint('首节课时间: ${today.first.start} - ${today.first.end}');
    }
    debugPrint('=========================');

    _CourseWindow? current;
    for (final course in today) {
      final inClass =
          (now.isAfter(course.start) || now.isAtSameMomentAs(course.start)) &&
              now.isBefore(course.end);
      if (inClass) {
        current = course;
        break;
      }
    }

    if (current != null) {
      await _setSilentMode();
      _mutedByService = true;
      await _updateForeground('上课中，已自动为您静音');
      _schedulePrecise(current.end.difference(now));
      return;
    }

    if (_mutedByService) {
      await _setNormalMode();
      _mutedByService = false;
    }

    final next = today.where((e) => e.start.isAfter(now)).fold<_CourseWindow?>(
      null,
      (best, item) {
        if (best == null || item.start.isBefore(best.start)) {
          return item;
        }
        return best;
      },
    );

    if (next == null) {
      await _updateForeground('下一节课：今日已无课程');
      _preciseTimer?.cancel();
      return;
    }

    final hh = next.start.hour.toString().padLeft(2, '0');
    final mm = next.start.minute.toString().padLeft(2, '0');
    await _updateForeground('下一节课：${next.course.name} $hh:$mm');
    _schedulePrecise(next.start.difference(now));
  }

  Future<void> _setSilentMode() async {
    try {
      await SoundMode.setSoundMode(RingerModeStatus.silent);
    } catch (e) {
      debugPrint('[DND Debug - Background] 设置静音失败: $e');
    }
  }

  Future<void> _setNormalMode() async {
    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    } catch (e) {
      debugPrint('[DND Debug - Background] 恢复正常模式失败: $e');
    }
  }

  void _schedulePrecise(Duration delay) {
    _preciseTimer?.cancel();
    _preciseTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      await refresh(trigger: 'precise_timer');
    });
  }

  Future<void> _updateForeground(String content) async {
    if (_service case AndroidServiceInstance androidService) {
      await androidService.setForegroundNotificationInfo(
        title: _serviceTitle,
        content: content,
      );
    }
  }

  Future<_Snapshot> _loadSnapshot() async {
    final prefs = await SharedPreferences.getInstance();

    final semesterRaw = prefs.getString(_semesterStartDateKey);
    final semesterStart = semesterRaw == null
        ? _calculator.defaultSemesterStartDate()
        : _calculator.alignToMonday(
            DateTime.tryParse(semesterRaw) ?? _calculator.defaultSemesterStartDate(),
          );

    final timeSlots = _calculator.generateTimeSlots(
      classDuration: prefs.getInt(_classDurationKey) ?? 45,
      shortBreak: prefs.getInt(_shortBreakKey) ?? 5,
      bigBreak: prefs.getInt(_bigBreakKey) ?? 15,
      bigBreakAfterPeriod: prefs.getInt(_bigBreakAfterPeriodKey) ?? 2,
      morningStartTime: ClockTime.fromString(
        prefs.getString(_morningStartTimeKey) ?? '08:00',
      ),
      morningClasses: prefs.getInt(_morningClassesKey) ?? 5,
      afternoonStartTime: ClockTime.fromString(
        prefs.getString(_afternoonStartTimeKey) ?? '14:00',
      ),
      afternoonClasses: prefs.getInt(_afternoonClassesKey) ?? 5,
      eveningStartTime: ClockTime.fromString(
        prefs.getString(_eveningStartTimeKey) ?? '19:00',
      ),
      eveningClasses: prefs.getInt(_eveningClassesKey) ?? 3,
    );

    final rawCourses = prefs.getStringList(_coursesKey) ?? const <String>[];
    final courses = <Course>[];
    for (final raw in rawCourses) {
      try {
        courses.add(Course.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Ignore malformed rows to keep scheduler running.
      }
    }

    return _Snapshot(
      courses: courses,
      semesterStartDate: semesterStart,
      totalWeeks: prefs.getInt(_totalWeeksKey) ?? 18,
      autoMuteEnabled: prefs.getBool(_autoMuteEnabledKey) ?? false,
      backgroundServiceEnabled: prefs.getBool(_backgroundServiceEnabledKey) ?? false,
      timeSlots: timeSlots,
    );
  }

  List<_CourseWindow> _buildTodayWindows({
    required DateTime now,
    required _Snapshot snapshot,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final weekIndex = _weekIndexOf(today, snapshot.semesterStartDate);
    if (weekIndex == null || weekIndex < 1 || weekIndex > snapshot.totalWeeks) {
      return const <_CourseWindow>[];
    }

    final windows = <_CourseWindow>[];
    for (final course in snapshot.courses) {
      if (course.weekday != today.weekday || !course.weeks.contains(weekIndex)) {
        continue;
      }
      if (course.startPeriod < 1 || course.startPeriod > snapshot.timeSlots.length) {
        continue;
      }

      final startSlot = snapshot.timeSlots[course.startPeriod - 1];
      final endIndex = course.endPeriod.clamp(1, snapshot.timeSlots.length).toInt() - 1;
      final endSlot = snapshot.timeSlots[endIndex];
      windows.add(
        _CourseWindow(
          course: course,
          start: DateTime(
            today.year,
            today.month,
            today.day,
            startSlot.startTime.hour,
            startSlot.startTime.minute,
          ),
          end: DateTime(
            today.year,
            today.month,
            today.day,
            endSlot.endTime.hour,
            endSlot.endTime.minute,
          ),
        ),
      );
    }

    windows.sort((a, b) => a.start.compareTo(b.start));
    return windows;
  }

  int? _weekIndexOf(DateTime date, DateTime semesterStartDate) {
    final diff = date.difference(
      DateTime(semesterStartDate.year, semesterStartDate.month, semesterStartDate.day),
    ).inDays;
    if (diff < 0) {
      return null;
    }
    return (diff ~/ 7) + 1;
  }

  Future<void> dispose() async {
    _preciseTimer?.cancel();
    _heartbeatTimer?.cancel();
    _testMuteTimer?.cancel();
    if (_mutedByService) {
      await _setNormalMode();
      _mutedByService = false;
    }
  }
}

class _Snapshot {
  const _Snapshot({
    required this.courses,
    required this.semesterStartDate,
    required this.totalWeeks,
    required this.autoMuteEnabled,
    required this.backgroundServiceEnabled,
    required this.timeSlots,
  });

  final List<Course> courses;
  final DateTime semesterStartDate;
  final int totalWeeks;
  final bool autoMuteEnabled;
  final bool backgroundServiceEnabled;
  final List<TimeSlot> timeSlots;
}

class _CourseWindow {
  const _CourseWindow({
    required this.course,
    required this.start,
    required this.end,
  });

  final Course course;
  final DateTime start;
  final DateTime end;
}
