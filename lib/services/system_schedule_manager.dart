import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';
import 'background_service_manager.dart';

/// 系统调度管理器 —— 简易门面，供 Provider 层调用
class SystemScheduleManager {
  SystemScheduleManager._();

  static final SystemScheduleManager instance = SystemScheduleManager._();

  Future<void> initialize() async {
    await BackgroundServiceManager.initialize();
  }

  Future<void> refreshSchedules({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    // The new architecture fully delegates execution to background service.
    // Keep parameters for compatibility with existing caller signatures.
    if (settings.backgroundServiceEnabled && settings.autoMuteEnabled) {
      await BackgroundServiceManager.setEnabled(true);
      await BackgroundServiceManager.requestRefresh();
      return;
    }

    await BackgroundServiceManager.setEnabled(false);
  }

  Future<void> cancelAll() async {
    await BackgroundServiceManager.setEnabled(false);
  }
}
