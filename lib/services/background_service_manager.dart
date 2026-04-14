import 'native_alarm_service.dart';

class BackgroundServiceManager {
  BackgroundServiceManager._();

  static Future<void> initialize() async {}

  static Future<void> setEnabled(bool enabled) async {
    await NativeAlarmService.instance.setForegroundServiceEnabled(enabled);
  }

  static Future<void> requestRefresh() async {
    await NativeAlarmService.instance.refreshForegroundService();
  }
}
