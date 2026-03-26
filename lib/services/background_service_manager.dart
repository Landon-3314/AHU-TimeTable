import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'background_service_coordinator.dart';

class BackgroundServiceManager {
  const BackgroundServiceManager();

  Future<bool> isRunning() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final service = FlutterBackgroundService();
    return service.isRunning();
  }

  Future<void> start() async {
    if (!Platform.isAndroid) {
      return;
    }

    await BackgroundServiceCoordinator.instance.initialize();
    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
      return;
    }
    service.invoke('sync_now');
  }

  Future<void> stop() async {
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

  Future<void> syncIfRunning() async {
    if (!Platform.isAndroid) {
      return;
    }

    final service = FlutterBackgroundService();
    final running = await service.isRunning();
    if (!running) {
      return;
    }
    service.invoke('sync_now');
  }
}

