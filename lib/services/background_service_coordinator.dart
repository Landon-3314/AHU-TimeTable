import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'background_runtime_service.dart';
import 'notification_service.dart';

class BackgroundServiceCoordinator {
  BackgroundServiceCoordinator._();

  static final BackgroundServiceCoordinator instance =
      BackgroundServiceCoordinator._();

  bool _configured = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (_configured) {
      return;
    }

    await NotificationService.instance.initialize();

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _backgroundEntryPoint,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: NotificationService.silentBackgroundChannelId,
        initialNotificationTitle:
            BackgroundRuntimeService.foregroundServiceTitle,
        initialNotificationContent:
            BackgroundRuntimeService.foregroundServiceContent,
        foregroundServiceNotificationId:
            BackgroundRuntimeService.foregroundServiceNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _backgroundEntryPoint,
        onBackground: _onIosBackground,
      ),
    );

    _configured = true;
  }

  Future<void> requestSync() async {
    if (!Platform.isAndroid) {
      return;
    }

    await NotificationService.instance.ensurePermissions();
    await initialize();
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
      return;
    }
    service.invoke('sync_now');
  }

  Future<void> stopIfRunning() async {
    if (!Platform.isAndroid) {
      return;
    }

    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      return;
    }
    service.invoke('stop_service');
  }

  @pragma('vm:entry-point')
  static Future<void> _backgroundEntryPoint(ServiceInstance service) async {
    final runtime = BackgroundRuntimeService();
    await runtime.start(service);
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
