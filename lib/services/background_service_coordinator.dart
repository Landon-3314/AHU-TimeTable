import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/widgets.dart';

import 'background_runtime_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      ui.DartPluginRegistrant.ensureInitialized();

      final runtime = BackgroundRuntimeService();
      await runtime.start(service);
    },
    (error, stack) {
      debugPrint('Background Error: $error');
    },
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

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
        onStart: onServiceStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: 'silent_bg_channel',
        initialNotificationTitle: '课程表守护服务',
        initialNotificationContent: '正在后台保障自动静音与课前提醒',
        foregroundServiceNotificationId:
            BackgroundRuntimeService.foregroundServiceNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.specialUse],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onServiceStart,
        onBackground: onIosBackground,
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
}
