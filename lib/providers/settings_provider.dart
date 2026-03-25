import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../app_localizations.dart';
import '../models/clock_time.dart';
import '../models/time_slot.dart';
import '../services/auto_mute_toggle_service.dart';
import '../services/schedule_calculator.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required StorageService storageService,
    ScheduleCalculator? scheduleCalculator,
    AutoMuteToggleService? autoMuteToggleService,
  }) : _storageService = storageService,
       _scheduleCalculator = scheduleCalculator ?? const ScheduleCalculator(),
       _autoMuteToggleService =
           autoMuteToggleService ?? AutoMuteToggleService(),
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
       _autoMuteEnabled = storageService.readAutoMuteEnabled(fallback: false);

  static const double _defaultPixelsPerMinute = 1.2;
  static const int _defaultClassDuration = 45;
  static const int _defaultShortBreak = 5;
  static const int _defaultBigBreak = 15;
  static const String _defaultMorningStartTime = '08:00';
  static const int _defaultMorningClasses = 5;
  static const String _defaultAfternoonStartTime = '14:00';
  static const int _defaultAfternoonClasses = 5;
  static const String _defaultEveningStartTime = '19:00';
  static const int _defaultEveningClasses = 3;
  static const int _defaultTotalWeeks = 20;
  static const int _defaultReminderAdvanceMinutes = 0;
  static const int _defaultEventReminderAdvanceMinutes = 0;

  final StorageService _storageService;
  final ScheduleCalculator _scheduleCalculator;
  final AutoMuteToggleService _autoMuteToggleService;

  double _pixelsPerMinute;
  int _classDuration;
  int _shortBreak;
  int _bigBreak;
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
  Future<void> Function()? _reminderScheduler;

  double get pixelsPerMinute => _pixelsPerMinute;
  int get classDuration => _classDuration;
  int get shortBreak => _shortBreak;
  int get bigBreak => _bigBreak;
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
    await _refreshReminders();
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

  Future<void> updateReminderAdvanceMinutes(int value) async {
    final safeValue = value.clamp(0, 60).toInt();
    if (safeValue == _reminderAdvanceMinutes) {
      return;
    }

    _reminderAdvanceMinutes = safeValue;
    notifyListeners();
    await _storageService.writeReminderAdvanceMinutes(safeValue);
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'updateReminderAdvanceMinutes',
    );
    await _refreshReminders();
  }

  Future<void> updateEventReminderAdvanceMinutes(int value) async {
    final safeValue = value.clamp(0, 1440).toInt();
    if (safeValue == _eventReminderAdvanceMinutes) {
      return;
    }

    _eventReminderAdvanceMinutes = safeValue;
    notifyListeners();
    await _storageService.writeEventReminderAdvanceMinutes(safeValue);
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'updateEventReminderAdvanceMinutes',
    );
    await _refreshReminders();
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
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'updateAutoMuteEnabled',
    );
    await _refreshReminders();
  }

  Future<bool> toggleAutoMuteWithCheck(bool value) async {
    if (!value) {
      await updateAutoMuteEnabled(false, fromUserAction: true);
      return true;
    }

    try {
      final canEnable = await _autoMuteToggleService.ensureCanEnableAutoMute();
      await updateAutoMuteEnabled(canEnable, fromUserAction: true);
      return canEnable;
    } catch (error, stackTrace) {
      print('[SettingsProvider] toggleAutoMuteWithCheck error: $error');
      print(stackTrace);
      await updateAutoMuteEnabled(false, fromUserAction: true);
      return false;
    }
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

  Future<void> _wakeBackgroundServiceIfNeeded({
    required bool shouldStart,
    required String reason,
  }) async {
    if (!Platform.isAndroid || !shouldStart) {
      return;
    }

    final service = FlutterBackgroundService();
    print('[SettingsProvider] startService requested from $reason');
    await service.startService();
  }

  bool _shouldKeepBackgroundServiceAlive() {
    return _autoMuteEnabled ||
        _reminderAdvanceMinutes > 0 ||
        _eventReminderAdvanceMinutes > 0;
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
