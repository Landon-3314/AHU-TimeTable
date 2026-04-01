import 'package:flutter/widgets.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';
import 'background_service_manager.dart';
import 'native_alarm_service.dart';
import 'storage_service.dart';

class AppServices {
  const AppServices._();

  static Future<StorageService> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final storageService = await StorageService.create();
    await BackgroundServiceManager.initialize();
    return storageService;
  }

  static Future<void> refreshSchedules({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    final shouldScheduleNativeAlarms =
        settings.autoMuteEnabled ||
        settings.courseReminderEnabled ||
        settings.eventReminderAdvanceMinutes > 0;

    if (shouldScheduleNativeAlarms) {
      await NativeAlarmService.instance.scheduleClasses(
        courses: courses,
        events: events,
        settings: settings,
      );
    } else {
      await NativeAlarmService.instance.cancelAllClasses();
    }

    if (settings.backgroundServiceEnabled) {
      await BackgroundServiceManager.setEnabled(true);
      await BackgroundServiceManager.requestRefresh();
    } else {
      await BackgroundServiceManager.setEnabled(false);
    }
  }
}
