import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../models/clock_time.dart';
import '../models/event.dart';
import '../models/time_slot.dart';
import 'audio_mode_service.dart';
import 'notification_service.dart';
import 'schedule_calculator.dart';
import 'storage_service.dart';

class BackgroundRuntimeService {
  BackgroundRuntimeService({
    AudioModeService? audioModeService,
    NotificationService? notificationService,
    ScheduleCalculator? scheduleCalculator,
  }) : _audioModeService = audioModeService ?? AudioModeService(),
       _notificationService =
           notificationService ?? NotificationService.backgroundWorker(),
       _scheduleCalculator = scheduleCalculator ?? const ScheduleCalculator();

  static const int foregroundServiceNotificationId = 9527;
  static const String foregroundServiceTitle = '课程表守护服务';
  static const String foregroundServiceContent = '正在后台保障自动静音与课前提醒';

  final AudioModeService _audioModeService;
  final NotificationService _notificationService;
  final ScheduleCalculator _scheduleCalculator;

  Timer? _timer;
  DeviceAudioMode? _lastAppliedMode;
  final Set<String> _notifiedCourseIds = <String>{};
  final Set<String> _notifiedEventIds = <String>{};
  String? _notifiedCourseDay;

  Future<void> start(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Must be registered before any potentially slow initialization.
    service.on('test_mute').listen((_) async {
      await _handleDeveloperCommand(
        service: service,
        action: _audioModeService.muteDeviceSafely,
      );
    });

    service.on('test_unmute').listen((_) async {
      await _handleDeveloperCommand(
        service: service,
        action: _audioModeService.restoreDeviceAudio,
      );
    });

    service.on('sync_now').listen((_) async {
      await runScheduleTick(service);
    });

    service.on('stop_service').listen((_) {
      _timer?.cancel();
      service.stopSelf();
    });

    ui.DartPluginRegistrant.ensureInitialized();
    await _notificationService.initializeForBackgroundIsolate();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      await _refreshForegroundNotification(service);
    }

    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) async => runScheduleTick(service),
    );

    await runScheduleTick(service);
  }

  Future<void> runScheduleTick(ServiceInstance service) async {
    try {
      final storageService = await StorageService.create();
      await storageService.reload();

      final nextMode = _computeTargetMode(storageService);
      await _applyMode(service: service, mode: nextMode);
      await _runCourseReminderTick(storageService);
      await _runEventReminderTick(storageService);
    } catch (error, stackTrace) {
      developer.log(
        'runScheduleTick error',
        name: 'BackgroundRuntimeService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  DeviceAudioMode _computeTargetMode(StorageService storageService) {
    final autoMuteEnabled = storageService.readAutoMuteEnabled(fallback: false);
    if (!autoMuteEnabled) {
      return DeviceAudioMode.normal;
    }

    final now = DateTime.now();
    final totalWeeks = storageService.readTotalWeeks(fallback: 20).clamp(1, 30);
    final semesterStartDate = _loadSemesterStartDate(storageService);
    final currentWeek = _scheduleCalculator.computeCurrentWeek(
      semesterStartDate: semesterStartDate,
      totalWeeks: totalWeeks,
      now: now,
    );
    final currentWeekday = now.weekday.clamp(1, 7);
    final slots = _generateTimeSlots(storageService);
    final courses = storageService.loadCourses();

    for (final course in courses) {
      if (course.weekday != currentWeekday) {
        continue;
      }

      if (!course.weeks.contains(currentWeek)) {
        continue;
      }

      final startPeriod = course.startPeriod;
      final endPeriod = course.endPeriod;
      if (startPeriod <= 0 ||
          endPeriod <= 0 ||
          startPeriod > slots.length ||
          endPeriod > slots.length) {
        continue;
      }

      final startSlot = slots[startPeriod - 1];
      final endSlot = slots[endPeriod - 1];
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        startSlot.startTime.hour,
        startSlot.startTime.minute,
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        endSlot.endTime.hour,
        endSlot.endTime.minute,
      );

      if (!now.isBefore(start) && now.isBefore(end)) {
        return DeviceAudioMode.vibrate;
      }
    }

    return DeviceAudioMode.normal;
  }

  Future<void> _applyMode({
    required ServiceInstance service,
    required DeviceAudioMode mode,
  }) async {
    if (mode == _lastAppliedMode) {
      return;
    }

    final granted = await _audioModeService.canControlAudioMode();
    if (!granted) {
      developer.log(
        'DND permission is not granted',
        name: 'BackgroundRuntimeService',
      );
      return;
    }

    await _audioModeService.applyMode(mode);
    _lastAppliedMode = mode;

    if (service is AndroidServiceInstance) {
      await _refreshForegroundNotification(service);
    }
  }

  Future<void> _runCourseReminderTick(StorageService storageService) async {
    final advanceMinutes = storageService
        .readReminderAdvanceMinutes(fallback: 0)
        .clamp(0, 60)
        .toInt();
    if (advanceMinutes <= 0) {
      return;
    }

    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    _resetCourseNotificationDeduplication(dayKey);

    final totalWeeks = storageService.readTotalWeeks(fallback: 20).clamp(1, 30);
    final semesterStartDate = _loadSemesterStartDate(storageService);
    final currentWeek = _scheduleCalculator.computeCurrentWeek(
      semesterStartDate: semesterStartDate,
      totalWeeks: totalWeeks,
      now: now,
    );
    final currentWeekday = now.weekday.clamp(1, 7);
    final slots = _generateTimeSlots(storageService);
    final courses = storageService.loadCourses();

    for (final course in courses) {
      if (course.weekday != currentWeekday) {
        continue;
      }

      if (!course.weeks.contains(currentWeek)) {
        continue;
      }

      final startPeriod = course.startPeriod;
      if (startPeriod <= 0 || startPeriod > slots.length) {
        continue;
      }

      final slot = slots[startPeriod - 1];
      final classStart = DateTime(
        now.year,
        now.month,
        now.day,
        slot.startTime.hour,
        slot.startTime.minute,
      );
      final reminderTime = classStart.subtract(
        Duration(minutes: advanceMinutes),
      );
      if (!_isSameMinute(now, reminderTime)) {
        continue;
      }

      final courseName = course.name.trim();
      if (courseName.isEmpty) {
        continue;
      }

      final dedupeId = '$dayKey-$currentWeek-$courseName-$startPeriod';
      if (_notifiedCourseIds.contains(dedupeId)) {
        continue;
      }

      await _notificationService.showCourseReminder(
        course: course,
        notificationId: dedupeId.hashCode & 0x7fffffff,
      );
      _notifiedCourseIds.add(dedupeId);
    }
  }

  Future<void> _runEventReminderTick(StorageService storageService) async {
    final advanceMinutes = storageService
        .readEventReminderAdvanceMinutes(fallback: 0)
        .clamp(0, 1440)
        .toInt();
    if (advanceMinutes <= 0) {
      return;
    }

    final now = DateTime.now();
    final events = storageService.loadEvents();
    _pruneExpiredEventNotifications(events, now);

    for (final event in events) {
      if (!event.enableAlarm) {
        continue;
      }

      final reminderTime = event.dateTime.subtract(
        Duration(minutes: advanceMinutes),
      );
      final eventEndTime = _eventNotificationWindowEnd(event);
      if (now.isBefore(reminderTime) || !now.isBefore(eventEndTime)) {
        continue;
      }

      final eventName = event.name.trim();
      if (eventName.isEmpty) {
        continue;
      }

      if (_notifiedEventIds.contains(event.id)) {
        continue;
      }

      try {
        await _notificationService.showEventReminder(
          event: event,
          notificationId: event.id.hashCode & 0x7fffffff,
        );
      } catch (error, stackTrace) {
        developer.log(
          'showEventReminder failed',
          name: 'BackgroundRuntimeService',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }

      _notifiedEventIds.add(event.id);
    }
  }

  List<TimeSlot> _generateTimeSlots(StorageService storageService) {
    return _scheduleCalculator.generateTimeSlots(
      classDuration: storageService.readClassDuration(fallback: 45),
      shortBreak: storageService.readShortBreak(fallback: 5),
      bigBreak: storageService.readBigBreak(fallback: 15),
      morningStartTime: ClockTime.fromString(
        storageService.readMorningStartTime(fallback: '08:00'),
      ),
      morningClasses: storageService.readMorningClasses(fallback: 5),
      afternoonStartTime: ClockTime.fromString(
        storageService.readAfternoonStartTime(fallback: '14:00'),
      ),
      afternoonClasses: storageService.readAfternoonClasses(fallback: 5),
      eveningStartTime: ClockTime.fromString(
        storageService.readEveningStartTime(fallback: '19:00'),
      ),
      eveningClasses: storageService.readEveningClasses(fallback: 3),
    );
  }

  DateTime _loadSemesterStartDate(StorageService storageService) {
    final parsed = storageService.readSemesterStartDate();
    return _scheduleCalculator.alignToMonday(parsed ?? DateTime.now());
  }

  Future<void> _refreshForegroundNotification(
    AndroidServiceInstance service,
  ) async {
    await service.setForegroundNotificationInfo(
      title: foregroundServiceTitle,
      content: foregroundServiceContent,
    );
  }

  bool _isSameMinute(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day &&
        left.hour == right.hour &&
        left.minute == right.minute;
  }

  void _resetCourseNotificationDeduplication(String dayKey) {
    if (_notifiedCourseDay == dayKey) {
      return;
    }

    _notifiedCourseIds.clear();
    _notifiedCourseDay = dayKey;
  }

  DateTime _eventNotificationWindowEnd(Event event) {
    return event.dateTime.add(const Duration(minutes: 1));
  }

  void _pruneExpiredEventNotifications(List<Event> events, DateTime now) {
    final activeIds = events
        .where((event) => _eventNotificationWindowEnd(event).isAfter(now))
        .map((event) => event.id)
        .toSet();
    _notifiedEventIds.removeWhere((id) => !activeIds.contains(id));
  }

  Future<void> _handleDeveloperCommand({
    required ServiceInstance service,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      if (service is AndroidServiceInstance) {
        await _refreshForegroundNotification(service);
      }
    } catch (error, stackTrace) {
      developer.log(
        'developer command failed',
        name: 'BackgroundRuntimeService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
