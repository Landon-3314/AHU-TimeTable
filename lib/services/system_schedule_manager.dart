import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';
import 'app_services.dart';
import 'local_notification_service.dart';
import 'native_alarm_service.dart';
import 'persistent_course_reminder_manager.dart';

/// 系统调度管理器 —— 简易门面，供 Provider 层调用
class SystemScheduleManager {
  SystemScheduleManager._();

  static final SystemScheduleManager instance = SystemScheduleManager._();

  Future<void> initialize() async {
    await PersistentCourseReminderManager.initialize();
  }

  Future<void> refreshSchedules({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    await AppServices.refreshSchedules(
      courses: courses,
      events: events,
      settings: settings,
    );
  }

  Future<void> cancelAll() async {
    await LocalNotificationService.instance.cancelManagedNotifications();
    await NativeAlarmService.instance.cancelAllClasses();
    await PersistentCourseReminderManager.setEnabled(false);
  }
}
