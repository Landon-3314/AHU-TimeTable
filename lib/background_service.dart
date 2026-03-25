import 'services/background_service_coordinator.dart';

Future<void> initializeBackgroundServices() async {
  await BackgroundServiceCoordinator.instance.initialize();
}

Future<void> requestBackgroundServiceSync() async {
  await BackgroundServiceCoordinator.instance.requestSync();
}

Future<void> stopBackgroundServiceIfRunning() async {
  await BackgroundServiceCoordinator.instance.stopIfRunning();
}
