import 'package:flutter/widgets.dart';

import 'background_service_coordinator.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class AppServices {
  const AppServices._();

  static Future<StorageService> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final storageService = await StorageService.create();
    await NotificationService.instance.initialize();
    await BackgroundServiceCoordinator.instance.initialize();
    return storageService;
  }
}
