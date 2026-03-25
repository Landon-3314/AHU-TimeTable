import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannelRegistrar {
  NotificationChannelRegistrar(this._plugin);

  static const String silentBackgroundChannelId = 'silent_bg_channel';
  static const String silentBackgroundChannelName = '后台静音服务';
  static const String silentBackgroundChannelDescription =
      'Foreground service channel for background worker';

  static const String reminderChannelId = 'course_reminder_channel';
  static const String reminderChannelName = '课程与日程提醒';
  static const String reminderChannelDescription =
      'High priority reminder notifications for courses and events';

  static const AndroidNotificationChannel silentBackgroundChannel =
      AndroidNotificationChannel(
        silentBackgroundChannelId,
        silentBackgroundChannelName,
        description: silentBackgroundChannelDescription,
        importance: Importance.min,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

  static const AndroidNotificationChannel reminderChannel =
      AndroidNotificationChannel(
        reminderChannelId,
        reminderChannelName,
        description: reminderChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> registerChannels() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(silentBackgroundChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
  }
}
