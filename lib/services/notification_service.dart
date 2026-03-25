import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel silentBgChannel =
      AndroidNotificationChannel(
    'silent_bg_channel',
    '后台静音服务',
    description: 'Foreground service channel for background worker',
    importance: Importance.min,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  static const AndroidNotificationChannel courseReminderChannel =
      AndroidNotificationChannel(
    'course_reminder_channel',
    '课程提醒',
    description: 'High priority course reminder notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: initializationSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(silentBgChannel);
    await androidPlugin?.createNotificationChannel(courseReminderChannel);

    if (Platform.isAndroid) {
      await androidPlugin?.requestNotificationsPermission();
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  // Legacy API kept for compatibility with existing call sites.
  // Scheduling is now handled by background_service Timer.periodic.
  Future<void> scheduleAllCourseReminders(
    List<Course> courses,
    SettingsProvider settings,
  ) async {
    await initialize();
    print('[NotificationService] scheduleAllCourseReminders skipped: migrated to background_service');
  }

  // Legacy API kept for compatibility.
  Future<void> scheduleEventReminders(
    List<Event> events,
    int advanceMinutes,
  ) async {
    await initialize();
    print('[NotificationService] scheduleEventReminders skipped: migrated to background_service');
  }

  // Legacy API kept for compatibility.
  Future<void> refreshAllReminders({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    await initialize();
    print('[NotificationService] refreshAllReminders skipped: migrated to background_service');
  }
}
