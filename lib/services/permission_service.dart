import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sound_mode/permission_handler.dart';

class PermissionService {
  static const MethodChannel _permissionsChannel = MethodChannel(
    'app.permissions',
  );

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> ensureNotificationPermission() async {
    try {
      final hasPermission = await _permissionsChannel.invokeMethod<bool>(
        'hasNotificationPermission',
      );
      if (hasPermission == true) {
        return true;
      }
      final granted = await _permissionsChannel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureExactAlarmPermission() async {
    return true;
  }

  Future<bool> hasNotificationPermission() async {
    try {
      final result = await _permissionsChannel.invokeMethod<bool>(
        'hasNotificationPermission',
      );
      return result ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> ensureDndPermission() async {
    if (!_isAndroid) {
      return true;
    }
    final granted = await PermissionHandler.permissionsGranted;
    return granted ?? false;
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
      return;
    }
    await PermissionHandler.openDoNotDisturbSetting();
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!_isAndroid) {
      return;
    }
    await AppSettings.openAppSettings(
      type: AppSettingsType.batteryOptimization,
    );
  }
}
