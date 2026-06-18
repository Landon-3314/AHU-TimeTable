import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/clock_time.dart';
import '../models/semester.dart';
import '../models/time_slot.dart';

import '../services/permission_service.dart';
import '../services/schedule_calculator.dart';
import '../services/storage_service.dart';

class SettingsActionResult {
  const SettingsActionResult._({required this.success, this.message});

  final bool success;
  final String? message;

  factory SettingsActionResult.success() =>
      const SettingsActionResult._(success: true);

  factory SettingsActionResult.failure(String message) =>
      SettingsActionResult._(success: false, message: message);
}

class SettingsReminderRefreshException implements Exception {
  SettingsReminderRefreshException(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'SettingsReminderRefreshException: $cause';
}

enum ClassDayPeriod { morning, afternoon, evening }

enum CourseReminderStyle { singleNotification, persistentDisplay }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required StorageService storageService,
    ScheduleCalculator? scheduleCalculator,
    PermissionService? permissionService,
  }) : _storageService = storageService,
       _scheduleCalculator = scheduleCalculator ?? const ScheduleCalculator(),
       _permissionService = permissionService ?? PermissionService(),
       _pixelsPerMinute = storageService.readPixelsPerMinute(
         fallback: _defaultPixelsPerMinute,
       ),
       _classDuration = storageService.readClassDuration(
         fallback: _defaultClassDuration,
       ),
       _shortBreak = storageService.readShortBreak(
         fallback: _defaultShortBreak,
       ),
       _bigBreakEnabled = storageService.readBigBreakEnabled(
         fallback: _defaultBigBreakEnabled,
       ),
       _bigBreak = storageService.readBigBreak(fallback: _defaultBigBreak),
       _bigBreakAfterPeriods = _restoreBigBreakAfterPeriodsFromStorage(
         storageService,
       ),
       _morningStartTime = storageService.readMorningStartTime(
         fallback: _defaultMorningStartTime,
       ),
       _morningClasses = storageService.readMorningClasses(
         fallback: _defaultMorningClasses,
       ),
       _afternoonStartTime = storageService.readAfternoonStartTime(
         fallback: _defaultAfternoonStartTime,
       ),
       _afternoonClasses = storageService.readAfternoonClasses(
         fallback: _defaultAfternoonClasses,
       ),
       _eveningStartTime = storageService.readEveningStartTime(
         fallback: _defaultEveningStartTime,
       ),
       _eveningClasses = storageService.readEveningClasses(
         fallback: _defaultEveningClasses,
       ),
       _morningPeriodStartTimes = _restoreSessionStartTimesFromStorage(
         storageService,
         ClassDayPeriod.morning,
       ),
       _afternoonPeriodStartTimes = _restoreSessionStartTimesFromStorage(
         storageService,
         ClassDayPeriod.afternoon,
       ),
       _eveningPeriodStartTimes = _restoreSessionStartTimesFromStorage(
         storageService,
         ClassDayPeriod.evening,
       ),
       _semesterStartDate = _restoreSemesterStartDate(
         storageService: storageService,
         scheduleCalculator: scheduleCalculator ?? const ScheduleCalculator(),
       ),
       _totalWeeks = storageService.readTotalWeeks(
         fallback: _defaultTotalWeeks,
       ),
       _reminderAdvanceMinutes = storageService.readReminderAdvanceMinutes(
         fallback: _defaultReminderAdvanceMinutes,
       ),
       _eventReminderAdvanceMinutes = storageService
           .readEventReminderAdvanceMinutes(
             fallback: _defaultEventReminderAdvanceMinutes,
           ),
       _appThemeMode = storageService.readAppThemeMode(),
       _themePaletteId = storageService.readThemePaletteId(
         fallback: AppThemePalette.defaultPalette.id,
       ),
       _customThemePrimaryValue = storageService.readCustomThemePrimaryValue(
         fallback: AppColors.themePickerPaletteValues.first,
       ),
       _customThemeAccentValue = storageService.readCustomThemeAccentValue(
         fallback: AppThemePalette.defaultPalette.accentValue,
       ),
       _autoMuteEnabled = storageService.readAutoMuteEnabled(fallback: false),
       _semesters = storageService.loadSemesters(),
       _currentSemesterId = storageService.currentSemesterId,
       _courseReminderPersistentDisplayEnabled = storageService
           .readCourseReminderPersistentDisplayEnabled(fallback: false),
       _timetableToolbarGuideConfirmed = storageService
           .readTimetableToolbarGuideConfirmed(fallback: false),
       // 向后兼容：menu guide 的 key 对老用户不存在，
       // fallback 取 toolbar guide 的值（老用户 toolbar=true → menu 默认跳过）
       _timetableMenuGuideConfirmed = storageService
           .readTimetableMenuGuideConfirmed(
             fallback: storageService.readTimetableToolbarGuideConfirmed(
               fallback: false,
             ),
           ),
       _importWebViewGuideConfirmed = storageService
           .readImportWebViewGuideConfirmed(fallback: false);

  static const double _defaultPixelsPerMinute = 1.2;
  static const int _defaultClassDuration = 45;
  static const int _defaultShortBreak = 5;
  static const bool _defaultBigBreakEnabled = true;
  static const int _defaultBigBreak = 15;
  static const int _defaultBigBreakAfterPeriod = 2;
  static const String _defaultMorningStartTime = '08:00';
  static const int _defaultMorningClasses = 5;
  static const String _defaultAfternoonStartTime = '14:00';
  static const int _defaultAfternoonClasses = 5;
  static const String _defaultEveningStartTime = '19:00';
  static const int _defaultEveningClasses = 3;
  static const int _defaultTotalWeeks = AppConstants.defaultSemesterTotalWeeks;
  static const int _defaultReminderAdvanceMinutes = 0;
  static const int _defaultEventReminderAdvanceMinutes = 0;
  static const int _maxCourseReminderAdvanceMinutes = 23 * 60 + 59;
  static const int _maxEventReminderAdvanceMinutes = 7 * 24 * 60 + 23 * 60 + 59;

  final StorageService _storageService;
  final ScheduleCalculator _scheduleCalculator;
  final PermissionService _permissionService;

  double _pixelsPerMinute;
  int _classDuration;
  int _shortBreak;
  bool _bigBreakEnabled;
  int _bigBreak;
  List<int> _bigBreakAfterPeriods;
  String _morningStartTime;
  int _morningClasses;
  String _afternoonStartTime;
  int _afternoonClasses;
  String _eveningStartTime;
  int _eveningClasses;
  List<String> _morningPeriodStartTimes;
  List<String> _afternoonPeriodStartTimes;
  List<String> _eveningPeriodStartTimes;
  DateTime _semesterStartDate;
  int _totalWeeks;
  int _reminderAdvanceMinutes;
  int _eventReminderAdvanceMinutes;
  AppThemeMode _appThemeMode;
  String _themePaletteId;
  int _customThemePrimaryValue;
  int _customThemeAccentValue;
  bool _autoMuteEnabled;
  bool _courseReminderPersistentDisplayEnabled;
  bool _timetableToolbarGuideConfirmed;
  bool _timetableMenuGuideConfirmed;
  bool _importWebViewGuideConfirmed;
  List<Semester> _semesters;
  String? _currentSemesterId;
  Future<void> Function()? _reminderScheduler;
  Future<void> Function()? _semesterChangeHandler;

  double get pixelsPerMinute => _pixelsPerMinute;
  int get classDuration => _classDuration;
  int get shortBreak => _shortBreak;
  bool get bigBreakEnabled => _bigBreakEnabled;
  int get bigBreak => _bigBreak;
  int get bigBreakAfterPeriod => bigBreakAfterPeriods.isEmpty
      ? _defaultBigBreakAfterPeriod
      : bigBreakAfterPeriods.first;
  List<int> get bigBreakAfterPeriods =>
      _sanitizeBigBreakAfterPeriods(_bigBreakAfterPeriods, totalClassPeriods);
  TimeOfDay get morningStartTime =>
      _parseTime(_morningStartTime, fallback: _defaultMorningStartTime);
  int get morningClasses => _morningClasses;
  TimeOfDay get afternoonStartTime =>
      _parseTime(_afternoonStartTime, fallback: _defaultAfternoonStartTime);
  int get afternoonClasses => _afternoonClasses;
  TimeOfDay get eveningStartTime =>
      _parseTime(_eveningStartTime, fallback: _defaultEveningStartTime);
  int get eveningClasses => _eveningClasses;
  List<TimeOfDay> get morningPeriodStartTimes =>
      _parseTimeList(_morningPeriodStartTimes);
  List<TimeOfDay> get afternoonPeriodStartTimes =>
      _parseTimeList(_afternoonPeriodStartTimes);
  List<TimeOfDay> get eveningPeriodStartTimes =>
      _parseTimeList(_eveningPeriodStartTimes);
  int get totalClassPeriods =>
      _morningClasses + _afternoonClasses + _eveningClasses;
  DateTime get semesterStartDate => _semesterStartDate;
  int get totalWeeks => _totalWeeks;
  int get reminderAdvanceMinutes => _reminderAdvanceMinutes;
  int get eventReminderAdvanceMinutes => _eventReminderAdvanceMinutes;
  String get languageCode => 'zh';
  AppThemeMode get appThemeMode => _appThemeMode;
  ThemeMode get materialThemeMode => switch (_appThemeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
  String get themePaletteId => _themePaletteId;
  int get customThemePrimaryValue => _customThemePrimaryValue;
  int get customThemeAccentValue => _customThemeAccentValue;
  AppThemePalette get themePalette {
    if (_themePaletteId == AppThemePalette.customId) {
      return AppThemePalette.custom(
        primaryValue: _customThemePrimaryValue,
        accentValue: _customThemeAccentValue,
      );
    }
    return AppThemePalette.byId(_themePaletteId);
  }

  bool get autoMuteEnabled => _autoMuteEnabled;
  bool get courseReminderPersistentDisplayEnabled =>
      _courseReminderPersistentDisplayEnabled;
  CourseReminderStyle get courseReminderStyle =>
      _courseReminderPersistentDisplayEnabled
      ? CourseReminderStyle.persistentDisplay
      : CourseReminderStyle.singleNotification;
  bool get courseReminderUsesSingleNotification =>
      courseReminderEnabled &&
      courseReminderStyle == CourseReminderStyle.singleNotification;
  bool get courseReminderUsesPersistentDisplay =>
      courseReminderEnabled &&
      courseReminderStyle == CourseReminderStyle.persistentDisplay;
  List<Semester> get semesters => List.unmodifiable(_semesters);
  String? get currentSemesterId => _currentSemesterId;
  Semester? get currentSemester {
    final semesterId = _currentSemesterId;
    if (semesterId == null) {
      return null;
    }
    for (final semester in _semesters) {
      if (semester.id == semesterId) {
        return semester;
      }
    }
    return null;
  }

  bool get shouldShowSemesterStartDatePrompt =>
      currentSemester?.isInitialized != true;
  bool get isCurrentSemesterInitialized =>
      currentSemester?.isInitialized == true;
  bool get shouldShowTimetableToolbarGuide => !_timetableToolbarGuideConfirmed;

  /// 折叠菜单引导是否需要展示。
  bool get shouldShowTimetableMenuGuide => !_timetableMenuGuideConfirmed;
  bool get shouldShowImportWebViewGuide => !_importWebViewGuideConfirmed;
  bool get courseReminderEnabled =>
      _reminderAdvanceMinutes > 0 || _courseReminderPersistentDisplayEnabled;
  List<TimeSlot> get timeSlots => generateTimeSlots();
  String t(String key) => AppStrings.get(key, 'zh');

  int get currentRealWeek => _scheduleCalculator.computeCurrentWeek(
    semesterStartDate: _semesterStartDate,
    totalWeeks: _totalWeeks,
  );

  int get currentRealWeekday => _scheduleCalculator.computeCurrentWeekday();

  DateTime getDateFor(int week, int weekday) {
    return _scheduleCalculator.getDateFor(
      semesterStartDate: _semesterStartDate,
      totalWeeks: _totalWeeks,
      week: week,
      weekday: weekday,
    );
  }

  void bindReminderScheduler(Future<void> Function() callback) {
    _reminderScheduler = callback;
  }

  void bindSemesterChangeHandler(Future<void> Function() callback) {
    _semesterChangeHandler = callback;
  }

  Future<bool> syncExternalBackup() {
    return _storageService.syncExternalBackup();
  }

  Future<int> consumePendingCorruptRowNoticeCount() {
    return _storageService.consumePendingCorruptRowNoticeCount();
  }

  Future<Semester> createSemesterWithInitialData({
    required DateTime startDate,
    String? customName,
  }) async {
    final aligned = _scheduleCalculator.alignToMonday(startDate);
    final semester = await _storageService.createSemesterWithInitialData(
      startDate: aligned,
      customName: customName,
    );
    _reloadSemesterState();
    notifyListeners();
    await _handleSemesterChange();
    return semester;
  }

  Future<bool> switchSemester(String semesterId) async {
    if (semesterId == _currentSemesterId) {
      return true;
    }
    final targetSemester = _semesterById(semesterId);
    if (targetSemester?.isInitialized != true) {
      return false;
    }

    await _storageService.switchSemester(semesterId);
    _reloadSemesterState();
    notifyListeners();
    await _handleSemesterChange();
    return true;
  }

  Future<void> initializeExistingSemester(
    String semesterId, {
    required DateTime startDate,
  }) async {
    final aligned = _scheduleCalculator.alignToMonday(startDate);
    await _storageService.initializeExistingSemester(
      semesterId,
      startDate: aligned,
    );
    if (semesterId == _currentSemesterId) {
      _reloadSemesterState();
    } else {
      _semesters = _storageService.loadSemesters();
    }
    notifyListeners();
    if (semesterId == _currentSemesterId) {
      await _handleSemesterChange();
    }
  }

  Future<void> initializeExistingSemesterAndSwitch(
    String semesterId, {
    required DateTime startDate,
  }) async {
    final aligned = _scheduleCalculator.alignToMonday(startDate);
    await _storageService.initializeExistingSemester(
      semesterId,
      startDate: aligned,
    );
    await _storageService.switchSemester(semesterId);
    _reloadSemesterState();
    notifyListeners();
    await _handleSemesterChange();
  }

  Future<void> renameSemester(String semesterId, String newName) async {
    await _storageService.renameSemester(semesterId, newName);
    _semesters = _storageService.loadSemesters();
    notifyListeners();
  }

  Future<String?> deleteSemester(String semesterId) async {
    final nextSemesterId = await _storageService.deleteSemester(semesterId);
    _reloadSemesterState();
    notifyListeners();
    await _handleSemesterChange();
    return nextSemesterId;
  }

  Future<void> changeAppThemeMode(AppThemeMode mode) async {
    if (mode == _appThemeMode) {
      return;
    }

    final snapshot = _themeSnapshot();
    _appThemeMode = mode;
    await _commitSettingsMutation(
      restore: () => _restoreThemeSnapshot(snapshot),
      persist: () => _storageService.writeAppThemeMode(mode),
      compensate: () => _persistThemeSnapshot(snapshot),
    );
  }

  Future<void> changeThemePalette(String id) async {
    final palette = AppThemePalette.byId(id);
    if (palette.id == _themePaletteId) {
      return;
    }

    final snapshot = _themeSnapshot();
    _themePaletteId = palette.id;
    await _commitSettingsMutation(
      restore: () => _restoreThemeSnapshot(snapshot),
      persist: () => _storageService.writeThemePaletteId(palette.id),
      compensate: () => _persistThemeSnapshot(snapshot),
    );
  }

  Future<void> confirmTimetableToolbarGuide() async {
    if (_timetableToolbarGuideConfirmed) {
      return;
    }
    final previousToolbarConfirmed = _timetableToolbarGuideConfirmed;
    final previousMenuConfirmed = _timetableMenuGuideConfirmed;
    _timetableToolbarGuideConfirmed = true;
    await _commitSettingsMutation(
      restore: () {
        _timetableToolbarGuideConfirmed = previousToolbarConfirmed;
        _timetableMenuGuideConfirmed = previousMenuConfirmed;
      },
      persist: () async {
        await _storageService.writeTimetableToolbarGuideConfirmed(true);
        // 显式写入 menuGuide=false，确保 key 存在于存储中。
        // 这样新用户重启后不会因为 fallback 到 toolbar 值而误跳过菜单引导。
        if (!previousMenuConfirmed) {
          await _storageService.writeTimetableMenuGuideConfirmed(false);
        }
      },
      compensate: () async {
        await _storageService.writeTimetableToolbarGuideConfirmed(
          previousToolbarConfirmed,
        );
        await _storageService.writeTimetableMenuGuideConfirmed(
          previousMenuConfirmed,
        );
      },
    );
  }

  Future<void> confirmTimetableMenuGuide() async {
    if (_timetableMenuGuideConfirmed) {
      return;
    }
    final previousValue = _timetableMenuGuideConfirmed;
    _timetableMenuGuideConfirmed = true;
    await _commitSettingsMutation(
      restore: () => _timetableMenuGuideConfirmed = previousValue,
      persist: () => _storageService.writeTimetableMenuGuideConfirmed(true),
      compensate: () =>
          _storageService.writeTimetableMenuGuideConfirmed(previousValue),
    );
  }

  Future<void> confirmImportWebViewGuide() async {
    if (_importWebViewGuideConfirmed) {
      return;
    }
    final previousValue = _importWebViewGuideConfirmed;
    _importWebViewGuideConfirmed = true;
    await _commitSettingsMutation(
      restore: () => _importWebViewGuideConfirmed = previousValue,
      persist: () => _storageService.writeImportWebViewGuideConfirmed(true),
      compensate: () =>
          _storageService.writeImportWebViewGuideConfirmed(previousValue),
    );
  }

  Future<void> changeCustomThemeColors({
    required int primaryValue,
    required int accentValue,
  }) async {
    if (_themePaletteId == AppThemePalette.customId &&
        _customThemePrimaryValue == primaryValue &&
        _customThemeAccentValue == accentValue) {
      return;
    }

    final snapshot = _themeSnapshot();
    _themePaletteId = AppThemePalette.customId;
    _customThemePrimaryValue = primaryValue;
    _customThemeAccentValue = accentValue;
    await _commitSettingsMutation(
      restore: () => _restoreThemeSnapshot(snapshot),
      persist: () async {
        await _storageService.writeThemePaletteId(AppThemePalette.customId);
        await _storageService.writeCustomThemePrimaryValue(primaryValue);
        await _storageService.writeCustomThemeAccentValue(accentValue);
      },
      compensate: () => _persistThemeSnapshot(snapshot),
    );
  }

  List<TimeSlot> generateTimeSlots() {
    return _scheduleCalculator.generateTimeSlots(
      classDuration: _classDuration,
      morningStartTimes: _clockTimesFromStrings(_morningPeriodStartTimes),
      afternoonStartTimes: _clockTimesFromStrings(_afternoonPeriodStartTimes),
      eveningStartTimes: _clockTimesFromStrings(_eveningPeriodStartTimes),
    );
  }

  Future<void> updatePixelsPerMinute(double value) async {
    if (value == _pixelsPerMinute) {
      return;
    }

    final previousValue = _pixelsPerMinute;
    _pixelsPerMinute = value;
    await _commitSettingsMutation(
      restore: () => _pixelsPerMinute = previousValue,
      persist: () => _storageService.writePixelsPerMinute(value),
      compensate: () => _storageService.writePixelsPerMinute(previousValue),
    );
  }

  Future<void> updateClassDuration(int value) async {
    if (value == _classDuration) {
      return;
    }

    final snapshot = _periodSnapshot();
    _classDuration = value;
    _reflowAllSessionStartTimes();
    await _commitSettingsMutation(
      restore: () => _restorePeriodSnapshot(snapshot),
      persist: () async {
        await _storageService.writeClassDuration(value);
        await _persistAllSessionStartTimes();
      },
      compensate: () => _persistPeriodSnapshot(snapshot),
      refreshReminders: true,
    );
  }

  Future<void> updateShortBreak(int value) async {
    if (value == _shortBreak) {
      return;
    }

    final snapshot = _periodSnapshot();
    _shortBreak = value;
    _reflowAllSessionStartTimes();
    await _commitSettingsMutation(
      restore: () => _restorePeriodSnapshot(snapshot),
      persist: () async {
        await _storageService.writeShortBreak(value);
        await _persistAllSessionStartTimes();
      },
      compensate: () => _persistPeriodSnapshot(snapshot),
      refreshReminders: true,
    );
  }

  Future<void> updateBigBreakEnabled(bool value) async {
    await updateBigBreakSettings(
      enabled: value,
      durationMinutes: _bigBreak,
      afterPeriods: _bigBreakAfterPeriods,
    );
  }

  Future<void> updateBigBreak(int value) async {
    await updateBigBreakSettings(
      enabled: _bigBreakEnabled,
      durationMinutes: value,
      afterPeriods: _bigBreakAfterPeriods,
    );
  }

  Future<void> updateBigBreakAfterPeriod(int value) async {
    await updateBigBreakSettings(
      enabled: _bigBreakEnabled,
      durationMinutes: _bigBreak,
      afterPeriods: <int>[value],
    );
  }

  Future<void> updateBigBreakAfterPeriods(Iterable<int> values) async {
    await updateBigBreakSettings(
      enabled: _bigBreakEnabled,
      durationMinutes: _bigBreak,
      afterPeriods: values,
    );
  }

  Future<void> updateBigBreakSettings({
    required bool enabled,
    required int durationMinutes,
    required Iterable<int> afterPeriods,
  }) async {
    final safeDuration = durationMinutes.clamp(0, 120).toInt();
    final safeAfterPeriods = _sanitizeBigBreakAfterPeriods(
      afterPeriods,
      totalClassPeriods,
    );
    if (enabled == _bigBreakEnabled &&
        safeDuration == _bigBreak &&
        _listEquals(safeAfterPeriods, _bigBreakAfterPeriods)) {
      return;
    }

    final snapshot = _periodSnapshot();
    _bigBreakEnabled = enabled;
    _bigBreak = safeDuration;
    _bigBreakAfterPeriods = safeAfterPeriods;
    _reflowAllSessionStartTimes();
    await _commitSettingsMutation(
      restore: () => _restorePeriodSnapshot(snapshot),
      persist: () async {
        await _storageService.writeBigBreakEnabled(enabled);
        await _storageService.writeBigBreak(safeDuration);
        await _storageService.writeBigBreakAfterPeriods(safeAfterPeriods);
        await _persistAllSessionStartTimes();
      },
      compensate: () => _persistPeriodSnapshot(snapshot),
      refreshReminders: true,
    );
  }

  Future<void> updateMorningStartTime(TimeOfDay value) async {
    await updatePeriodStartTime(ClassDayPeriod.morning, 0, value);
  }

  Future<void> updateMorningClasses(int value) async {
    await updateSessionClassCount(ClassDayPeriod.morning, value);
  }

  Future<void> updateAfternoonStartTime(TimeOfDay value) async {
    await updatePeriodStartTime(ClassDayPeriod.afternoon, 0, value);
  }

  Future<void> updateAfternoonClasses(int value) async {
    await updateSessionClassCount(ClassDayPeriod.afternoon, value);
  }

  Future<void> updateEveningStartTime(TimeOfDay value) async {
    await updatePeriodStartTime(ClassDayPeriod.evening, 0, value);
  }

  Future<void> updateEveningClasses(int value) async {
    await updateSessionClassCount(ClassDayPeriod.evening, value);
  }

  Future<void> updateSessionClassCount(ClassDayPeriod period, int value) async {
    final safeValue = value.clamp(0, 12).toInt();
    if (safeValue == _classCountFor(period)) {
      return;
    }

    final startTimes = _resizeSessionStartTimes(
      period,
      _startTimesFor(period),
      safeValue,
      _fallbackStartTimeFor(period),
    );
    final snapshot = _periodSnapshot();
    _setClassCount(period, safeValue);
    _bigBreakAfterPeriods = _sanitizeBigBreakAfterPeriods(
      _bigBreakAfterPeriods,
      totalClassPeriods,
    );
    _setStartTimes(period, startTimes);
    _reflowAllSessionStartTimes();
    await _commitSettingsMutation(
      restore: () => _restorePeriodSnapshot(snapshot),
      persist: () async {
        await _persistClassCount(period, safeValue);
        await _storageService.writeBigBreakAfterPeriods(_bigBreakAfterPeriods);
        await _persistStartTimes(period, startTimes);
      },
      compensate: () => _persistPeriodSnapshot(snapshot),
      refreshReminders: true,
    );
  }

  Future<void> updatePeriodStartTime(
    ClassDayPeriod period,
    int index,
    TimeOfDay value,
  ) async {
    final currentStartTimes = _startTimesFor(period);
    if (index < 0 || index >= currentStartTimes.length) {
      return;
    }

    final formatted = _formatTime(value);
    if (formatted == currentStartTimes[index]) {
      return;
    }

    final updatedStartTimes = List<String>.of(currentStartTimes);
    updatedStartTimes[index] = formatted;
    for (var i = index + 1; i < updatedStartTimes.length; i += 1) {
      updatedStartTimes[i] = _nextStartTime(
        period,
        i - 1,
        updatedStartTimes[i - 1],
      );
    }

    final snapshot = _periodSnapshot();
    _setStartTimes(period, updatedStartTimes);
    if (index == 0) {
      _setLegacySessionStartTime(period, formatted);
    }
    await _commitSettingsMutation(
      restore: () => _restorePeriodSnapshot(snapshot),
      persist: () async {
        await _persistStartTimes(period, updatedStartTimes);
        if (index == 0) {
          await _persistLegacySessionStartTime(period, formatted);
        }
      },
      compensate: () => _persistPeriodSnapshot(snapshot),
      refreshReminders: true,
    );
  }

  Future<void> updateSemesterStartDate(DateTime value) async {
    final aligned = _scheduleCalculator.alignToMonday(value);
    if (_isSameDate(aligned, _semesterStartDate)) {
      return;
    }

    final previousStartDate = _semesterStartDate;
    _semesterStartDate = aligned;
    if (!isCurrentSemesterInitialized) {
      await _commitSettingsMutation(
        restore: () => _semesterStartDate = previousStartDate,
        persist: () async {
          final semesterId = _currentSemesterId;
          if (semesterId != null) {
            await _storageService.initializeExistingSemester(
              semesterId,
              startDate: aligned,
            );
          } else {
            await _storageService.writeSemesterStartDate(aligned);
          }
        },
      );
      _reloadSemesterState();
      notifyListeners();
      await _handleSemesterChange();
      return;
    }
    await _commitSettingsMutation(
      restore: () => _semesterStartDate = previousStartDate,
      persist: () => _storageService.writeSemesterStartDate(aligned),
      refreshReminders: true,
    );
  }

  Future<void> completeInitialSemesterStartDate(DateTime value) async {
    final aligned = _scheduleCalculator.alignToMonday(value);
    final previousStartDate = _semesterStartDate;
    _semesterStartDate = aligned;

    await _commitSettingsMutation(
      restore: () => _semesterStartDate = previousStartDate,
      persist: () async {
        final semesterId = _currentSemesterId;
        if (semesterId != null) {
          await _storageService.initializeExistingSemester(
            semesterId,
            startDate: aligned,
          );
        } else {
          await _storageService.writeSemesterStartDate(aligned);
        }
      },
    );
    _reloadSemesterState();
    notifyListeners();
    await _handleSemesterChange();
  }

  Future<bool> initializeCurrentSemesterFromAcademicImport(
    DateTime startDate,
  ) async {
    if (isCurrentSemesterInitialized) {
      return false;
    }

    final aligned = _scheduleCalculator.alignToMonday(startDate);
    final previousStartDate = _semesterStartDate;
    _semesterStartDate = aligned;

    await _commitSettingsMutation(
      restore: () => _semesterStartDate = previousStartDate,
      persist: () async {
        final semesterId = _currentSemesterId;
        if (semesterId != null) {
          await _storageService.initializeExistingSemester(
            semesterId,
            startDate: aligned,
          );
        } else {
          await _storageService.writeSemesterStartDate(aligned);
        }
      },
    );

    _reloadSemesterState();
    notifyListeners();
    await _handleSemesterChange();
    return true;
  }

  Future<void> updateTotalWeeks(int value) async {
    final safeValue = value.clamp(15, 30).toInt();
    if (safeValue == _totalWeeks) {
      return;
    }

    final previousTotalWeeks = _totalWeeks;
    _totalWeeks = safeValue;
    await _commitSettingsMutation(
      restore: () => _totalWeeks = previousTotalWeeks,
      persist: () => _storageService.writeTotalWeeks(safeValue),
      refreshReminders: true,
    );
  }

  Future<SettingsActionResult> updateReminderAdvanceMinutes(int value) async {
    final safeValue = value.clamp(0, _maxCourseReminderAdvanceMinutes).toInt();
    if (safeValue == _reminderAdvanceMinutes) {
      return SettingsActionResult.success();
    }

    if (safeValue > 0) {
      final notifOk = await _permissionService.ensureNotificationPermission();
      if (!notifOk) {
        return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
      }
    }

    final snapshot = _reminderSnapshot();
    _reminderAdvanceMinutes = safeValue;
    await _commitSettingsMutation(
      restore: () => _restoreReminderSnapshot(snapshot),
      persist: () => _storageService.writeReminderAdvanceMinutes(safeValue),
      compensate: () => _persistReminderSnapshot(snapshot),
      refreshReminders: true,
    );
    return SettingsActionResult.success();
  }

  Future<SettingsActionResult> toggleCourseReminder(bool value) async {
    if (!value) {
      if (_reminderAdvanceMinutes == 0 &&
          !_courseReminderPersistentDisplayEnabled) {
        return SettingsActionResult.success();
      }
      final snapshot = _reminderSnapshot();
      _reminderAdvanceMinutes = 0;
      _courseReminderPersistentDisplayEnabled = false;
      await _commitSettingsMutation(
        restore: () => _restoreReminderSnapshot(snapshot),
        persist: () async {
          await _storageService.writeReminderAdvanceMinutes(0);
          await _storageService.writeCourseReminderPersistentDisplayEnabled(
            false,
          );
        },
        compensate: () => _persistReminderSnapshot(snapshot),
        refreshReminders: true,
      );
      return SettingsActionResult.success();
    }
    if (_reminderAdvanceMinutes > 0) {
      return SettingsActionResult.success();
    }
    return updateReminderAdvanceMinutes(10);
  }

  Future<SettingsActionResult> updateCourseReminderStyle(
    CourseReminderStyle style,
  ) async {
    final notifOk = await _permissionService.ensureNotificationPermission();
    if (!notifOk) {
      return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
    }

    switch (style) {
      case CourseReminderStyle.singleNotification:
        if (!_courseReminderPersistentDisplayEnabled &&
            _reminderAdvanceMinutes > 0) {
          return SettingsActionResult.success();
        }
        final snapshot = _reminderSnapshot();
        _courseReminderPersistentDisplayEnabled = false;
        if (_reminderAdvanceMinutes == 0) {
          _reminderAdvanceMinutes = 10;
        }
        await _commitSettingsMutation(
          restore: () => _restoreReminderSnapshot(snapshot),
          persist: () async {
            await _storageService.writeCourseReminderPersistentDisplayEnabled(
              false,
            );
            if (snapshot.reminderAdvanceMinutes != _reminderAdvanceMinutes) {
              await _storageService.writeReminderAdvanceMinutes(
                _reminderAdvanceMinutes,
              );
            }
          },
          compensate: () => _persistReminderSnapshot(snapshot),
          refreshReminders: true,
        );
        return SettingsActionResult.success();
      case CourseReminderStyle.persistentDisplay:
        if (_courseReminderPersistentDisplayEnabled) {
          return SettingsActionResult.success();
        }
        final snapshot = _reminderSnapshot();
        _courseReminderPersistentDisplayEnabled = true;
        await _commitSettingsMutation(
          restore: () => _restoreReminderSnapshot(snapshot),
          persist: () =>
              _storageService.writeCourseReminderPersistentDisplayEnabled(true),
          compensate: () => _persistReminderSnapshot(snapshot),
          refreshReminders: true,
        );
        return SettingsActionResult.success();
    }
  }

  Future<SettingsActionResult> updateEventReminderAdvanceMinutes(
    int value,
  ) async {
    final safeValue = value.clamp(0, _maxEventReminderAdvanceMinutes).toInt();
    if (safeValue == _eventReminderAdvanceMinutes) {
      return SettingsActionResult.success();
    }

    if (safeValue > 0) {
      final notifOk = await _permissionService.ensureNotificationPermission();
      if (!notifOk) {
        return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
      }
    }

    final snapshot = _reminderSnapshot();
    _eventReminderAdvanceMinutes = safeValue;
    await _commitSettingsMutation(
      restore: () => _restoreReminderSnapshot(snapshot),
      persist: () =>
          _storageService.writeEventReminderAdvanceMinutes(safeValue),
      compensate: () => _persistReminderSnapshot(snapshot),
      refreshReminders: true,
    );
    return SettingsActionResult.success();
  }

  Future<void> updateAutoMuteEnabled(
    bool value, {
    bool fromUserAction = false,
  }) async {
    if (!fromUserAction) {
      return;
    }

    if (value == _autoMuteEnabled) {
      return;
    }

    final snapshot = _reminderSnapshot();
    _autoMuteEnabled = value;
    await _commitSettingsMutation(
      restore: () => _restoreReminderSnapshot(snapshot),
      persist: () => _storageService.writeAutoMuteEnabled(value),
      compensate: () => _persistReminderSnapshot(snapshot),
      refreshReminders: true,
    );
  }

  Future<SettingsActionResult> toggleAutoMuteWithCheck(bool value) async {
    if (!value) {
      await updateAutoMuteEnabled(false, fromUserAction: true);
      return SettingsActionResult.success();
    }

    final notifOk = await _permissionService.ensureNotificationPermission();
    if (!notifOk) {
      return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
    }

    await updateAutoMuteEnabled(true, fromUserAction: true);
    return SettingsActionResult.success();
  }

  Future<bool> ensureDndPermission() =>
      _permissionService.ensureDndPermission();

  Future<bool> ensureNotificationPermission() =>
      _permissionService.ensureNotificationPermission();

  Future<bool> ensureSoundModePermission() =>
      _permissionService.ensureSoundModePermission();

  Future<void> openAppOrAlarmSettings() async {
    await _permissionService.openAppOrAlarmSettings();
  }

  Future<void> openSystemDndSettings() async {
    await _permissionService.openSystemDndSettings();
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _permissionService.openBatteryOptimizationSettings();
  }

  Future<void> _refreshReminders() async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) {
      return;
    }

    await scheduler();
  }

  Future<void> _refreshRemindersAfterPersistence() async {
    try {
      await _refreshReminders();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SettingsReminderRefreshException(error, stackTrace),
        stackTrace,
      );
    }
  }

  Future<void> _handleSemesterChange() async {
    final handler = _semesterChangeHandler;
    if (handler == null) {
      await _refreshReminders();
      return;
    }

    await handler();
  }

  Future<void> _commitSettingsMutation({
    required VoidCallback restore,
    required Future<void> Function() persist,
    Future<void> Function()? compensate,
    bool refreshReminders = false,
  }) async {
    notifyListeners();
    try {
      await persist();
    } catch (error, stackTrace) {
      restore();
      try {
        await compensate?.call();
      } catch (compensationError) {
        debugPrint(
          '[SettingsProvider] Failed to compensate persisted settings: '
          '$compensationError',
        );
      }
      notifyListeners();
      Error.throwWithStackTrace(error, stackTrace);
    }
    if (refreshReminders) {
      await _refreshRemindersAfterPersistence();
    }
  }

  _ThemeSettingsSnapshot _themeSnapshot() {
    return _ThemeSettingsSnapshot(
      appThemeMode: _appThemeMode,
      themePaletteId: _themePaletteId,
      customThemePrimaryValue: _customThemePrimaryValue,
      customThemeAccentValue: _customThemeAccentValue,
    );
  }

  void _restoreThemeSnapshot(_ThemeSettingsSnapshot snapshot) {
    _appThemeMode = snapshot.appThemeMode;
    _themePaletteId = snapshot.themePaletteId;
    _customThemePrimaryValue = snapshot.customThemePrimaryValue;
    _customThemeAccentValue = snapshot.customThemeAccentValue;
  }

  Future<void> _persistThemeSnapshot(_ThemeSettingsSnapshot snapshot) async {
    await _storageService.writeAppThemeMode(snapshot.appThemeMode);
    await _storageService.writeThemePaletteId(snapshot.themePaletteId);
    await _storageService.writeCustomThemePrimaryValue(
      snapshot.customThemePrimaryValue,
    );
    await _storageService.writeCustomThemeAccentValue(
      snapshot.customThemeAccentValue,
    );
  }

  _PeriodSettingsSnapshot _periodSnapshot() {
    return _PeriodSettingsSnapshot(
      classDuration: _classDuration,
      shortBreak: _shortBreak,
      bigBreakEnabled: _bigBreakEnabled,
      bigBreak: _bigBreak,
      bigBreakAfterPeriods: List<int>.of(_bigBreakAfterPeriods),
      morningStartTime: _morningStartTime,
      morningClasses: _morningClasses,
      afternoonStartTime: _afternoonStartTime,
      afternoonClasses: _afternoonClasses,
      eveningStartTime: _eveningStartTime,
      eveningClasses: _eveningClasses,
      morningPeriodStartTimes: List<String>.of(_morningPeriodStartTimes),
      afternoonPeriodStartTimes: List<String>.of(_afternoonPeriodStartTimes),
      eveningPeriodStartTimes: List<String>.of(_eveningPeriodStartTimes),
    );
  }

  void _restorePeriodSnapshot(_PeriodSettingsSnapshot snapshot) {
    _classDuration = snapshot.classDuration;
    _shortBreak = snapshot.shortBreak;
    _bigBreakEnabled = snapshot.bigBreakEnabled;
    _bigBreak = snapshot.bigBreak;
    _bigBreakAfterPeriods = List<int>.of(snapshot.bigBreakAfterPeriods);
    _morningStartTime = snapshot.morningStartTime;
    _morningClasses = snapshot.morningClasses;
    _afternoonStartTime = snapshot.afternoonStartTime;
    _afternoonClasses = snapshot.afternoonClasses;
    _eveningStartTime = snapshot.eveningStartTime;
    _eveningClasses = snapshot.eveningClasses;
    _morningPeriodStartTimes = List<String>.of(
      snapshot.morningPeriodStartTimes,
    );
    _afternoonPeriodStartTimes = List<String>.of(
      snapshot.afternoonPeriodStartTimes,
    );
    _eveningPeriodStartTimes = List<String>.of(
      snapshot.eveningPeriodStartTimes,
    );
  }

  Future<void> _persistPeriodSnapshot(_PeriodSettingsSnapshot snapshot) async {
    await _storageService.writeClassDuration(snapshot.classDuration);
    await _storageService.writeShortBreak(snapshot.shortBreak);
    await _storageService.writeBigBreakEnabled(snapshot.bigBreakEnabled);
    await _storageService.writeBigBreak(snapshot.bigBreak);
    await _storageService.writeBigBreakAfterPeriods(
      snapshot.bigBreakAfterPeriods,
    );
    await _storageService.writeMorningClasses(snapshot.morningClasses);
    await _storageService.writeAfternoonClasses(snapshot.afternoonClasses);
    await _storageService.writeEveningClasses(snapshot.eveningClasses);
    await _storageService.writeMorningPeriodStartTimes(
      snapshot.morningPeriodStartTimes,
    );
    await _storageService.writeAfternoonPeriodStartTimes(
      snapshot.afternoonPeriodStartTimes,
    );
    await _storageService.writeEveningPeriodStartTimes(
      snapshot.eveningPeriodStartTimes,
    );
    await _storageService.writeMorningStartTime(snapshot.morningStartTime);
    await _storageService.writeAfternoonStartTime(snapshot.afternoonStartTime);
    await _storageService.writeEveningStartTime(snapshot.eveningStartTime);
  }

  _ReminderSettingsSnapshot _reminderSnapshot() {
    return _ReminderSettingsSnapshot(
      reminderAdvanceMinutes: _reminderAdvanceMinutes,
      eventReminderAdvanceMinutes: _eventReminderAdvanceMinutes,
      autoMuteEnabled: _autoMuteEnabled,
      courseReminderPersistentDisplayEnabled:
          _courseReminderPersistentDisplayEnabled,
    );
  }

  void _restoreReminderSnapshot(_ReminderSettingsSnapshot snapshot) {
    _reminderAdvanceMinutes = snapshot.reminderAdvanceMinutes;
    _eventReminderAdvanceMinutes = snapshot.eventReminderAdvanceMinutes;
    _autoMuteEnabled = snapshot.autoMuteEnabled;
    _courseReminderPersistentDisplayEnabled =
        snapshot.courseReminderPersistentDisplayEnabled;
  }

  Future<void> _persistReminderSnapshot(
    _ReminderSettingsSnapshot snapshot,
  ) async {
    await _storageService.writeReminderAdvanceMinutes(
      snapshot.reminderAdvanceMinutes,
    );
    await _storageService.writeEventReminderAdvanceMinutes(
      snapshot.eventReminderAdvanceMinutes,
    );
    await _storageService.writeAutoMuteEnabled(snapshot.autoMuteEnabled);
    await _storageService.writeCourseReminderPersistentDisplayEnabled(
      snapshot.courseReminderPersistentDisplayEnabled,
    );
  }

  int _classCountFor(ClassDayPeriod period) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _morningClasses;
      case ClassDayPeriod.afternoon:
        return _afternoonClasses;
      case ClassDayPeriod.evening:
        return _eveningClasses;
    }
  }

  void _setClassCount(ClassDayPeriod period, int value) {
    switch (period) {
      case ClassDayPeriod.morning:
        _morningClasses = value;
      case ClassDayPeriod.afternoon:
        _afternoonClasses = value;
      case ClassDayPeriod.evening:
        _eveningClasses = value;
    }
  }

  List<String> _startTimesFor(ClassDayPeriod period) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _morningPeriodStartTimes;
      case ClassDayPeriod.afternoon:
        return _afternoonPeriodStartTimes;
      case ClassDayPeriod.evening:
        return _eveningPeriodStartTimes;
    }
  }

  List<String>? _storedStartTimesFor(ClassDayPeriod period) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _storageService.readMorningPeriodStartTimes();
      case ClassDayPeriod.afternoon:
        return _storageService.readAfternoonPeriodStartTimes();
      case ClassDayPeriod.evening:
        return _storageService.readEveningPeriodStartTimes();
    }
  }

  void _setStartTimes(ClassDayPeriod period, List<String> values) {
    switch (period) {
      case ClassDayPeriod.morning:
        _morningPeriodStartTimes = values;
      case ClassDayPeriod.afternoon:
        _afternoonPeriodStartTimes = values;
      case ClassDayPeriod.evening:
        _eveningPeriodStartTimes = values;
    }
  }

  String _fallbackStartTimeFor(ClassDayPeriod period) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _morningStartTime;
      case ClassDayPeriod.afternoon:
        return _afternoonStartTime;
      case ClassDayPeriod.evening:
        return _eveningStartTime;
    }
  }

  void _setLegacySessionStartTime(ClassDayPeriod period, String value) {
    switch (period) {
      case ClassDayPeriod.morning:
        _morningStartTime = value;
      case ClassDayPeriod.afternoon:
        _afternoonStartTime = value;
      case ClassDayPeriod.evening:
        _eveningStartTime = value;
    }
  }

  Future<void> _persistClassCount(ClassDayPeriod period, int value) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _storageService.writeMorningClasses(value);
      case ClassDayPeriod.afternoon:
        return _storageService.writeAfternoonClasses(value);
      case ClassDayPeriod.evening:
        return _storageService.writeEveningClasses(value);
    }
  }

  Future<void> _persistStartTimes(ClassDayPeriod period, List<String> values) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _storageService.writeMorningPeriodStartTimes(values);
      case ClassDayPeriod.afternoon:
        return _storageService.writeAfternoonPeriodStartTimes(values);
      case ClassDayPeriod.evening:
        return _storageService.writeEveningPeriodStartTimes(values);
    }
  }

  Future<void> _persistAllSessionStartTimes() async {
    await _storageService.writeMorningPeriodStartTimes(
      _morningPeriodStartTimes,
    );
    await _storageService.writeAfternoonPeriodStartTimes(
      _afternoonPeriodStartTimes,
    );
    await _storageService.writeEveningPeriodStartTimes(
      _eveningPeriodStartTimes,
    );
  }

  Future<void> _persistLegacySessionStartTime(
    ClassDayPeriod period,
    String value,
  ) {
    switch (period) {
      case ClassDayPeriod.morning:
        return _storageService.writeMorningStartTime(value);
      case ClassDayPeriod.afternoon:
        return _storageService.writeAfternoonStartTime(value);
      case ClassDayPeriod.evening:
        return _storageService.writeEveningStartTime(value);
    }
  }

  void _reflowAllSessionStartTimes() {
    _morningPeriodStartTimes = _reflowSessionStartTimes(
      ClassDayPeriod.morning,
      _morningPeriodStartTimes,
    );
    _afternoonPeriodStartTimes = _reflowSessionStartTimes(
      ClassDayPeriod.afternoon,
      _afternoonPeriodStartTimes,
    );
    _eveningPeriodStartTimes = _reflowSessionStartTimes(
      ClassDayPeriod.evening,
      _eveningPeriodStartTimes,
    );
  }

  List<String> _reflowSessionStartTimes(
    ClassDayPeriod period,
    List<String> values,
  ) {
    if (values.length <= 1) {
      return values;
    }

    final updated = <String>[values.first];
    while (updated.length < values.length) {
      updated.add(_nextStartTime(period, updated.length - 1, updated.last));
    }
    return updated;
  }

  void _reloadSemesterState() {
    _semesters = _storageService.loadSemesters();
    _currentSemesterId = _storageService.currentSemesterId;
    _pixelsPerMinute = _storageService.readPixelsPerMinute(
      fallback: _defaultPixelsPerMinute,
    );
    _classDuration = _storageService.readClassDuration(
      fallback: _defaultClassDuration,
    );
    _shortBreak = _storageService.readShortBreak(fallback: _defaultShortBreak);
    _bigBreakEnabled = _storageService.readBigBreakEnabled(
      fallback: _defaultBigBreakEnabled,
    );
    _bigBreak = _storageService.readBigBreak(fallback: _defaultBigBreak);
    _morningStartTime = _storageService.readMorningStartTime(
      fallback: _defaultMorningStartTime,
    );
    _morningClasses = _storageService.readMorningClasses(
      fallback: _defaultMorningClasses,
    );
    _afternoonStartTime = _storageService.readAfternoonStartTime(
      fallback: _defaultAfternoonStartTime,
    );
    _afternoonClasses = _storageService.readAfternoonClasses(
      fallback: _defaultAfternoonClasses,
    );
    _eveningStartTime = _storageService.readEveningStartTime(
      fallback: _defaultEveningStartTime,
    );
    _eveningClasses = _storageService.readEveningClasses(
      fallback: _defaultEveningClasses,
    );
    _bigBreakAfterPeriods = _restoreBigBreakAfterPeriodsFromStorage(
      _storageService,
    );
    _morningPeriodStartTimes = _restoreSessionStartTimesFromState(
      ClassDayPeriod.morning,
    );
    _afternoonPeriodStartTimes = _restoreSessionStartTimesFromState(
      ClassDayPeriod.afternoon,
    );
    _eveningPeriodStartTimes = _restoreSessionStartTimesFromState(
      ClassDayPeriod.evening,
    );
    _semesterStartDate = _restoreSemesterStartDate(
      storageService: _storageService,
      scheduleCalculator: _scheduleCalculator,
    );
    _totalWeeks = _storageService.readTotalWeeks(fallback: _defaultTotalWeeks);
    _timetableToolbarGuideConfirmed = _storageService
        .readTimetableToolbarGuideConfirmed(fallback: false);
    _timetableMenuGuideConfirmed = _storageService
        .readTimetableMenuGuideConfirmed(
          fallback: _timetableToolbarGuideConfirmed,
        );
    _importWebViewGuideConfirmed = _storageService
        .readImportWebViewGuideConfirmed(fallback: false);
  }

  Semester? _semesterById(String semesterId) {
    for (final semester in _semesters) {
      if (semester.id == semesterId) {
        return semester;
      }
    }
    return null;
  }

  TimeOfDay _parseTime(String value, {String fallback = '08:00'}) {
    final parts = value.split(':');
    final fallbackParts = fallback.split(':');
    final fallbackHour = fallbackParts.isNotEmpty
        ? int.tryParse(fallbackParts[0])
        : null;
    final fallbackMinute = fallbackParts.length > 1
        ? int.tryParse(fallbackParts[1])
        : null;
    final parsedHour = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final parsedMinute = parts.length == 2 ? int.tryParse(parts[1]) : null;
    final hasValidValue =
        parsedHour != null &&
        parsedMinute != null &&
        parsedHour >= 0 &&
        parsedHour <= 23 &&
        parsedMinute >= 0 &&
        parsedMinute <= 59;
    return TimeOfDay(
      hour: (hasValidValue ? parsedHour : fallbackHour ?? 8)
          .clamp(0, 23)
          .toInt(),
      minute: (hasValidValue ? parsedMinute : fallbackMinute ?? 0)
          .clamp(0, 59)
          .toInt(),
    );
  }

  List<TimeOfDay> _parseTimeList(List<String> values) {
    return values.map(_parseTime).toList(growable: false);
  }

  List<ClockTime> _clockTimesFromStrings(List<String> values) {
    return values.map(ClockTime.fromString).toList(growable: false);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatClockTime(ClockTime time) {
    return time.format24Hour();
  }

  String _nextStartTime(
    ClassDayPeriod period,
    int previousIndex,
    String previousStartTime,
  ) {
    final previous = ClockTime.fromString(previousStartTime);
    final previousPeriodNumber = _firstPeriodNumberFor(period) + previousIndex;
    final nextMinutes =
        previous.toMinutes() +
        _classDuration +
        _breakAfterPeriod(
          previousPeriodNumber: previousPeriodNumber,
          shortBreak: _shortBreak,
          bigBreakEnabled: _bigBreakEnabled,
          bigBreak: _bigBreak,
          bigBreakAfterPeriods: _bigBreakAfterPeriods,
        );
    return _formatClockTime(ClockTime.fromMinutes(nextMinutes));
  }

  int _firstPeriodNumberFor(ClassDayPeriod period) {
    switch (period) {
      case ClassDayPeriod.morning:
        return 1;
      case ClassDayPeriod.afternoon:
        return _morningClasses + 1;
      case ClassDayPeriod.evening:
        return _morningClasses + _afternoonClasses + 1;
    }
  }

  List<String> _resizeSessionStartTimes(
    ClassDayPeriod period,
    List<String> currentValues,
    int count,
    String fallbackStartTime,
  ) {
    final safeCount = count.clamp(0, 12).toInt();
    if (safeCount == 0) {
      return <String>[];
    }

    final values = currentValues.where(_isValidTimeString).toList();
    if (values.isEmpty) {
      values.add(
        _isValidTimeString(fallbackStartTime) ? fallbackStartTime : '08:00',
      );
    }

    while (values.length < safeCount) {
      values.add(_nextStartTime(period, values.length - 1, values.last));
    }
    if (values.length > safeCount) {
      return values.take(safeCount).toList();
    }
    return values;
  }

  bool _isValidTimeString(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  List<String> _restoreSessionStartTimesFromState(ClassDayPeriod period) {
    return _restoreSessionStartTimes(
      storedValues: _storedStartTimesFor(period),
      fallbackStartTime: _fallbackStartTimeFor(period),
      count: _classCountFor(period),
      firstPeriodNumber: _firstPeriodNumberFor(period),
      classDuration: _classDuration,
      shortBreak: _shortBreak,
      bigBreakEnabled: _bigBreakEnabled,
      bigBreak: _bigBreak,
      bigBreakAfterPeriods: _bigBreakAfterPeriods,
    );
  }

  static List<String> _restoreSessionStartTimesFromStorage(
    StorageService storageService,
    ClassDayPeriod period,
  ) {
    final morningClasses = storageService.readMorningClasses(
      fallback: _defaultMorningClasses,
    );
    final afternoonClasses = storageService.readAfternoonClasses(
      fallback: _defaultAfternoonClasses,
    );
    final eveningClasses = storageService.readEveningClasses(
      fallback: _defaultEveningClasses,
    );
    final totalClassPeriods =
        morningClasses + afternoonClasses + eveningClasses;
    final bigBreakAfterPeriods = _restoreBigBreakAfterPeriodsFromStorage(
      storageService,
    );

    return _restoreSessionStartTimes(
      storedValues: switch (period) {
        ClassDayPeriod.morning => storageService.readMorningPeriodStartTimes(),
        ClassDayPeriod.afternoon =>
          storageService.readAfternoonPeriodStartTimes(),
        ClassDayPeriod.evening => storageService.readEveningPeriodStartTimes(),
      },
      fallbackStartTime: switch (period) {
        ClassDayPeriod.morning => storageService.readMorningStartTime(
          fallback: _defaultMorningStartTime,
        ),
        ClassDayPeriod.afternoon => storageService.readAfternoonStartTime(
          fallback: _defaultAfternoonStartTime,
        ),
        ClassDayPeriod.evening => storageService.readEveningStartTime(
          fallback: _defaultEveningStartTime,
        ),
      },
      count: switch (period) {
        ClassDayPeriod.morning => morningClasses,
        ClassDayPeriod.afternoon => afternoonClasses,
        ClassDayPeriod.evening => eveningClasses,
      },
      firstPeriodNumber: _firstPeriodNumberForCounts(
        period,
        morningClasses: morningClasses,
        afternoonClasses: afternoonClasses,
      ),
      classDuration: storageService.readClassDuration(
        fallback: _defaultClassDuration,
      ),
      shortBreak: storageService.readShortBreak(fallback: _defaultShortBreak),
      bigBreakEnabled: storageService.readBigBreakEnabled(
        fallback: _defaultBigBreakEnabled,
      ),
      bigBreak: storageService.readBigBreak(fallback: _defaultBigBreak),
      bigBreakAfterPeriods: _sanitizeBigBreakAfterPeriods(
        bigBreakAfterPeriods,
        totalClassPeriods,
      ),
    );
  }

  static List<String> _restoreSessionStartTimes({
    required List<String>? storedValues,
    required String fallbackStartTime,
    required int count,
    required int firstPeriodNumber,
    required int classDuration,
    required int shortBreak,
    required bool bigBreakEnabled,
    required int bigBreak,
    required Iterable<int> bigBreakAfterPeriods,
  }) {
    final safeCount = count.clamp(0, 12).toInt();
    if (safeCount == 0) {
      return <String>[];
    }

    final values = (storedValues ?? <String>[])
        .where(_isValidStoredTimeString)
        .toList();
    if (values.isEmpty) {
      values.add(
        _isValidStoredTimeString(fallbackStartTime)
            ? fallbackStartTime
            : _defaultMorningStartTime,
      );
    }

    while (values.length < safeCount) {
      values.add(
        _nextStoredStartTime(
          values.last,
          firstPeriodNumber: firstPeriodNumber,
          previousIndex: values.length - 1,
          classDuration: classDuration,
          shortBreak: shortBreak,
          bigBreakEnabled: bigBreakEnabled,
          bigBreak: bigBreak,
          bigBreakAfterPeriods: bigBreakAfterPeriods,
        ),
      );
    }
    if (values.length > safeCount) {
      return values.take(safeCount).toList();
    }
    return values;
  }

  static String _nextStoredStartTime(
    String previousStartTime, {
    required int firstPeriodNumber,
    required int previousIndex,
    required int classDuration,
    required int shortBreak,
    required bool bigBreakEnabled,
    required int bigBreak,
    required Iterable<int> bigBreakAfterPeriods,
  }) {
    final previous = ClockTime.fromString(previousStartTime);
    final previousPeriodNumber = firstPeriodNumber + previousIndex;
    final nextMinutes =
        previous.toMinutes() +
        classDuration +
        _breakAfterPeriod(
          previousPeriodNumber: previousPeriodNumber,
          shortBreak: shortBreak,
          bigBreakEnabled: bigBreakEnabled,
          bigBreak: bigBreak,
          bigBreakAfterPeriods: bigBreakAfterPeriods,
        );
    return ClockTime.fromMinutes(nextMinutes).format24Hour();
  }

  static int _breakAfterPeriod({
    required int previousPeriodNumber,
    required int shortBreak,
    required bool bigBreakEnabled,
    required int bigBreak,
    required Iterable<int> bigBreakAfterPeriods,
  }) {
    final usesBigBreak =
        bigBreakEnabled && bigBreakAfterPeriods.contains(previousPeriodNumber);
    return usesBigBreak ? bigBreak : shortBreak;
  }

  static int _firstPeriodNumberForCounts(
    ClassDayPeriod period, {
    required int morningClasses,
    required int afternoonClasses,
  }) {
    switch (period) {
      case ClassDayPeriod.morning:
        return 1;
      case ClassDayPeriod.afternoon:
        return morningClasses + 1;
      case ClassDayPeriod.evening:
        return morningClasses + afternoonClasses + 1;
    }
  }

  static List<int> _restoreBigBreakAfterPeriodsFromStorage(
    StorageService storageService,
  ) {
    final morningClasses = storageService.readMorningClasses(
      fallback: _defaultMorningClasses,
    );
    final afternoonClasses = storageService.readAfternoonClasses(
      fallback: _defaultAfternoonClasses,
    );
    final eveningClasses = storageService.readEveningClasses(
      fallback: _defaultEveningClasses,
    );
    final totalClassPeriods =
        morningClasses + afternoonClasses + eveningClasses;
    return _sanitizeBigBreakAfterPeriods(
      storageService.readBigBreakAfterPeriods() ??
          _defaultBigBreakAfterPeriods(
            morningClasses: morningClasses,
            afternoonClasses: afternoonClasses,
            totalClassPeriods: totalClassPeriods,
          ),
      totalClassPeriods,
    );
  }

  static List<int> _defaultBigBreakAfterPeriods({
    required int morningClasses,
    required int afternoonClasses,
    required int totalClassPeriods,
  }) {
    final values = <int>[];
    if (morningClasses >= 3) {
      values.add(2);
    }
    if (afternoonClasses >= 3) {
      values.add(morningClasses + 2);
    }
    return _sanitizeBigBreakAfterPeriods(values, totalClassPeriods);
  }

  static List<int> _sanitizeBigBreakAfterPeriods(
    Iterable<int> values,
    int totalClassPeriods,
  ) {
    final maxPeriod = totalClassPeriods - 1;
    if (maxPeriod < 1) {
      return <int>[];
    }
    final unique =
        values
            .where((value) => value >= 1 && value <= maxPeriod)
            .toSet()
            .toList()
          ..sort();
    return unique;
  }

  static bool _listEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  static bool _isValidStoredTimeString(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  static DateTime _restoreSemesterStartDate({
    required StorageService storageService,
    required ScheduleCalculator scheduleCalculator,
  }) {
    final storedValue = storageService.readSemesterStartDate();
    if (storedValue == null) {
      return scheduleCalculator.defaultSemesterStartDate();
    }
    return scheduleCalculator.alignToMonday(storedValue);
  }
}

class _ThemeSettingsSnapshot {
  const _ThemeSettingsSnapshot({
    required this.appThemeMode,
    required this.themePaletteId,
    required this.customThemePrimaryValue,
    required this.customThemeAccentValue,
  });

  final AppThemeMode appThemeMode;
  final String themePaletteId;
  final int customThemePrimaryValue;
  final int customThemeAccentValue;
}

class _PeriodSettingsSnapshot {
  const _PeriodSettingsSnapshot({
    required this.classDuration,
    required this.shortBreak,
    required this.bigBreakEnabled,
    required this.bigBreak,
    required this.bigBreakAfterPeriods,
    required this.morningStartTime,
    required this.morningClasses,
    required this.afternoonStartTime,
    required this.afternoonClasses,
    required this.eveningStartTime,
    required this.eveningClasses,
    required this.morningPeriodStartTimes,
    required this.afternoonPeriodStartTimes,
    required this.eveningPeriodStartTimes,
  });

  final int classDuration;
  final int shortBreak;
  final bool bigBreakEnabled;
  final int bigBreak;
  final List<int> bigBreakAfterPeriods;
  final String morningStartTime;
  final int morningClasses;
  final String afternoonStartTime;
  final int afternoonClasses;
  final String eveningStartTime;
  final int eveningClasses;
  final List<String> morningPeriodStartTimes;
  final List<String> afternoonPeriodStartTimes;
  final List<String> eveningPeriodStartTimes;
}

class _ReminderSettingsSnapshot {
  const _ReminderSettingsSnapshot({
    required this.reminderAdvanceMinutes,
    required this.eventReminderAdvanceMinutes,
    required this.autoMuteEnabled,
    required this.courseReminderPersistentDisplayEnabled,
  });

  final int reminderAdvanceMinutes;
  final int eventReminderAdvanceMinutes;
  final bool autoMuteEnabled;
  final bool courseReminderPersistentDisplayEnabled;
}
