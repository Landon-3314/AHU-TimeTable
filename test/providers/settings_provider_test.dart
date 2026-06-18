import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:AnKe/providers/settings_provider.dart';
import 'package:AnKe/services/permission_service.dart';
import 'package:AnKe/services/storage_service.dart';

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

  test('falls back when stored session start time is corrupt', () async {
    final settings = await _buildSettingsProvider(
      initialValues: const {
        'settings.morningStartTime': 'bad-value',
        'settings.afternoonStartTime': 'broken',
        'settings.eveningStartTime': '99:xx',
      },
    );

    expect(settings.morningStartTime, const TimeOfDay(hour: 8, minute: 0));
    expect(settings.afternoonStartTime, const TimeOfDay(hour: 14, minute: 0));
    expect(settings.eveningStartTime, const TimeOfDay(hour: 19, minute: 0));
  });

  test('falls back when stored session start time is out of range', () async {
    final settings = await _buildSettingsProvider(
      initialValues: const {
        'settings.morningStartTime': '99:30',
        'settings.afternoonStartTime': '08:99',
        'settings.eveningStartTime': '-1:00',
      },
    );

    expect(settings.morningStartTime, const TimeOfDay(hour: 8, minute: 0));
    expect(settings.afternoonStartTime, const TimeOfDay(hour: 14, minute: 0));
    expect(settings.eveningStartTime, const TimeOfDay(hour: 19, minute: 0));
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
    'onboarding guide confirmations roll back when persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(storageService: storage);

      storage.failGuideWrites = true;
      await expectLater(
        settings.confirmTimetableToolbarGuide(),
        throwsStateError,
      );
      expect(settings.shouldShowTimetableToolbarGuide, isTrue);

      await expectLater(settings.confirmTimetableMenuGuide(), throwsStateError);
      expect(settings.shouldShowTimetableMenuGuide, isTrue);

      await expectLater(settings.confirmImportWebViewGuide(), throwsStateError);
      expect(settings.shouldShowImportWebViewGuide, isTrue);
    },
  );

  test('pixels per minute rolls back when persistence fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalPixelsPerMinute = settings.pixelsPerMinute;

    storage.failPixelsPerMinuteWrites = true;
    await expectLater(settings.updatePixelsPerMinute(1.6), throwsStateError);

    expect(settings.pixelsPerMinute, originalPixelsPerMinute);
    final restored = SettingsProvider(storageService: storage);
    expect(restored.pixelsPerMinute, originalPixelsPerMinute);
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

  test(
    'initial semester completion rolls back when persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(storageService: storage);
      final originalStartDate = settings.semesterStartDate;

      storage.failSemesterInitializationWrites = true;
      await expectLater(
        settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23)),
        throwsStateError,
      );

      expect(settings.semesterStartDate, originalStartDate);
      expect(settings.isCurrentSemesterInitialized, isFalse);
    },
  );

  test(
    'academic import semester initialization rolls back when persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(storageService: storage);
      final originalStartDate = settings.semesterStartDate;

      storage.failSemesterInitializationWrites = true;
      await expectLater(
        settings.initializeCurrentSemesterFromAcademicImport(
          DateTime(2026, 3, 4),
        ),
        throwsStateError,
      );

      expect(settings.semesterStartDate, originalStartDate);
      expect(settings.isCurrentSemesterInitialized, isFalse);
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

  test('theme changes roll back in memory when persistence fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalPalette = settings.themePaletteId;
    final originalPrimary = settings.customThemePrimaryValue;
    final originalAccent = settings.customThemeAccentValue;

    storage.failThemeWrites = true;
    await expectLater(
      settings.changeThemePalette('teal_orange'),
      throwsStateError,
    );
    expect(settings.themePaletteId, originalPalette);

    await expectLater(
      settings.changeCustomThemeColors(
        primaryValue: 0xFF000001,
        accentValue: 0xFF000002,
      ),
      throwsStateError,
    );
    expect(settings.themePaletteId, originalPalette);
    expect(settings.customThemePrimaryValue, originalPrimary);
    expect(settings.customThemeAccentValue, originalAccent);
  });

  test('custom theme partial persistence is compensated on failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalPalette = settings.themePaletteId;
    final originalPrimary = settings.customThemePrimaryValue;
    final originalAccent = settings.customThemeAccentValue;

    storage.failOnWriteNumber = 2;
    await expectLater(
      settings.changeCustomThemeColors(
        primaryValue: 0xFF000001,
        accentValue: 0xFF000002,
      ),
      throwsStateError,
    );

    final restored = SettingsProvider(storageService: storage);
    expect(restored.themePaletteId, originalPalette);
    expect(restored.customThemePrimaryValue, originalPrimary);
    expect(restored.customThemeAccentValue, originalAccent);
  });

  test('period settings roll back in memory when persistence fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalDuration = settings.classDuration;
    final originalShortBreak = settings.shortBreak;
    final originalMorningStarts = settings.morningPeriodStartTimes;
    final originalMorningClasses = settings.morningClasses;

    storage.failPeriodWrites = true;
    await expectLater(settings.updateClassDuration(50), throwsStateError);
    expect(settings.classDuration, originalDuration);
    expect(settings.morningPeriodStartTimes, originalMorningStarts);

    await expectLater(settings.updateShortBreak(15), throwsStateError);
    expect(settings.shortBreak, originalShortBreak);
    expect(settings.morningPeriodStartTimes, originalMorningStarts);

    await expectLater(settings.updateMorningClasses(3), throwsStateError);
    expect(settings.morningClasses, originalMorningClasses);
    expect(settings.morningPeriodStartTimes, originalMorningStarts);

    await expectLater(
      settings.updatePeriodStartTime(
        ClassDayPeriod.morning,
        0,
        const TimeOfDay(hour: 9, minute: 0),
      ),
      throwsStateError,
    );
    expect(settings.morningPeriodStartTimes, originalMorningStarts);
  });

  test('period partial persistence is compensated on failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalDuration = settings.classDuration;
    final originalMorningStarts = settings.morningPeriodStartTimes;

    storage.failOnWriteNumber = 2;
    await expectLater(settings.updateClassDuration(50), throwsStateError);

    final restored = SettingsProvider(storageService: storage);
    expect(restored.classDuration, originalDuration);
    expect(restored.morningPeriodStartTimes, originalMorningStarts);
  });

  test('short break partial persistence is compensated on failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalShortBreak = settings.shortBreak;
    final originalMorningStarts = settings.morningPeriodStartTimes;

    storage.failOnWriteNumber = 2;
    await expectLater(settings.updateShortBreak(10), throwsStateError);

    final restored = SettingsProvider(storageService: storage);
    expect(restored.shortBreak, originalShortBreak);
    expect(restored.morningPeriodStartTimes, originalMorningStarts);
  });

  test('big break partial persistence is compensated on failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalEnabled = settings.bigBreakEnabled;
    final originalBigBreak = settings.bigBreak;
    final originalAfterPeriods = settings.bigBreakAfterPeriods;
    final originalMorningStarts = settings.morningPeriodStartTimes;

    storage.failOnWriteNumber = 2;
    await expectLater(
      settings.updateBigBreakSettings(
        enabled: false,
        durationMinutes: 20,
        afterPeriods: const [3],
      ),
      throwsStateError,
    );

    final restored = SettingsProvider(storageService: storage);
    expect(restored.bigBreakEnabled, originalEnabled);
    expect(restored.bigBreak, originalBigBreak);
    expect(restored.bigBreakAfterPeriods, originalAfterPeriods);
    expect(restored.morningPeriodStartTimes, originalMorningStarts);
  });

  test(
    'period start time partial persistence is compensated on failure',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(storageService: storage);
      final originalMorningStartTime = settings.morningStartTime;
      final originalMorningStarts = settings.morningPeriodStartTimes;

      storage.failOnWriteNumber = 2;
      await expectLater(
        settings.updatePeriodStartTime(
          ClassDayPeriod.morning,
          0,
          const TimeOfDay(hour: 8, minute: 30),
        ),
        throwsStateError,
      );

      final restored = SettingsProvider(storageService: storage);
      expect(restored.morningStartTime, originalMorningStartTime);
      expect(restored.morningPeriodStartTimes, originalMorningStarts);
    },
  );

  test('total weeks rolls back in memory when persistence fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final originalWeeks = settings.totalWeeks;

    storage.failTotalWeeksWrites = true;
    await expectLater(settings.updateTotalWeeks(20), throwsStateError);

    expect(settings.totalWeeks, originalWeeks);
  });

  test(
    'semester start date rolls back in memory when persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(storageService: storage);
      await settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23));
      final originalStartDate = settings.semesterStartDate;

      storage.failSemesterStartWrites = true;
      await expectLater(
        settings.updateSemesterStartDate(DateTime(2026, 3, 2)),
        throwsStateError,
      );

      expect(settings.semesterStartDate, originalStartDate);
      final restored = SettingsProvider(storageService: storage);
      expect(restored.semesterStartDate, originalStartDate);
    },
  );

  test(
    'reminder advance minutes roll back in memory when persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(
        storageService: storage,
        permissionService: _FakePermissionService(notificationGranted: true),
      );
      final originalMinutes = settings.reminderAdvanceMinutes;

      storage.failReminderWrites = true;
      await expectLater(
        settings.updateReminderAdvanceMinutes(10),
        throwsStateError,
      );

      expect(settings.reminderAdvanceMinutes, originalMinutes);
      final restored = SettingsProvider(storageService: storage);
      expect(restored.reminderAdvanceMinutes, originalMinutes);
    },
  );

  test(
    'event reminder advance minutes roll back in memory when persistence fails',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _FailingSettingsStorageService(
        sharedPreferences: preferences,
      );
      await storage.ensureSemesterMigration();
      final settings = SettingsProvider(
        storageService: storage,
        permissionService: _FakePermissionService(notificationGranted: true),
      );
      final originalMinutes = settings.eventReminderAdvanceMinutes;

      storage.failEventReminderWrites = true;
      await expectLater(
        settings.updateEventReminderAdvanceMinutes(30),
        throwsStateError,
      );

      expect(settings.eventReminderAdvanceMinutes, originalMinutes);
      final restored = SettingsProvider(storageService: storage);
      expect(restored.eventReminderAdvanceMinutes, originalMinutes);
    },
  );

  test('auto mute rolls back in memory when persistence fails', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = _FailingSettingsStorageService(
      sharedPreferences: preferences,
    );
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(
      storageService: storage,
      permissionService: _FakePermissionService(notificationGranted: true),
    );
    final originalAutoMute = settings.autoMuteEnabled;

    storage.failAutoMuteWrites = true;
    await expectLater(settings.toggleAutoMuteWithCheck(true), throwsStateError);

    expect(settings.autoMuteEnabled, originalAutoMute);
    final restored = SettingsProvider(storageService: storage);
    expect(restored.autoMuteEnabled, originalAutoMute);
  });

  test('reminder refresh failure is separate from persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    settings.bindReminderScheduler(() async {
      throw StateError('refresh failed');
    });

    await expectLater(
      settings.updateTotalWeeks(20),
      throwsA(isA<SettingsReminderRefreshException>()),
    );

    expect(settings.totalWeeks, 20);
    final restored = SettingsProvider(storageService: storage);
    expect(restored.totalWeeks, 20);
  });
}

class _FailingSettingsStorageService extends StorageService {
  _FailingSettingsStorageService({required super.sharedPreferences});

  bool failThemeWrites = false;
  bool failPeriodWrites = false;
  bool failTotalWeeksWrites = false;
  bool failSemesterStartWrites = false;
  bool failSemesterInitializationWrites = false;
  bool failReminderWrites = false;
  bool failEventReminderWrites = false;
  bool failAutoMuteWrites = false;
  bool failGuideWrites = false;
  bool failPixelsPerMinuteWrites = false;
  int? failOnWriteNumber;
  int writeCount = 0;

  void _failIfNeeded(String message, {required bool enabled}) {
    writeCount += 1;
    if (enabled || failOnWriteNumber == writeCount) {
      throw StateError(message);
    }
  }

  @override
  Future<void> writeThemePaletteId(String value) {
    _failIfNeeded('theme write failed', enabled: failThemeWrites);
    return super.writeThemePaletteId(value);
  }

  @override
  Future<void> writeCustomThemePrimaryValue(int value) {
    _failIfNeeded('custom primary write failed', enabled: failThemeWrites);
    return super.writeCustomThemePrimaryValue(value);
  }

  @override
  Future<void> writeCustomThemeAccentValue(int value) {
    _failIfNeeded('custom accent write failed', enabled: failThemeWrites);
    return super.writeCustomThemeAccentValue(value);
  }

  @override
  Future<void> writeClassDuration(int value) {
    _failIfNeeded('class duration write failed', enabled: failPeriodWrites);
    return super.writeClassDuration(value);
  }

  @override
  Future<void> writeShortBreak(int value) {
    _failIfNeeded('short break write failed', enabled: failPeriodWrites);
    return super.writeShortBreak(value);
  }

  @override
  Future<void> writeBigBreakEnabled(bool value) {
    _failIfNeeded('big break enabled write failed', enabled: failPeriodWrites);
    return super.writeBigBreakEnabled(value);
  }

  @override
  Future<void> writeBigBreak(int value) {
    _failIfNeeded('big break duration write failed', enabled: failPeriodWrites);
    return super.writeBigBreak(value);
  }

  @override
  Future<void> writeMorningClasses(int value) {
    _failIfNeeded('morning classes write failed', enabled: failPeriodWrites);
    return super.writeMorningClasses(value);
  }

  @override
  Future<void> writeMorningPeriodStartTimes(List<String> values) {
    _failIfNeeded('morning starts write failed', enabled: failPeriodWrites);
    return super.writeMorningPeriodStartTimes(values);
  }

  @override
  Future<void> writeMorningStartTime(String value) {
    _failIfNeeded('morning start write failed', enabled: failPeriodWrites);
    return super.writeMorningStartTime(value);
  }

  @override
  Future<void> writeBigBreakAfterPeriods(List<int> values) {
    _failIfNeeded('big break write failed', enabled: failPeriodWrites);
    return super.writeBigBreakAfterPeriods(values);
  }

  @override
  Future<void> writeTotalWeeks(int value) {
    _failIfNeeded('total weeks write failed', enabled: failTotalWeeksWrites);
    return super.writeTotalWeeks(value);
  }

  @override
  Future<void> writePixelsPerMinute(double value) {
    _failIfNeeded(
      'pixels per minute write failed',
      enabled: failPixelsPerMinuteWrites,
    );
    return super.writePixelsPerMinute(value);
  }

  @override
  Future<void> writeTimetableToolbarGuideConfirmed(bool value) {
    _failIfNeeded('toolbar guide write failed', enabled: failGuideWrites);
    return super.writeTimetableToolbarGuideConfirmed(value);
  }

  @override
  Future<void> writeTimetableMenuGuideConfirmed(bool value) {
    _failIfNeeded('menu guide write failed', enabled: failGuideWrites);
    return super.writeTimetableMenuGuideConfirmed(value);
  }

  @override
  Future<void> writeImportWebViewGuideConfirmed(bool value) {
    _failIfNeeded('import guide write failed', enabled: failGuideWrites);
    return super.writeImportWebViewGuideConfirmed(value);
  }

  @override
  Future<void> writeSemesterStartDate(DateTime value) {
    _failIfNeeded(
      'semester start write failed',
      enabled: failSemesterStartWrites,
    );
    return super.writeSemesterStartDate(value);
  }

  @override
  Future<void> initializeExistingSemester(
    String semesterId, {
    required DateTime startDate,
  }) {
    _failIfNeeded(
      'semester initialization write failed',
      enabled: failSemesterInitializationWrites,
    );
    return super.initializeExistingSemester(semesterId, startDate: startDate);
  }

  @override
  Future<void> writeReminderAdvanceMinutes(int value) {
    _failIfNeeded('reminder write failed', enabled: failReminderWrites);
    return super.writeReminderAdvanceMinutes(value);
  }

  @override
  Future<void> writeEventReminderAdvanceMinutes(int value) {
    _failIfNeeded(
      'event reminder write failed',
      enabled: failEventReminderWrites,
    );
    return super.writeEventReminderAdvanceMinutes(value);
  }

  @override
  Future<void> writeAutoMuteEnabled(bool value) {
    _failIfNeeded('auto mute write failed', enabled: failAutoMuteWrites);
    return super.writeAutoMuteEnabled(value);
  }
}
