import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/course.dart';
import '../../models/event.dart';
import 'notification_channel_registrar.dart';

class ImmediateReminderNotifier {
  ImmediateReminderNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> showCourseReminder({
    required Course course,
    required int notificationId,
  }) async {
    final courseName = course.name.trim();
    if (courseName.isEmpty) {
      return;
    }

    final location = course.location.trim();
    final teacher = course.teacher.trim();
    final body = <String>[
      if (location.isNotEmpty) '地点：$location',
      if (teacher.isNotEmpty) '教师：$teacher',
      if (location.isEmpty && teacher.isEmpty) '请准备上课',
    ].join(' · ');

    await _plugin.show(
      id: notificationId,
      title: '即将上课：$courseName',
      body: body,
      notificationDetails: _reminderDetails,
      payload: jsonEncode(<String, Object?>{
        'type': 'course',
        'id': course.id,
        'name': courseName,
        'weekday': course.weekday,
        'startPeriod': course.startPeriod,
      }),
    );
  }

  Future<void> showEventReminder({
    required Event event,
    required int notificationId,
  }) async {
    final eventName = event.name.trim();
    if (eventName.isEmpty) {
      return;
    }

    final location = event.location.trim();
    await _plugin.show(
      id: notificationId,
      title: '日程提醒：$eventName',
      body: location.isEmpty ? '即将开始，请注意时间。' : '地点：$location',
      notificationDetails: _reminderDetails,
      payload: jsonEncode(<String, Object?>{
        'type': 'event',
        'id': event.id,
        'name': eventName,
        'dateTime': event.dateTime.toIso8601String(),
      }),
    );
  }

  NotificationDetails get _reminderDetails => const NotificationDetails(
    android: AndroidNotificationDetails(
      NotificationChannelRegistrar.reminderChannelId,
      NotificationChannelRegistrar.reminderChannelName,
      channelDescription:
          NotificationChannelRegistrar.reminderChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
