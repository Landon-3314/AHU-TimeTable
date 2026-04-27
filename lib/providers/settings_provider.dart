import 'package:flutter/material.dart';

import '../app_localizations.dart';
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
       _bigBreak = storageService.readBigBreak(fallback: _defaultBigBreak),
       _bigBreakAfterPeriod = storageService.readBigBreakAfterPeriod(
         fallback: _defaultBigBreakAfterPeriod,
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
       _languageCode = storageService.readLanguageCode(fallback: 'zh'),
       _autoMuteEnabled = storageService.readAutoMuteEnabled(fallback: false),
       _semesters = storageService.loadSemesters(),
       _currentSemesterId = storageService.currentSemesterId,
       _backgroundServiceEnabled = storageService.readBackgroundServiceEnabled(
         fallback: false,
       );

  static const double _defaultPixelsPerMinute = 1.2;
  static const int _defaultClassDuration = 45;
  static const int _defaultShortBreak = 5;
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

  final StorageService _storageService;
  final ScheduleCalculator _scheduleCalculator;
  final PermissionService _permissionService;

  double _pixelsPerMinute;
  int _classDuration;
  int _shortBreak;
  int _bigBreak;
  int _bigBreakAfterPeriod;
  String _morningStartTime;
  int _morningClasses;
  String _afternoonStartTime;
  int _afternoonClasses;
  String _eveningStartTime;
  int _eveningClasses;
  DateTime _semesterStartDate;
  int _totalWeeks;
  int _reminderAdvanceMinutes;
  int _eventReminderAdvanceMinutes;
  String _languageCode;
  bool _autoMuteEnabled;
  bool _backgroundServiceEnabled;
  List<Semester> _semesters;
  String? _currentSemesterId;
  Future<void> Function()? _reminderScheduler;

  double get pixelsPerMinute => _pixelsPerMinute;
  int get classDuration => _classDuration;
  int get shortBreak => _shortBreak;
  int get bigBreak => _bigBreak;
  int get bigBreakAfterPeriod => _bigBreakAfterPeriod;
  TimeOfDay get morningStartTime => _parseTime(_morningStartTime);
  int get morningClasses => _morningClasses;
  TimeOfDay get afternoonStartTime => _parseTime(_afternoonStartTime);
  int get afternoonClasses => _afternoonClasses;
  TimeOfDay get eveningStartTime => _parseTime(_eveningStartTime);
  int get eveningClasses => _eveningClasses;
  DateTime get semesterStartDate => _semesterStartDate;
  int get totalWeeks => _totalWeeks;
  int get reminderAdvanceMinutes => _reminderAdvanceMinutes;
  int get eventReminderAdvanceMinutes => _eventReminderAdvanceMinutes;
  String get languageCode => _languageCode;
  bool get autoMuteEnabled => _autoMuteEnabled;
  bool get backgroundServiceEnabled => _backgroundServiceEnabled;
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
  bool get courseReminderEnabled => _reminderAdvanceMinutes > 0;
  List<TimeSlot> get timeSlots => generateTimeSlots();
  String t(String key) => AppStrings.get(key, _languageCode);

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

    await _storageService.setCurrentSemesterId(semesterId);
    _reloadSemesterState();
    notifyListeners();
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
    _semesters = _storageService.loadSemesters();
    notifyListeners();
  }

  Future<void> initializeExistingSemesterAndSwitch(
    String semesterId, {
    required DateTime startDate,
  }) async {
    await initializeExistingSemester(semesterId, startDate: startDate);
    await _storageService.setCurrentSemesterId(semesterId);
    _reloadSemesterState();
    notifyListeners();
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
    return nextSemesterId;
  }

  Future<void> changeLanguage(String code) async {
    if (code == _languageCode) {
      return;
    }

    _languageCode = code;
    notifyListeners();
    await _storageService.writeLanguageCode(code);
  }

  List<TimeSlot> generateTimeSlots() {
    return _scheduleCalculator.generateTimeSlots(
      classDuration: _classDuration,
      shortBreak: _shortBreak,
      bigBreak: _bigBreak,
      bigBreakAfterPeriod: _bigBreakAfterPeriod,
      morningStartTime: ClockTime.fromString(_morningStartTime),
      morningClasses: _morningClasses,
      afternoonStartTime: ClockTime.fromString(_afternoonStartTime),
      afternoonClasses: _afternoonClasses,
      eveningStartTime: ClockTime.fromString(_eveningStartTime),
      eveningClasses: _eveningClasses,
    );
  }

  Future<void> updatePixelsPerMinute(double value) async {
    if (value == _pixelsPerMinute) {
      return;
    }

    _pixelsPerMinute = value;
    notifyListeners();
    await _storageService.writePixelsPerMinute(value);
  }

  Future<void> updateClassDuration(int value) async {
    if (value == _classDuration) {
      return;
    }

    _classDuration = value;
    notifyListeners();
    await _storageService.writeClassDuration(value);
    await _refreshReminders();
  }

  Future<void> updateShortBreak(int value) async {
    if (value == _shortBreak) {
      return;
    }

    _shortBreak = value;
    notifyListeners();
    await _storageService.writeShortBreak(value);
    await _refreshReminders();
  }

  Future<void> updateBigBreak(int value) async {
    if (value == _bigBreak) {
      return;
    }

    _bigBreak = value;
    notifyListeners();
    await _storageService.writeBigBreak(value);
    await _refreshReminders();
  }

  Future<void> updateBigBreakAfterPeriod(int value) async {
    final safeValue = value.clamp(1, 6).toInt();
    if (safeValue == _bigBreakAfterPeriod) {
      return;
    }

    _bigBreakAfterPeriod = safeValue;
    notifyListeners();
    await _storageService.writeBigBreakAfterPeriod(safeValue);
    await _refreshReminders();
  }

  Future<void> updateMorningStartTime(TimeOfDay value) async {
    await _updateTime(
      currentValue: _morningStartTime,
      nextValue: value,
      apply: (formatted) => _morningStartTime = formatted,
      persist: _storageService.writeMorningStartTime,
    );
  }

  Future<void> updateMorningClasses(int value) async {
    if (value == _morningClasses) {
      return;
    }

    _morningClasses = value;
    notifyListeners();
    await _storageService.writeMorningClasses(value);
    await _refreshReminders();
  }

  Future<void> updateAfternoonStartTime(TimeOfDay value) async {
    await _updateTime(
      currentValue: _afternoonStartTime,
      nextValue: value,
      apply: (formatted) => _afternoonStartTime = formatted,
      persist: _storageService.writeAfternoonStartTime,
    );
  }

  Future<void> updateAfternoonClasses(int value) async {
    if (value == _afternoonClasses) {
      return;
    }

    _afternoonClasses = value;
    notifyListeners();
    await _storageService.writeAfternoonClasses(value);
    await _refreshReminders();
  }

  Future<void> updateEveningStartTime(TimeOfDay value) async {
    await _updateTime(
      currentValue: _eveningStartTime,
      nextValue: value,
      apply: (formatted) => _eveningStartTime = formatted,
      persist: _storageService.writeEveningStartTime,
    );
  }

  Future<void> updateEveningClasses(int value) async {
    if (value == _eveningClasses) {
      return;
    }

    _eveningClasses = value;
    notifyListeners();
    await _storageService.writeEveningClasses(value);
    await _refreshReminders();
  }

  Future<void> updateSemesterStartDate(DateTime value) async {
    final aligned = _scheduleCalculator.alignToMonday(value);
    if (_isSameDate(aligned, _semesterStartDate)) {
      return;
    }

    _semesterStartDate = aligned;
    notifyListeners();
    await _storageService.writeSemesterStartDate(aligned);
    if (!isCurrentSemesterInitialized) {
      final semesterId = _currentSemesterId;
      if (semesterId != null) {
        await _storageService.markSemesterInitialized(semesterId);
      }
      _semesters = _storageService.loadSemesters();
      notifyListeners();
    }
    await _refreshReminders();
  }

  Future<void> completeInitialSemesterStartDate(DateTime value) async {
    final aligned = _scheduleCalculator.alignToMonday(value);
    final dateChanged = !_isSameDate(aligned, _semesterStartDate);

    _semesterStartDate = aligned;

    await _storageService.writeSemesterStartDate(aligned);
    final semesterId = _currentSemesterId;
    if (semesterId != null) {
      await _storageService.markSemesterInitialized(semesterId);
    }
    _semesters = _storageService.loadSemesters();
    notifyListeners();
    if (dateChanged) {
      await _refreshReminders();
    }
  }

  Future<void> updateTotalWeeks(int value) async {
    final safeValue = value.clamp(15, 30).toInt();
    if (safeValue == _totalWeeks) {
      return;
    }

    _totalWeeks = safeValue;
    notifyListeners();
    await _storageService.writeTotalWeeks(safeValue);
    await _refreshReminders();
  }

  Future<SettingsActionResult> updateReminderAdvanceMinutes(int value) async {
    final safeValue = value.clamp(0, 1440).toInt();
    if (safeValue == _reminderAdvanceMinutes) {
      return SettingsActionResult.success();
    }

    if (safeValue > 0) {
      final notifOk = await _permissionService.ensureNotificationPermission();
      if (!notifOk) {
        return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
      }
      final alarmOk = await _permissionService.ensureExactAlarmPermission();
      if (!alarmOk) {
        return SettingsActionResult.failure('EXACT_ALARM_REQUIRED');
      }
    }

    _reminderAdvanceMinutes = safeValue;
    notifyListeners();
    await _storageService.writeReminderAdvanceMinutes(safeValue);
    await _refreshReminders();
    return SettingsActionResult.success();
  }

  Future<SettingsActionResult> toggleCourseReminder(bool value) async {
    if (!value) {
      return updateReminderAdvanceMinutes(0);
    }
    if (_reminderAdvanceMinutes > 0) {
      return SettingsActionResult.success();
    }
    return updateReminderAdvanceMinutes(10);
  }

  Future<SettingsActionResult> updateEventReminderAdvanceMinutes(
    int value,
  ) async {
    final safeValue = value.clamp(0, 1440).toInt();
    if (safeValue == _eventReminderAdvanceMinutes) {
      return SettingsActionResult.success();
    }

    if (safeValue > 0) {
      final notifOk = await _permissionService.ensureNotificationPermission();
      if (!notifOk) {
        return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
      }
      final alarmOk = await _permissionService.ensureExactAlarmPermission();
      if (!alarmOk) {
        return SettingsActionResult.failure('EXACT_ALARM_REQUIRED');
      }
    }

    _eventReminderAdvanceMinutes = safeValue;
    notifyListeners();
    await _storageService.writeEventReminderAdvanceMinutes(safeValue);
    await _refreshReminders();
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

    _autoMuteEnabled = value;
    notifyListeners();
    await _storageService.writeAutoMuteEnabled(value);
    await _refreshReminders();
  }

  Future<SettingsActionResult> toggleAutoMuteWithCheck(bool value) async {
    if (!value) {
      await updateAutoMuteEnabled(false, fromUserAction: true);
      return SettingsActionResult.success();
    }

    final alarmOk = await _permissionService.ensureExactAlarmPermission();
    if (!alarmOk) {
      return SettingsActionResult.failure('EXACT_ALARM_REQUIRED');
    }

    final dndOk = await _permissionService.ensureDndPermission();
    if (!dndOk) {
      return SettingsActionResult.failure('DND_PERMISSION_REQUIRED');
    }

    await updateAutoMuteEnabled(true, fromUserAction: true);
    return SettingsActionResult.success();
  }

  Future<SettingsActionResult> toggleBackgroundServiceWithCheck(
    bool value,
  ) async {
    if (!value) {
      if (!_backgroundServiceEnabled) {
        return SettingsActionResult.success();
      }
      _backgroundServiceEnabled = false;
      notifyListeners();
      await _storageService.writeBackgroundServiceEnabled(false);
      await _refreshReminders();
      return SettingsActionResult.success();
    }

    final notifOk = await _permissionService.ensureNotificationPermission();
    if (!notifOk) {
      return SettingsActionResult.failure('NOTIFICATION_REQUIRED');
    }

    if (_backgroundServiceEnabled) {
      return SettingsActionResult.success();
    }
    _backgroundServiceEnabled = true;
    notifyListeners();
    await _storageService.writeBackgroundServiceEnabled(true);
    await _refreshReminders();
    return SettingsActionResult.success();
  }

  Future<SettingsActionResult> toggleAutoMuteServiceSwitch(bool value) async {
    if (value) {
      final dndOk = await _permissionService.ensureDndPermission();
      if (!dndOk) {
        return SettingsActionResult.failure('DND_PERMISSION_REQUIRED');
      }
    }

    _autoMuteEnabled = value;
    _backgroundServiceEnabled = value;
    notifyListeners();
    await _storageService.writeAutoMuteEnabled(value);
    await _storageService.writeBackgroundServiceEnabled(value);
    await _refreshReminders();
    return SettingsActionResult.success();
  }

  Future<bool> ensureDndPermission() =>
      _permissionService.ensureDndPermission();

  Future<bool> ensureNotificationPermission() =>
      _permissionService.ensureNotificationPermission();

  Future<bool> ensureSoundModePermission() =>
      _permissionService.ensureSoundModePermission();

  Future<void> setAutoMuteServiceEnabled(bool value) async {
    if (_autoMuteEnabled == value && _backgroundServiceEnabled == value) {
      return;
    }
    _autoMuteEnabled = value;
    _backgroundServiceEnabled = value;
    notifyListeners();
    await _storageService.writeAutoMuteEnabled(value);
    await _storageService.writeBackgroundServiceEnabled(value);
    await _refreshReminders();
  }

  Future<void> openAppOrAlarmSettings() async {
    await _permissionService.openAppOrAlarmSettings();
  }

  Future<void> openSystemDndSettings() async {
    await _permissionService.openSystemDndSettings();
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _permissionService.openBatteryOptimizationSettings();
  }

  Future<void> _updateTime({
    required String currentValue,
    required TimeOfDay nextValue,
    required ValueChanged<String> apply,
    required Future<void> Function(String value) persist,
  }) async {
    final formatted = _formatTime(nextValue);
    if (formatted == currentValue) {
      return;
    }

    apply(formatted);
    notifyListeners();
    await persist(formatted);
    await _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) {
      return;
    }

    await scheduler();
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
    _bigBreak = _storageService.readBigBreak(fallback: _defaultBigBreak);
    _bigBreakAfterPeriod = _storageService.readBigBreakAfterPeriod(
      fallback: _defaultBigBreakAfterPeriod,
    );
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
    _semesterStartDate = _restoreSemesterStartDate(
      storageService: _storageService,
      scheduleCalculator: _scheduleCalculator,
    );
    _totalWeeks = _storageService.readTotalWeeks(fallback: _defaultTotalWeeks);
  }

  Semester? _semesterById(String semesterId) {
    for (final semester in _semesters) {
      if (semester.id == semesterId) {
        return semester;
      }
    }
    return null;
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
