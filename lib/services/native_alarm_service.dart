import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'schedule_plan.dart';

class NativeMuteTestResult {
  const NativeMuteTestResult({required this.success, this.reason});

  const NativeMuteTestResult.failure(String reason)
    : this(success: false, reason: reason);

  final bool success;
  final String? reason;

  factory NativeMuteTestResult.fromPlatform(Object? value) {
    if (value is! Map) {
      return const NativeMuteTestResult.failure('invalid_native_response');
    }
    final success = value['success'];
    final reason = value['reason'];
    if (success is! bool || (reason != null && reason is! String)) {
      return const NativeMuteTestResult.failure('invalid_native_response');
    }
    return NativeMuteTestResult(success: success, reason: reason as String?);
  }

  String get failureMessage {
    return switch (reason) {
      'silent_alarm_schedule_failed' => '静音闹钟写入失败，请查看控制台 MuteDiag 日志',
      'restore_alarm_schedule_failed' => '恢复闹钟写入失败，请查看控制台 MuteDiag 日志',
      _ => '诊断静音闹钟写入失败，请查看控制台 MuteDiag 日志',
    };
  }
}

class NativeAlarmService {
  NativeAlarmService._();

  static final NativeAlarmService instance = NativeAlarmService._();
  static const String _logTag = '[NotificationDiag]';
  static const MethodChannel _channel = MethodChannel(
    'com.timetable/native_alarm',
  );
  static const String _actionRemindClass = 'com.timetable.ACTION_REMIND_CLASS';
  static const String _actionRemindSchedule =
      'com.timetable.ACTION_REMIND_SCHEDULE';

  bool get _supportsNativeAlarmChannel =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _supportsAndroidAlarmControls =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> ensureExactAlarmPermission() async {
    if (!_supportsAndroidAlarmControls) {
      return true;
    }

    try {
      final hasPermission =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      if (hasPermission) {
        return true;
      }
      await _channel.invokeMethod<void>('requestExactAlarmPermission');
      final recheck =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;
      return recheck;
    } catch (e) {
      debugPrint('[NativeAlarm] ensureExactAlarmPermission failed: $e');
      return false;
    }
  }

  Future<bool> hasExactAlarmPermission() async {
    if (!_supportsAndroidAlarmControls) {
      _log('hasExactAlarmPermission skipped: non-Android -> true');
      return true;
    }

    try {
      final result =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? true;
      _log('hasExactAlarmPermission result=$result');
      return result;
    } catch (e) {
      debugPrint('[NativeAlarm] hasExactAlarmPermission failed: $e');
      return false;
    }
  }

  Future<bool> ensureIgnoreBatteryOptimizations() async {
    if (!_supportsAndroidAlarmControls) {
      return true;
    }

    try {
      final ignoring =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
      if (ignoring) {
        return true;
      }
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
      final recheck =
          await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
      return recheck;
    } catch (e) {
      debugPrint('[NativeAlarm] ensureIgnoreBatteryOptimizations failed: $e');
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    if (!_supportsAndroidAlarmControls) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[NativeAlarm] requestIgnoreBatteryOptimization failed: $e');
    }
  }

  Future<void> setForegroundServiceEnabled(bool enabled) async {
    if (!_supportsAndroidAlarmControls) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('setForegroundServiceEnabled', {
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('[NativeAlarm] setForegroundServiceEnabled failed: $e');
    }
  }

  Future<void> refreshForegroundService() async {
    if (!_supportsAndroidAlarmControls) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('refreshForegroundService');
    } catch (e) {
      debugPrint('[NativeAlarm] refreshForegroundService failed: $e');
    }
  }

  Future<bool> openRomPermissionSettings() async {
    if (!_supportsAndroidAlarmControls) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('openRomPermissionSettings') ??
          false;
    } catch (e) {
      debugPrint('[NativeAlarm] openRomPermissionSettings failed: $e');
      return false;
    }
  }

  Future<NativeMuteTestResult> runOneMinuteMuteTest() async {
    if (!_supportsAndroidAlarmControls) {
      return const NativeMuteTestResult.failure('unsupported_platform');
    }

    try {
      return NativeMuteTestResult.fromPlatform(
        await _channel.invokeMethod<Object?>('runOneMinuteMuteTest'),
      );
    } catch (e) {
      debugPrint('[NativeAlarm] runOneMinuteMuteTest failed: $e');
      return const NativeMuteTestResult.failure('platform_exception');
    }
  }

  Future<NativeMuteTestResult> runTimedMuteTest({
    required int muteAfterSeconds,
    required int restoreAfterSeconds,
  }) async {
    if (!_supportsAndroidAlarmControls) {
      _log('runTimedMuteTest skipped: non-Android');
      return const NativeMuteTestResult.failure('unsupported_platform');
    }

    try {
      _log(
        'runTimedMuteTest start muteAfterSeconds=$muteAfterSeconds '
        'restoreAfterSeconds=$restoreAfterSeconds',
      );
      final result = NativeMuteTestResult.fromPlatform(
        await _channel.invokeMethod<Object?>('runTimedMuteTest', {
          'muteAfterSeconds': muteAfterSeconds,
          'restoreAfterSeconds': restoreAfterSeconds,
        }),
      );
      _log(
        'runTimedMuteTest result success=${result.success} '
        'reason=${result.reason}',
      );
      return result;
    } catch (e) {
      debugPrint('[NativeAlarm] runTimedMuteTest failed: $e');
      _log('runTimedMuteTest failed error=$e');
      return const NativeMuteTestResult.failure('platform_exception');
    }
  }

  Future<bool> cancelTimedMuteTest() async {
    if (!_supportsAndroidAlarmControls) {
      _log('cancelTimedMuteTest skipped: non-Android');
      return false;
    }

    try {
      _log('cancelTimedMuteTest start');
      await _channel.invokeMethod<void>('cancelTimedMuteTest');
      _log('cancelTimedMuteTest success');
      return true;
    } catch (e) {
      debugPrint('[NativeAlarm] cancelTimedMuteTest failed: $e');
      _log('cancelTimedMuteTest failed error=$e');
      return false;
    }
  }

  Future<void> scheduleSystemPlan(
    SchedulePlan plan, {
    bool includeCourseStatusWindows = false,
  }) async {
    if (!_supportsAndroidAlarmControls) {
      return;
    }

    try {
      final classItems = [
        ...plan.notifications.map(_notificationToJson),
        ...plan.courseAutomationWindows.map(_automationWindowToJson),
        if (includeCourseStatusWindows)
          ...plan.courseStatusWindows.map(_courseStatusWindowToJson),
      ];
      await _channel.invokeMethod<void>('scheduleAllClasses', {
        'classes': classItems,
        'todayCourses': plan.todayCourses.map(_todayCourseToJson).toList(),
      });
    } catch (e) {
      debugPrint('[NativeAlarm] scheduleMuteWindows failed: $e');
    }
  }

  Future<void> scheduleMuteWindows(
    SchedulePlan plan, {
    bool includeCourseStatusWindows = false,
  }) {
    return scheduleSystemPlan(
      plan,
      includeCourseStatusWindows: includeCourseStatusWindows,
    );
  }

  Future<void> reconcileMuteState({bool restoreActiveAppMute = false}) async {
    if (!_supportsAndroidAlarmControls) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('reconcileMuteState', {
        'restoreActiveAppMute': restoreActiveAppMute,
      });
    } catch (e) {
      debugPrint('[NativeAlarm] reconcileMuteState failed: $e');
    }
  }

  Future<void> cancelAllClasses() async {
    if (!_supportsNativeAlarmChannel) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('cancelAllClasses');
    } catch (e) {
      debugPrint('[NativeAlarm] cancelAllClasses failed: $e');
    }
  }

  Map<String, dynamic> _notificationToJson(ManagedNotification notification) {
    final reminderAction =
        notification.kind == ManagedNotificationKind.eventReminder
        ? _actionRemindSchedule
        : _actionRemindClass;
    return {
      'courseIndex': notification.id,
      'scheduleType': notification.kind.name,
      'reminderAtMillis': notification.scheduledAt.millisecondsSinceEpoch,
      'title': notification.title,
      'content': notification.body,
      'notificationId': notification.id,
      'reminderAction': reminderAction,
    };
  }

  Map<String, dynamic> _automationWindowToJson(AutoMuteWindow window) {
    return {
      'courseIndex': window.id,
      'scheduleType': 'course',
      'courseName': window.courseName,
      'location': window.location,
      'windowStartAtMillis': window.startAt.millisecondsSinceEpoch,
      'windowEndAtMillis': window.endAt.millisecondsSinceEpoch,
      if (window.shouldScheduleSilent)
        'silentAtMillis': window.startAt.millisecondsSinceEpoch,
      'restoreAtMillis': window.endAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _courseStatusWindowToJson(CourseStatusWindow window) {
    return {
      'courseIndex': window.id,
      'scheduleType': 'course',
      'courseName': window.courseName,
      'location': window.location,
      'windowStartAtMillis': window.startAt.millisecondsSinceEpoch,
      'windowEndAtMillis': window.endAt.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> _todayCourseToJson(TodayCourseSnapshot course) {
    return {
      'courseName': course.courseName,
      'location': course.location,
      'startAtMillis': course.startAt.millisecondsSinceEpoch,
      'endAtMillis': course.endAt.millisecondsSinceEpoch,
    };
  }

  static void _log(String message) {
    debugPrint('$_logTag ${DateTime.now().toIso8601String()} $message');
  }
}
