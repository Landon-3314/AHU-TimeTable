import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

const String _coursesKey = 'courses.items';
const String _autoMuteEnabledKey = 'settings.autoMuteEnabled';
const String _semesterStartDateKey = 'settings.semesterStartDate';
const String _totalWeeksKey = 'settings.totalWeeks';
const String _reminderAdvanceMinutesKey = 'settings.reminderAdvanceMinutes';

const String _classDurationKey = 'settings.classDuration';
const String _shortBreakKey = 'settings.shortBreak';
const String _bigBreakKey = 'settings.bigBreak';
const String _morningStartTimeKey = 'settings.morningStartTime';
const String _morningClassesKey = 'settings.morningClasses';
const String _afternoonStartTimeKey = 'settings.afternoonStartTime';
const String _afternoonClassesKey = 'settings.afternoonClasses';
const String _eveningStartTimeKey = 'settings.eveningStartTime';
const String _eveningClassesKey = 'settings.eveningClasses';

bool _serviceConfigured = false;

const AndroidNotificationChannel _silentBgChannel = AndroidNotificationChannel(
  'silent_bg_channel',
  'Silent Background Service',
  description: 'Low visibility foreground channel for auto-mute service',
  importance: Importance.min,
  playSound: false,
);

const AndroidNotificationChannel _courseReminderChannel =
    AndroidNotificationChannel(
  'course_reminder_channel',
  'Course Reminder Channel',
  description: 'High priority course reminder notifications',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

Future<void> initBackgroundService() async {
  await _ensureBackgroundServiceConfigured();
}

Future<void> _ensureBackgroundServiceConfigured() async {
  if (!Platform.isAndroid) {
    return;
  }
  if (_serviceConfigured) {
    return;
  }

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  final androidNotifications = notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidNotifications?.createNotificationChannel(_silentBgChannel);
  await androidNotifications?.createNotificationChannel(_courseReminderChannel);

  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: false,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: _silentBgChannel.id,
      initialNotificationTitle: '',
      initialNotificationContent: '',
      foregroundServiceNotificationId: 9527,
      foregroundServiceTypes: [AndroidForegroundType.specialUse],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onServiceStart,
      onBackground: _onIosBackground,
    ),
  );

  _serviceConfigured = true;
}

Future<void> requestBackgroundServiceSync() async {
  if (!Platform.isAndroid) {
    return;
  }

  await _ensureBackgroundServiceConfigured();
  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    await service.startService();
    return;
  }
  service.invoke('sync_now');
}

Future<void> stopBackgroundServiceIfRunning() async {
  if (!Platform.isAndroid) {
    return;
  }

  final service = FlutterBackgroundService();
  final running = await service.isRunning();
  if (!running) {
    return;
  }
  service.invoke('stop_service');
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  Timer? timer;
  String? lastAppliedMode;
  final notifiedCourseIds = <String>{};
  String? notifiedDay;
  final localNotifications = FlutterLocalNotificationsPlugin();
  unawaited(
    localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    ),
  );

  Future<void> applyMode(String mode) async {
    if (mode == lastAppliedMode) {
      return;
    }

    final granted = await PermissionHandler.permissionsGranted ?? false;
    if (!granted) {
      print('[BackgroundService] DND permission is not granted.');
      return;
    }

    final target = mode == 'vibrate'
        ? RingerModeStatus.vibrate
        : RingerModeStatus.normal;
    await SoundMode.setSoundMode(target);
    lastAppliedMode = mode;

    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: '',
        content: '',
      );
    }
  }

  Future<void> runScheduleTick() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final mode = _computeTargetModeFromPrefs(prefs);
      if (mode == null) {
        return;
      }
      await applyMode(mode);
      await _runCourseReminderTick(
        prefs: prefs,
        localNotifications: localNotifications,
        notifiedCourseIds: notifiedCourseIds,
        notifiedDay: notifiedDay,
        onDayChanged: (newDay) {
          notifiedDay = newDay;
        },
      );
    } catch (error, stackTrace) {
      print('[BackgroundService] runScheduleTick error: $error');
      print(stackTrace);
    }
  }

  service.on('test_mute').listen((_) async {
    try {
      await applyMode('vibrate');
    } catch (error, stackTrace) {
      print('[BackgroundService] test_mute error: $error');
      print(stackTrace);
    }
  });

  service.on('test_unmute').listen((_) async {
    try {
      await applyMode('normal');
    } catch (error, stackTrace) {
      print('[BackgroundService] test_unmute error: $error');
      print(stackTrace);
    }
  });

  service.on('sync_now').listen((_) async {
    await runScheduleTick();
  });

  service.on('stop_service').listen((_) {
    timer?.cancel();
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  timer = Timer.periodic(const Duration(minutes: 1), (_) async {
    await runScheduleTick();
  });

  unawaited(runScheduleTick());
}

String? _computeTargetModeFromPrefs(SharedPreferences prefs) {
  final autoMuteEnabled = prefs.getBool(_autoMuteEnabledKey) ?? false;
  if (!autoMuteEnabled) {
    return 'normal';
  }

  final now = DateTime.now();
  final totalWeeks = (prefs.getInt(_totalWeeksKey) ?? 20).clamp(1, 30);
  final semesterStartDate = _loadSemesterStartDate(prefs);
  final currentWeek = _computeCurrentWeek(
    semesterStartDate: semesterStartDate,
    totalWeeks: totalWeeks,
    now: now,
  );
  final currentWeekday = now.weekday.clamp(1, 7);

  final slots = _generateTimeSlots(prefs);
  final rawCourses = prefs.getStringList(_coursesKey) ?? <String>[];
  final courses = rawCourses
      .map((raw) {
        try {
          return jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          return <String, dynamic>{};
        }
      })
      .where((course) => course.isNotEmpty)
      .toList();

  var inClass = false;
  for (final course in courses) {
    final weekday = (course['weekday'] as num?)?.toInt();
    if (weekday != currentWeekday) {
      continue;
    }

    final weeks = _parseWeeks(course['weeks']);
    if (!weeks.contains(currentWeek)) {
      continue;
    }

    final startPeriod = (course['startPeriod'] as num?)?.toInt() ?? 0;
    final endPeriod = (course['endPeriod'] as num?)?.toInt() ?? 0;
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
      startSlot.startHour,
      startSlot.startMinute,
    );
    final end = DateTime(
      now.year,
      now.month,
      now.day,
      endSlot.endHour,
      endSlot.endMinute,
    );

    if (!now.isBefore(start) && now.isBefore(end)) {
      inClass = true;
      break;
    }
  }

  return inClass ? 'vibrate' : 'normal';
}

DateTime _loadSemesterStartDate(SharedPreferences prefs) {
  final raw = prefs.getString(_semesterStartDateKey);
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  final date = parsed ?? DateTime.now();
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

int _computeCurrentWeek({
  required DateTime semesterStartDate,
  required int totalWeeks,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final diffDays = today.difference(semesterStartDate).inDays;
  final week = (diffDays ~/ 7) + 1;
  return week.clamp(1, totalWeeks).toInt();
}

List<int> _parseWeeks(Object? raw) {
  if (raw is! List) {
    return const <int>[];
  }

  return raw
      .map((item) {
        if (item is int) {
          return item;
        }
        if (item is num) {
          return item.toInt();
        }
        return int.tryParse(item.toString());
      })
      .whereType<int>()
      .toList();
}

List<_TimeSlot> _generateTimeSlots(SharedPreferences prefs) {
  final classDuration = prefs.getInt(_classDurationKey) ?? 45;
  final shortBreak = prefs.getInt(_shortBreakKey) ?? 5;
  final bigBreak = prefs.getInt(_bigBreakKey) ?? 15;
  final morningStart = prefs.getString(_morningStartTimeKey) ?? '08:00';
  final morningClasses = prefs.getInt(_morningClassesKey) ?? 5;
  final afternoonStart = prefs.getString(_afternoonStartTimeKey) ?? '14:00';
  final afternoonClasses = prefs.getInt(_afternoonClassesKey) ?? 5;
  final eveningStart = prefs.getString(_eveningStartTimeKey) ?? '19:00';
  final eveningClasses = prefs.getInt(_eveningClassesKey) ?? 3;

  final slots = <_TimeSlot>[];
  _appendSessionSlots(
    slots: slots,
    startTime: morningStart,
    count: morningClasses,
    classDuration: classDuration,
    shortBreak: shortBreak,
    bigBreak: bigBreak,
    hasBigBreak: true,
  );
  _appendSessionSlots(
    slots: slots,
    startTime: afternoonStart,
    count: afternoonClasses,
    classDuration: classDuration,
    shortBreak: shortBreak,
    bigBreak: bigBreak,
    hasBigBreak: true,
  );
  _appendSessionSlots(
    slots: slots,
    startTime: eveningStart,
    count: eveningClasses,
    classDuration: classDuration,
    shortBreak: shortBreak,
    bigBreak: bigBreak,
    hasBigBreak: false,
  );

  return slots;
}

void _appendSessionSlots({
  required List<_TimeSlot> slots,
  required String startTime,
  required int count,
  required int classDuration,
  required int shortBreak,
  required int bigBreak,
  required bool hasBigBreak,
}) {
  final parts = startTime.split(':');
  final startHour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final startMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

  var currentMinutes = startHour * 60 + startMinute;
  for (var i = 1; i <= count; i += 1) {
    final classStart = currentMinutes;
    final classEnd = classStart + classDuration;
    slots.add(
      _TimeSlot(
        startHour: classStart ~/ 60,
        startMinute: classStart % 60,
        endHour: classEnd ~/ 60,
        endMinute: classEnd % 60,
      ),
    );

    currentMinutes = classEnd;
    if (i == count) {
      continue;
    }
    currentMinutes += hasBigBreak && i == 2 ? bigBreak : shortBreak;
  }
}

class _TimeSlot {
  const _TimeSlot({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
}

Future<void> _runCourseReminderTick({
  required SharedPreferences prefs,
  required FlutterLocalNotificationsPlugin localNotifications,
  required Set<String> notifiedCourseIds,
  required String? notifiedDay,
  required void Function(String dayKey) onDayChanged,
}) async {
  final advanceMinutes = (prefs.getInt(_reminderAdvanceMinutesKey) ?? 0)
      .clamp(0, 60)
      .toInt();
  if (advanceMinutes <= 0) {
    return;
  }

  final now = DateTime.now();
  final dayKey = '${now.year}-${now.month}-${now.day}';
  if (notifiedDay != dayKey) {
    notifiedCourseIds.clear();
    onDayChanged(dayKey);
  }

  final totalWeeks = (prefs.getInt(_totalWeeksKey) ?? 20).clamp(1, 30);
  final semesterStartDate = _loadSemesterStartDate(prefs);
  final currentWeek = _computeCurrentWeek(
    semesterStartDate: semesterStartDate,
    totalWeeks: totalWeeks,
    now: now,
  );
  final currentWeekday = now.weekday.clamp(1, 7);
  final slots = _generateTimeSlots(prefs);
  final rawCourses = prefs.getStringList(_coursesKey) ?? <String>[];

  for (final raw in rawCourses) {
    Map<String, dynamic> course;
    try {
      course = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      continue;
    }

    final weekday = (course['weekday'] as num?)?.toInt();
    if (weekday != currentWeekday) {
      continue;
    }

    final weeks = _parseWeeks(course['weeks']);
    if (!weeks.contains(currentWeek)) {
      continue;
    }

    final startPeriod = (course['startPeriod'] as num?)?.toInt() ?? 0;
    if (startPeriod <= 0 || startPeriod > slots.length) {
      continue;
    }

    final slot = slots[startPeriod - 1];
    final classStart = DateTime(
      now.year,
      now.month,
      now.day,
      slot.startHour,
      slot.startMinute,
    );
    final reminderTime = classStart.subtract(Duration(minutes: advanceMinutes));
    if (!_isSameMinute(now, reminderTime)) {
      continue;
    }

    final name = (course['name'] as String?)?.trim();
    if (name == null || name.isEmpty) {
      continue;
    }
    final location = (course['location'] as String?)?.trim() ?? '';

    final dedupeId = '$dayKey-$currentWeek-$name-$startPeriod';
    if (notifiedCourseIds.contains(dedupeId)) {
      continue;
    }

    await localNotifications.show(
      id: dedupeId.hashCode & 0x7fffffff,
      title: '即将上课：$name',
      body: location.isEmpty ? '请准备上课' : '地点：$location',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'course_reminder_channel',
          'Course Reminder Channel',
          channelDescription: 'High priority course reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    notifiedCourseIds.add(dedupeId);
  }
}

bool _isSameMinute(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day &&
      left.hour == right.hour &&
      left.minute == right.minute;
}
