import 'dart:io';

import 'package:app_settings/app_settings.dart';

import 'auto_mute_service.dart';
import 'notification_service.dart';

class PermissionService {
  PermissionService({
    NotificationService? notificationService,
    AutoMuteService? autoMuteService,
  }) : _notificationService = notificationService ?? NotificationService.instance,
       _autoMuteService = autoMuteService ?? AutoMuteService.instance;

  final NotificationService _notificationService;
  final AutoMuteService _autoMuteService;

  Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final status = await _notificationService.ensurePermissions();
    return status.notificationsGranted;
  }

  Future<bool> ensureDndPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    var hasPermission = await _autoMuteService.hasPermission();
    if (!hasPermission) {
      await _autoMuteService.openPermissionSettings();
      hasPermission = await _autoMuteService.hasPermission();
    }
    return hasPermission;
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
  }
}

