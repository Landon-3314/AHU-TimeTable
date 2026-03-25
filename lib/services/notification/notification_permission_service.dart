import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsGranted,
    required this.exactAlarmGranted,
  });

  final bool notificationsGranted;
  final bool exactAlarmGranted;
}

class NotificationPermissionService {
  NotificationPermissionService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<NotificationPermissionStatus> getStatus() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsGranted =
          await androidPlugin?.areNotificationsEnabled() ?? true;
      final exactAlarmGranted =
          await androidPlugin?.canScheduleExactNotifications() ?? true;
      return NotificationPermissionStatus(
        notificationsGranted: notificationsGranted,
        exactAlarmGranted: exactAlarmGranted,
      );
    }

    return const NotificationPermissionStatus(
      notificationsGranted: true,
      exactAlarmGranted: true,
    );
  }

  Future<NotificationPermissionStatus> ensurePermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final notificationsGranted =
          await androidPlugin?.requestNotificationsPermission() ?? true;
      final exactAlarmGranted = await _ensureExactAlarmPermission(
        androidPlugin,
      );

      return NotificationPermissionStatus(
        notificationsGranted: notificationsGranted,
        exactAlarmGranted: exactAlarmGranted,
      );
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final notificationsGranted =
        await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;

    return NotificationPermissionStatus(
      notificationsGranted: notificationsGranted,
      exactAlarmGranted: true,
    );
  }

  Future<bool> _ensureExactAlarmPermission(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    if (androidPlugin == null) {
      return true;
    }

    final canSchedule =
        await androidPlugin.canScheduleExactNotifications() ?? true;
    if (canSchedule) {
      return true;
    }

    return await androidPlugin.requestExactAlarmsPermission() ?? false;
  }
}
