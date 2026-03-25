import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';

class NotificationService {
  NotificationService._({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

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

  factory NotificationService.backgroundWorker() => NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  Future<void> initialize() async {
    await _initialize(requestPermissions: true);
  }

  Future<void> initializeForBackgroundIsolate() async {
    await _initialize(requestPermissions: false);
  }

  Future<void> ensurePermissions() async {
    await initialize();
    await _requestPlatformPermissions();
  }

  Future<void> showCourseReminder({
    required Course course,
    required int notificationId,
  }) async {
    await initializeForBackgroundIsolate();

    final courseName = course.name.trim();
    if (courseName.isEmpty) {
      return;
    }

    final location = course.location.trim();
    await _plugin.show(
      id: notificationId,
      title: '即将上课：$courseName',
      body: location.isEmpty ? '请准备上课' : '地点：$location',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          courseReminderChannelId,
          courseReminderChannelName,
          channelDescription: courseReminderChannelDescription,
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
  }

  static const String courseReminderChannelId = 'course_reminder_channel';
  static const String courseReminderChannelName = '课程提醒';
  static const String courseReminderChannelDescription =
      'High priority course reminder notifications';

  Future<void> _initialize({required bool requestPermissions}) async {
    if (_initialized) {
      if (requestPermissions) {
        await _requestPlatformPermissions();
      }
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

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(silentBgChannel);
    await androidPlugin?.createNotificationChannel(courseReminderChannel);

    _initialized = true;
    if (requestPermissions) {
      await _requestPlatformPermissions();
    }
  }

  Future<void> _requestPlatformPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // Legacy API kept for compatibility with existing call sites.
  // Scheduling is now handled by background_service Timer.periodic.
  Future<void> scheduleAllCourseReminders(
    List<Course> courses,
    SettingsProvider settings,
  ) async {
    await initialize();
    developer.log(
      'scheduleAllCourseReminders skipped: delegated to background service runtime',
      name: 'NotificationService',
    );
  }

  // Legacy API kept for compatibility.
  Future<void> scheduleEventReminders(
    List<Event> events,
    int advanceMinutes,
  ) async {
    await initialize();
    developer.log(
      'scheduleEventReminders skipped: event reminder pipeline is not active',
      name: 'NotificationService',
    );
  }

  // Legacy API kept for compatibility.
  Future<void> refreshAllReminders({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    await initialize();
    developer.log(
      'refreshAllReminders delegated to background service coordinator',
      name: 'NotificationService',
    );
  }
}
