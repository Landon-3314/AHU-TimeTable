import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/services/permission_service.dart';
import 'package:timetable/services/storage_service.dart';

Future<SettingsProvider> _buildSettingsProvider({
  Map<String, Object> initialValues = const {},
  PermissionService? permissionService,
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return SettingsProvider(
    storageService: storage,
    permissionService: permissionService,
  );
}

class _FakePermissionService extends PermissionService {
  _FakePermissionService({
    this.notificationGranted = true,
    this.exactAlarmGranted = false,
    this.dndGranted = false,
  });

  final bool notificationGranted;
  final bool exactAlarmGranted;
  final bool dndGranted;

  @override
  Future<bool> ensureNotificationPermission() async => notificationGranted;

  @override
  Future<bool> ensureExactAlarmPermission() async => exactAlarmGranted;

  @override
  Future<bool> hasExactAlarmPermission() async => exactAlarmGranted;

  @override
  Future<bool> ensureDndPermission() async => dndGranted;

  @override
  Future<bool> hasDndPermission() async => dndGranted;
}

void main() {
  test('restores default period start times from session defaults', () async {
    final settings = await _buildSettingsProvider();

    expect(settings.bigBreakEnabled, isTrue);
    expect(settings.bigBreak, 15);
    expect(settings.bigBreakAfterPeriods, [2, 7]);
    expect(
      settings.morningPeriodStartTimes,
      containsAllInOrder([
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 8, minute: 50),
        const TimeOfDay(hour: 9, minute: 50),
        const TimeOfDay(hour: 10, minute: 40),
        const TimeOfDay(hour: 11, minute: 30),
      ]),
    );
    expect(
      settings.afternoonPeriodStartTimes,
      containsAllInOrder([
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 14, minute: 50),
        const TimeOfDay(hour: 15, minute: 50),
        const TimeOfDay(hour: 16, minute: 40),
        const TimeOfDay(hour: 17, minute: 30),
      ]),
    );
    expect(
      settings.eveningPeriodStartTimes,
      containsAllInOrder([
        const TimeOfDay(hour: 19, minute: 0),
        const TimeOfDay(hour: 19, minute: 50),
        const TimeOfDay(hour: 20, minute: 40),
      ]),
    );
    expect(settings.totalClassPeriods, 13);
  });

  test('big break settings reflow matching period tails', () async {
    final settings = await _buildSettingsProvider();

    await settings.updateBigBreakSettings(
      enabled: false,
      durationMinutes: 15,
      afterPeriods: const [2, 7],
    );

    expect(settings.bigBreakEnabled, isFalse);
    expect(
      settings.morningPeriodStartTimes[2],
      const TimeOfDay(hour: 9, minute: 40),
    );
    expect(
      settings.afternoonPeriodStartTimes[2],
      const TimeOfDay(hour: 15, minute: 40),
    );

    await settings.updateBigBreakSettings(
      enabled: true,
      durationMinutes: 20,
      afterPeriods: const [7, 2, 2, 99],
    );

    expect(settings.bigBreakAfterPeriods, [2, 7]);
    expect(settings.bigBreak, 20);
    expect(
      settings.morningPeriodStartTimes[2],
      const TimeOfDay(hour: 9, minute: 55),
    );
    expect(
      settings.afternoonPeriodStartTimes[2],
      const TimeOfDay(hour: 15, minute: 55),
    );
  });

  test('drops stored period start times with invalid hours', () async {
    final settings = await _buildSettingsProvider(
      initialValues: const {
        'settings.morningClasses': 2,
        'settings.morningPeriodStartTimes': ['25:00', '08:00'],
      },
    );

    expect(settings.morningPeriodStartTimes, hasLength(2));
    expect(
      settings.morningPeriodStartTimes,
      containsAllInOrder([
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 8, minute: 50),
      ]),
    );
  });

  test(
    'changing a period start time only shifts the same session tail',
    () async {
      final settings = await _buildSettingsProvider();

      await settings.updatePeriodStartTime(
        ClassDayPeriod.morning,
        1,
        const TimeOfDay(hour: 9, minute: 10),
      );

      expect(
        settings.morningPeriodStartTimes[0],
        const TimeOfDay(hour: 8, minute: 0),
      );
      expect(
        settings.morningPeriodStartTimes[1],
        const TimeOfDay(hour: 9, minute: 10),
      );
      expect(
        settings.morningPeriodStartTimes[2],
        const TimeOfDay(hour: 10, minute: 10),
      );
      expect(
        settings.afternoonPeriodStartTimes.first,
        const TimeOfDay(hour: 14, minute: 0),
      );
      expect(
        settings.eveningPeriodStartTimes.first,
        const TimeOfDay(hour: 19, minute: 0),
      );
    },
  );

  test(
    'changing session class count appends and truncates start times',
    () async {
      final settings = await _buildSettingsProvider();

      await settings.updateSessionClassCount(ClassDayPeriod.evening, 4);
      expect(settings.eveningPeriodStartTimes, hasLength(4));
      expect(
        settings.eveningPeriodStartTimes.last,
        const TimeOfDay(hour: 21, minute: 30),
      );

      await settings.updateSessionClassCount(ClassDayPeriod.evening, 2);
      expect(settings.eveningPeriodStartTimes, hasLength(2));
      expect(
        settings.eveningPeriodStartTimes.last,
        const TimeOfDay(hour: 19, minute: 50),
      );
    },
  );

  test(
    'changing short break reflows each session from its first start',
    () async {
      final settings = await _buildSettingsProvider();

      await settings.updatePeriodStartTime(
        ClassDayPeriod.afternoon,
        0,
        const TimeOfDay(hour: 14, minute: 10),
      );
      await settings.updateShortBreak(10);

      expect(
        settings.morningPeriodStartTimes[1],
        const TimeOfDay(hour: 8, minute: 55),
      );
      expect(
        settings.morningPeriodStartTimes[2],
        const TimeOfDay(hour: 9, minute: 55),
      );
      expect(
        settings.afternoonPeriodStartTimes[0],
        const TimeOfDay(hour: 14, minute: 10),
      );
      expect(
        settings.afternoonPeriodStartTimes[1],
        const TimeOfDay(hour: 15, minute: 5),
      );
      expect(
        settings.afternoonPeriodStartTimes[2],
        const TimeOfDay(hour: 16, minute: 5),
      );
      expect(
        settings.eveningPeriodStartTimes[1],
        const TimeOfDay(hour: 19, minute: 55),
      );
    },
  );

  test('course reminders do not require exact alarm permission', () async {
    final settings = await _buildSettingsProvider(
      permissionService: _FakePermissionService(exactAlarmGranted: false),
    );

    final result = await settings.updateReminderAdvanceMinutes(10);

    expect(result.success, isTrue);
    expect(settings.reminderAdvanceMinutes, 10);
    expect(settings.courseReminderPersistentDisplayEnabled, isFalse);
  });

  test('persistent display is restored as a course reminder style', () async {
    final settings = await _buildSettingsProvider(
      initialValues: const {'settings.backgroundServiceEnabled': true},
    );

    expect(settings.courseReminderEnabled, isTrue);
    expect(settings.courseReminderStyle, CourseReminderStyle.persistentDisplay);
    expect(settings.courseReminderUsesPersistentDisplay, isTrue);
  });

  test('onboarding guides are shown until confirmed', () async {
    final settings = await _buildSettingsProvider();

    expect(settings.shouldShowTimetableToolbarGuide, isTrue);
    expect(settings.shouldShowImportWebViewGuide, isTrue);

    await settings.confirmTimetableToolbarGuide();
    await settings.confirmImportWebViewGuide();

    expect(settings.shouldShowTimetableToolbarGuide, isFalse);
    expect(settings.shouldShowImportWebViewGuide, isFalse);
  });

  test('onboarding guide confirmations are restored from storage', () async {
    final settings = await _buildSettingsProvider(
      initialValues: const {
        'onboarding.timetableToolbarGuideConfirmed.v1': true,
        'onboarding.importWebViewGuideConfirmed.v1': true,
      },
    );

    expect(settings.shouldShowTimetableToolbarGuide, isFalse);
    expect(settings.shouldShowImportWebViewGuide, isFalse);
  });

  test(
    'turning off course reminders also disables persistent display',
    () async {
      final settings = await _buildSettingsProvider(
        initialValues: const {
          'settings.backgroundServiceEnabled': true,
          'settings.reminderAdvanceMinutes': 10,
        },
      );

      final result = await settings.toggleCourseReminder(false);

      expect(result.success, isTrue);
      expect(settings.courseReminderEnabled, isFalse);
      expect(settings.courseReminderPersistentDisplayEnabled, isFalse);
      expect(settings.reminderAdvanceMinutes, 0);
    },
  );

  test('changing course reminder style toggles persistent display', () async {
    final settings = await _buildSettingsProvider(
      permissionService: _FakePermissionService(notificationGranted: true),
    );

    var result = await settings.toggleCourseReminder(true);
    expect(result.success, isTrue);
    expect(
      settings.courseReminderStyle,
      CourseReminderStyle.singleNotification,
    );

    result = await settings.updateCourseReminderStyle(
      CourseReminderStyle.persistentDisplay,
    );
    expect(result.success, isTrue);
    expect(settings.courseReminderPersistentDisplayEnabled, isTrue);
    expect(settings.courseReminderUsesPersistentDisplay, isTrue);

    result = await settings.updateCourseReminderStyle(
      CourseReminderStyle.singleNotification,
    );
    expect(result.success, isTrue);
    expect(settings.courseReminderPersistentDisplayEnabled, isFalse);
    expect(settings.courseReminderUsesSingleNotification, isTrue);
    expect(settings.reminderAdvanceMinutes, greaterThan(0));
  });

  test(
    'auto mute stores user intent when native mute permissions are missing',
    () async {
      final settings = await _buildSettingsProvider(
        permissionService: _FakePermissionService(
          notificationGranted: true,
          exactAlarmGranted: false,
          dndGranted: false,
        ),
      );

      final result = await settings.toggleAutoMuteWithCheck(true);

      expect(result.success, isTrue);
      expect(settings.autoMuteEnabled, isTrue);
      expect(settings.courseReminderPersistentDisplayEnabled, isFalse);
    },
  );

  test(
    'semester changes notify the bound coordinator once per operation',
    () async {
      final settings = await _buildSettingsProvider();
      final originalSemesterId = settings.currentSemesterId!;
      var semesterChangeCount = 0;
      settings.bindSemesterChangeHandler(() async {
        semesterChangeCount += 1;
      });

      await settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23));
      final created = await settings.createSemesterWithInitialData(
        startDate: DateTime(2026, 9, 7),
      );
      expect(await settings.switchSemester(originalSemesterId), isTrue);
      await settings.deleteSemester(created.id);

      expect(semesterChangeCount, 4);
    },
  );

  test(
    'academic import initializes the current semester once from start date',
    () async {
      final settings = await _buildSettingsProvider();

      expect(settings.isCurrentSemesterInitialized, isFalse);

      final initialized = await settings
          .initializeCurrentSemesterFromAcademicImport(DateTime(2026, 3, 4));

      expect(initialized, isTrue);
      expect(settings.isCurrentSemesterInitialized, isTrue);
      expect(settings.semesterStartDate, DateTime(2026, 3, 2));

      final overwritten = await settings
          .initializeCurrentSemesterFromAcademicImport(DateTime(2026, 9, 7));

      expect(overwritten, isFalse);
      expect(settings.semesterStartDate, DateTime(2026, 3, 2));
    },
  );

  test('app theme mode persists and maps to material theme mode', () async {
    final settings = await _buildSettingsProvider();

    expect(settings.appThemeMode, AppThemeMode.system);
    expect(settings.materialThemeMode, ThemeMode.system);

    await settings.changeAppThemeMode(AppThemeMode.dark);

    expect(settings.appThemeMode, AppThemeMode.dark);
    expect(settings.materialThemeMode, ThemeMode.dark);

    final restored = await _buildSettingsProvider(
      initialValues: const {'settings.appThemeMode': 'dark'},
    );
    expect(restored.appThemeMode, AppThemeMode.dark);
    expect(restored.materialThemeMode, ThemeMode.dark);
  });

  test(
    'runtime language stays Chinese when a legacy preference is English',
    () async {
      final settings = await _buildSettingsProvider(
        initialValues: const {'settings.languageCode': 'en'},
      );

      expect(settings.languageCode, 'zh');
      expect(settings.t('settings'), '设置');
    },
  );
}
