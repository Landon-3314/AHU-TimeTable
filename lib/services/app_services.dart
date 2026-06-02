import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/settings_provider.dart';
import 'local_notification_service.dart';
import 'native_alarm_service.dart';
import 'permission_service.dart';
import 'persistent_course_reminder_manager.dart';
import 'schedule_plan.dart';
import 'storage_service.dart';

class AppServices {
  const AppServices._();

  static const String _logTag = '[NotificationDiag]';

  static Future<StorageService> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    final storageService = await StorageService.create();
    await LocalNotificationService.instance.initialize();
    await PersistentCourseReminderManager.initialize();
    return storageService;
  }

  static Future<void> refreshSchedules({
    required List<Course> courses,
    required List<Event> events,
    required SettingsProvider settings,
  }) async {
    _log(
      'refreshSchedules start courses=${courses.length} events=${events.length} '
      'semesterInitialized=${settings.isCurrentSemesterInitialized}',
    );
    if (!settings.isCurrentSemesterInitialized) {
      _log('refreshSchedules semester not initialized: cancel all schedules');
      await LocalNotificationService.instance.cancelManagedNotifications();
      await NativeAlarmService.instance.cancelAllClasses();
      await PersistentCourseReminderManager.setEnabled(false);
      return;
    }

    final permissionService = PermissionService();
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final hasExactAlarmPermission = await NativeAlarmService.instance
        .hasExactAlarmPermission();
    final hasDndPermission = await permissionService.hasDndPermission();
    final canAutoMute =
        isAndroid &&
        settings.autoMuteEnabled &&
        hasExactAlarmPermission &&
        hasDndPermission;
    final retainAutoMuteWindows = isAndroid && settings.autoMuteEnabled;
    final maxNotificationCount =
        defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS
        ? 60
        : null;
    _log(
      'refreshSchedules permissions exact=$hasExactAlarmPermission '
      'dnd=$hasDndPermission autoMuteEnabled=${settings.autoMuteEnabled} '
      'canAutoMute=$canAutoMute '
      'courseReminderStyle=${settings.courseReminderStyle.name} '
      'maxNotificationCount=$maxNotificationCount',
    );
    final courseReminderAdvanceMinutes =
        settings.courseReminderStyle == CourseReminderStyle.singleNotification
        ? settings.reminderAdvanceMinutes
        : 0;

    final plan = SchedulePlanBuilder.build(
      courses: courses,
      events: events,
      timeSlots: settings.timeSlots,
      semesterStartDate: settings.semesterStartDate,
      totalWeeks: settings.totalWeeks,
      courseReminderAdvanceMinutes: courseReminderAdvanceMinutes,
      eventReminderAdvanceMinutes: settings.eventReminderAdvanceMinutes,
      autoMuteEnabled: settings.autoMuteEnabled,
      canAutoMute: canAutoMute,
      retainAutoMuteWindows: retainAutoMuteWindows,
      nativeMuteFallbackEnabled: retainAutoMuteWindows,
      horizonDays: isAndroid
          ? SchedulePlanBuilder.semesterCoverageDays(settings.totalWeeks)
          : 14,
      maxNotificationCount: maxNotificationCount,
    );
    _log(
      'refreshSchedules plan notifications=${plan.notifications.length} '
      'courseAutomationWindows=${plan.courseAutomationWindows.length} '
      'todayCourses=${plan.todayCourses.length} '
      'courseStatusWindows=${plan.courseStatusWindows.length}',
    );

    if (isAndroid) {
      await NativeAlarmService.instance.reconcileMuteState(
        restoreActiveAppMute: !settings.autoMuteEnabled,
      );
      await LocalNotificationService.instance
          .cancelAndroidPluginSchedulesForNativeMigration();
      _log(
        'refreshSchedules scheduling Android native plan '
        'notifications=${plan.notifications.length} '
        'courseAutomationWindows=${plan.courseAutomationWindows.length} '
        'includeCourseStatusWindows=${settings.courseReminderPersistentDisplayEnabled}',
      );
      await NativeAlarmService.instance.scheduleSystemPlan(
        plan,
        includeCourseStatusWindows:
            settings.courseReminderPersistentDisplayEnabled,
      );
    } else {
      await NativeAlarmService.instance.cancelAllClasses();
      await LocalNotificationService.instance.schedulePlan(
        plan,
        useExactAlarms: hasExactAlarmPermission,
      );
    }

    if (settings.courseReminderPersistentDisplayEnabled) {
      await PersistentCourseReminderManager.setEnabled(true);
      await PersistentCourseReminderManager.requestRefresh();
    } else {
      await PersistentCourseReminderManager.setEnabled(false);
    }
    _log('refreshSchedules complete');
  }

  static void _log(String message) {
    debugPrint('$_logTag ${DateTime.now().toIso8601String()} $message');
  }
}
