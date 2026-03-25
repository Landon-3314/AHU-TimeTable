import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';
import 'notification/immediate_reminder_notifier.dart';
import 'notification/notification_channel_registrar.dart';
import 'notification/notification_permission_service.dart';

class NotificationService {
  NotificationService._({FlutterLocalNotificationsPlugin? plugin})
    : this._withPlugin(plugin ?? FlutterLocalNotificationsPlugin());

  NotificationService._withPlugin(FlutterLocalNotificationsPlugin plugin)
    : _plugin = plugin,
      _channelRegistrar = NotificationChannelRegistrar(plugin),
      _permissionService = NotificationPermissionService(plugin),
      _immediateNotifier = ImmediateReminderNotifier(plugin);

  static final NotificationService instance = NotificationService._();

  factory NotificationService.backgroundWorker() => NotificationService._();

  static String get silentBackgroundChannelId =>
      NotificationChannelRegistrar.silentBackgroundChannelId;

  static String get reminderChannelId =>
      NotificationChannelRegistrar.reminderChannelId;

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationChannelRegistrar _channelRegistrar;
  final NotificationPermissionService _permissionService;
  final ImmediateReminderNotifier _immediateNotifier;

  bool _initialized = false;

  Future<void> initialize() async {
    await _initialize();
  }

  Future<void> initializeForBackgroundIsolate() async {
    await _initialize();
  }

  Future<NotificationPermissionStatus> ensurePermissions() async {
    await _initialize();
    return _permissionService.ensurePermissions();
  }

  Future<NotificationPermissionStatus> getPermissionStatus() async {
    await _initialize();
    return _permissionService.getStatus();
  }

  Future<void> showCourseReminder({
    required Course course,
    required int notificationId,
  }) async {
    await initializeForBackgroundIsolate();
    await _immediateNotifier.showCourseReminder(
      course: course,
      notificationId: notificationId,
    );
  }

  Future<void> showEventReminder({
    required Event event,
    required int notificationId,
  }) async {
    await initializeForBackgroundIsolate();
    await _immediateNotifier.showEventReminder(
      event: event,
      notificationId: notificationId,
    );
  }

  Future<void> _initialize() async {
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
    await _channelRegistrar.registerChannels();
    _initialized = true;
  }

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

  Future<void> scheduleEventReminders(
    List<Event> events,
    int advanceMinutes,
  ) async {
    await initialize();
    developer.log(
      'scheduleEventReminders skipped: delegated to background service runtime',
      name: 'NotificationService',
    );
  }

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
