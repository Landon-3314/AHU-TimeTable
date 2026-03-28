import 'package:flutter/widgets.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';
import 'background_service_manager.dart';
import 'native_alarm_service.dart';
import 'storage_service.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

/// App 服务入口 —— 统一管理初始化和调度刷新
class AppServices {
  const AppServices._();

  /// 初始化所有服务，返回 StorageService 实例
  static Future<StorageService> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final storageService = await StorageService.create();
    await BackgroundServiceManager.initialize();
    return storageService;
  }

  /// 刷新课表调度 —— UI 层数据变动时调用
  static Future<void> refreshSchedules({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    if (settings.backgroundServiceEnabled && settings.autoMuteEnabled) {
      await NativeAlarmService.instance.scheduleClasses(
        courses: courses,
        events: events,
        settings: settings,
      );
      await BackgroundServiceManager.setEnabled(true);
      await BackgroundServiceManager.requestRefresh();
      return;
    }

    await NativeAlarmService.instance.cancelAllClasses();
    await BackgroundServiceManager.setEnabled(false);
    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    } catch (_) {}
  }
}
