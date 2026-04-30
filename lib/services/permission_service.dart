import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sound_mode/permission_handler.dart';

import 'native_alarm_service.dart';

class PermissionService {
  static const MethodChannel _permissionsChannel = MethodChannel(
    'app.permissions',
  );
  static const String _logTag = '[NotificationDiag]';

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> ensureNotificationPermission() async {
    try {
      _log('ensureNotificationPermission start');
      final hasPermission = await _permissionsChannel.invokeMethod<bool>(
        'hasNotificationPermission',
      );
      _log('ensureNotificationPermission current=$hasPermission');
      if (hasPermission == true) {
        return true;
      }
      final granted = await _permissionsChannel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      _log('ensureNotificationPermission requestResult=$granted');
      return granted ?? false;
    } on MissingPluginException {
      _log('ensureNotificationPermission MissingPluginException -> true');
      return true;
    } catch (e) {
      _log('ensureNotificationPermission failed error=$e');
      return false;
    }
  }

  Future<bool> ensureExactAlarmPermission() async {
    return NativeAlarmService.instance.ensureExactAlarmPermission();
  }

  Future<bool> hasExactAlarmPermission() async {
    return NativeAlarmService.instance.hasExactAlarmPermission();
  }

  Future<bool> hasNotificationPermission() async {
    try {
      _log('hasNotificationPermission start');
      final result = await _permissionsChannel.invokeMethod<bool>(
        'hasNotificationPermission',
      );
      _log('hasNotificationPermission result=$result');
      return result ?? false;
    } on MissingPluginException {
      _log('hasNotificationPermission MissingPluginException -> true');
      return true;
    } catch (e) {
      _log('hasNotificationPermission failed error=$e');
      return false;
    }
  }

  Future<Map<String, Object?>> notificationDiagnostics() async {
    try {
      _log('notificationDiagnostics start');
      final result = await _permissionsChannel.invokeMapMethod<String, Object?>(
        'notificationDiagnostics',
      );
      final diagnostics = result ?? <String, Object?>{};
      _log('notificationDiagnostics result=$diagnostics');
      return diagnostics;
    } on MissingPluginException {
      final fallback = <String, Object?>{
        'missingPlugin': true,
        'platform': defaultTargetPlatform.name,
      };
      _log('notificationDiagnostics MissingPluginException result=$fallback');
      return fallback;
    } catch (e) {
      final fallback = <String, Object?>{
        'error': e.toString(),
        'platform': defaultTargetPlatform.name,
      };
      _log('notificationDiagnostics failed result=$fallback');
      return fallback;
    }
  }

  Future<bool> ensureDndPermission() async {
    if (!_isAndroid) {
      _log('ensureDndPermission skipped: non-Android -> true');
      return true;
    }
    try {
      final granted = await PermissionHandler.permissionsGranted;
      _log('ensureDndPermission result=$granted');
      return granted ?? false;
    } catch (e) {
      _log('ensureDndPermission failed error=$e');
      return false;
    }
  }

  Future<bool> hasDndPermission() async {
    if (!_isAndroid) {
      _log('hasDndPermission skipped: non-Android -> true');
      return true;
    }
    try {
      final granted = await PermissionHandler.permissionsGranted;
      _log('hasDndPermission result=$granted');
      return granted ?? false;
    } catch (e) {
      _log('hasDndPermission failed error=$e');
      return false;
    }
  }

  Future<bool> ensureSoundModePermission() async {
    return ensureDndPermission();
  }

  Future<void> openAppOrAlarmSettings() async {
    if (!_isAndroid) {
      return;
    }
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  Future<void> openSystemDndSettings() async {
    if (!_isAndroid) {
      _log('openSystemDndSettings skipped: non-Android');
      return;
    }
    _log('openSystemDndSettings start');
    await PermissionHandler.openDoNotDisturbSetting();
    _log('openSystemDndSettings invoked');
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!_isAndroid) {
      return;
    }
    await AppSettings.openAppSettings(
      type: AppSettingsType.batteryOptimization,
    );
  }

  static void _log(String message) {
    debugPrint('$_logTag ${DateTime.now().toIso8601String()} $message');
  }
}
