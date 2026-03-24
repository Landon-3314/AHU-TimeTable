import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_localizations.dart';
import '../models/time_slot.dart';
import '../services/auto_mute_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences,
       _pixelsPerMinute =
           sharedPreferences.getDouble(_pixelsPerMinuteKey) ??
           _defaultPixelsPerMinute,
       _classDuration =
           sharedPreferences.getInt(_classDurationKey) ?? _defaultClassDuration,
       _shortBreak =
           sharedPreferences.getInt(_shortBreakKey) ?? _defaultShortBreak,
       _bigBreak =
           sharedPreferences.getInt(_bigBreakKey) ?? _defaultBigBreak,
       _morningStartTime =
           sharedPreferences.getString(_morningStartTimeKey) ??
           _defaultMorningStartTime,
       _morningClasses =
           sharedPreferences.getInt(_morningClassesKey) ?? _defaultMorningClasses,
       _afternoonStartTime =
           sharedPreferences.getString(_afternoonStartTimeKey) ??
           _defaultAfternoonStartTime,
       _afternoonClasses = sharedPreferences.getInt(_afternoonClassesKey) ??
           _defaultAfternoonClasses,
       _eveningStartTime =
           sharedPreferences.getString(_eveningStartTimeKey) ??
           _defaultEveningStartTime,
       _eveningClasses =
           sharedPreferences.getInt(_eveningClassesKey) ?? _defaultEveningClasses,
       _semesterStartDate = _loadSemesterStartDate(sharedPreferences),
       _totalWeeks = sharedPreferences.getInt(_totalWeeksKey) ?? _defaultTotalWeeks,
       _reminderAdvanceMinutes =
           sharedPreferences.getInt(_reminderAdvanceMinutesKey) ??
           _defaultReminderAdvanceMinutes,
       _eventReminderAdvanceMinutes =
           sharedPreferences.getInt(_eventReminderAdvanceMinutesKey) ??
           _defaultEventReminderAdvanceMinutes,
       _languageCode = sharedPreferences.getString(_languageCodeKey) ?? 'zh',
       _autoMuteEnabled =
           sharedPreferences.getBool(_autoMuteEnabledKey) ?? false;

  static const String _pixelsPerMinuteKey = 'settings.pixelsPerMinute';
  static const String _classDurationKey = 'settings.classDuration';
  static const String _shortBreakKey = 'settings.shortBreak';
  static const String _bigBreakKey = 'settings.bigBreak';
  static const String _morningStartTimeKey = 'settings.morningStartTime';
  static const String _morningClassesKey = 'settings.morningClasses';
  static const String _afternoonStartTimeKey = 'settings.afternoonStartTime';
  static const String _afternoonClassesKey = 'settings.afternoonClasses';
  static const String _eveningStartTimeKey = 'settings.eveningStartTime';
  static const String _eveningClassesKey = 'settings.eveningClasses';
  static const String _semesterStartDateKey = 'settings.semesterStartDate';
  static const String _totalWeeksKey = 'settings.totalWeeks';
  static const String _reminderAdvanceMinutesKey =
      'settings.reminderAdvanceMinutes';
  static const String _eventReminderAdvanceMinutesKey =
      'settings.eventReminderAdvanceMinutes';
  static const String _languageCodeKey = 'settings.languageCode';
  static const String _autoMuteEnabledKey = 'settings.autoMuteEnabled';

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

  final SharedPreferences _sharedPreferences;

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

  int get currentRealWeek {
    final today = DateUtils.dateOnly(DateTime.now());
    final diffDays = today.difference(_semesterStartDate).inDays;
    final week = (diffDays ~/ 7) + 1;
    return week.clamp(1, _totalWeeks).toInt();
  }

  int get currentRealWeekday {
    final weekday = DateTime.now().weekday;
    return weekday.clamp(1, 7).toInt();
  }

  DateTime getDateFor(int week, int weekday) {
    final safeWeek = week.clamp(1, _totalWeeks).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    return _semesterStartDate.add(
      Duration(days: (safeWeek - 1) * 7 + (safeWeekday - 1)),
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
    await _sharedPreferences.setString(_languageCodeKey, code);
  }

  List<TimeSlot> generateTimeSlots() {
    final List<TimeSlot> slots = [];
    int periodNumber = 1;

    periodNumber = _appendSessionSlots(
      slots: slots,
      startTime: morningStartTime,
      count: _morningClasses,
      periodNumber: periodNumber,
      label: 'Morning',
      hasBigBreak: true,
    );
    periodNumber = _appendSessionSlots(
      slots: slots,
      startTime: afternoonStartTime,
      count: _afternoonClasses,
      periodNumber: periodNumber,
      label: 'Afternoon',
      hasBigBreak: true,
    );
    _appendSessionSlots(
      slots: slots,
      startTime: eveningStartTime,
      count: _eveningClasses,
      periodNumber: periodNumber,
      label: 'Evening',
      hasBigBreak: false,
    );

    return slots;
  }

  Future<void> updatePixelsPerMinute(double value) async {
    if (value == _pixelsPerMinute) {
      return;
    }

    _pixelsPerMinute = value;
    notifyListeners();
    await _sharedPreferences.setDouble(_pixelsPerMinuteKey, value);
  }

  Future<void> updateClassDuration(int value) async {
    if (value == _classDuration) {
      return;
    }

    _classDuration = value;
    notifyListeners();
    await _sharedPreferences.setInt(_classDurationKey, value);
    await _refreshReminders();
  }

  Future<void> updateShortBreak(int value) async {
    if (value == _shortBreak) {
      return;
    }

    _shortBreak = value;
    notifyListeners();
    await _sharedPreferences.setInt(_shortBreakKey, value);
    await _refreshReminders();
  }

  Future<void> updateBigBreak(int value) async {
    if (value == _bigBreak) {
      return;
    }

    _bigBreak = value;
    notifyListeners();
    await _sharedPreferences.setInt(_bigBreakKey, value);
    await _refreshReminders();
  }

  Future<void> updateMorningStartTime(TimeOfDay value) async {
    await _updateTime(
      key: _morningStartTimeKey,
      currentValue: _morningStartTime,
      nextValue: value,
      apply: (formatted) => _morningStartTime = formatted,
    );
  }

  Future<void> updateMorningClasses(int value) async {
    if (value == _morningClasses) {
      return;
    }

    _morningClasses = value;
    notifyListeners();
    await _sharedPreferences.setInt(_morningClassesKey, value);
    await _refreshReminders();
  }

  Future<void> updateAfternoonStartTime(TimeOfDay value) async {
    await _updateTime(
      key: _afternoonStartTimeKey,
      currentValue: _afternoonStartTime,
      nextValue: value,
      apply: (formatted) => _afternoonStartTime = formatted,
    );
  }

  Future<void> updateAfternoonClasses(int value) async {
    if (value == _afternoonClasses) {
      return;
    }

    _afternoonClasses = value;
    notifyListeners();
    await _sharedPreferences.setInt(_afternoonClassesKey, value);
    await _refreshReminders();
  }

  Future<void> updateEveningStartTime(TimeOfDay value) async {
    await _updateTime(
      key: _eveningStartTimeKey,
      currentValue: _eveningStartTime,
      nextValue: value,
      apply: (formatted) => _eveningStartTime = formatted,
    );
  }

  Future<void> updateEveningClasses(int value) async {
    if (value == _eveningClasses) {
      return;
    }

    _eveningClasses = value;
    notifyListeners();
    await _sharedPreferences.setInt(_eveningClassesKey, value);
    await _refreshReminders();
  }

  Future<void> updateSemesterStartDate(DateTime value) async {
    final aligned = _alignToMonday(value);
    if (DateUtils.isSameDay(aligned, _semesterStartDate)) {
      return;
    }

    _semesterStartDate = aligned;
    notifyListeners();
    await _sharedPreferences.setString(
      _semesterStartDateKey,
      aligned.toIso8601String(),
    );
    await _refreshReminders();
  }

  Future<void> updateTotalWeeks(int value) async {
    final safeValue = value.clamp(15, 30).toInt();
    if (safeValue == _totalWeeks) {
      return;
    }

    _totalWeeks = safeValue;
    notifyListeners();
    await _sharedPreferences.setInt(_totalWeeksKey, safeValue);
    await _refreshReminders();
  }

  Future<void> updateReminderAdvanceMinutes(int value) async {
    final safeValue = value.clamp(0, 60).toInt();
    if (safeValue == _reminderAdvanceMinutes) {
      return;
    }

    _reminderAdvanceMinutes = safeValue;
    notifyListeners();
    await _sharedPreferences.setInt(_reminderAdvanceMinutesKey, safeValue);
    await _refreshReminders();
  }

  Future<void> updateEventReminderAdvanceMinutes(int value) async {
    final safeValue = value.clamp(0, 1440).toInt();
    if (safeValue == _eventReminderAdvanceMinutes) {
      return;
    }

    _eventReminderAdvanceMinutes = safeValue;
    notifyListeners();
    await _sharedPreferences.setInt(_eventReminderAdvanceMinutesKey, safeValue);
    await _refreshReminders();
  }

  Future<void> updateAutoMuteEnabled(
    bool value, {
    bool fromUserAction = false,
  }) async {
    // Guardrail: only explicit user operations from settings UI
    // are allowed to mutate the persisted auto-mute preference.
    if (!fromUserAction) {
      return;
    }

    if (value == _autoMuteEnabled) {
      return;
    }

    _autoMuteEnabled = value;
    notifyListeners();
    await _sharedPreferences.setBool(_autoMuteEnabledKey, value);
    await _refreshReminders();
  }

  Future<bool> toggleAutoMuteWithCheck(bool value) async {
    if (!value) {
      await updateAutoMuteEnabled(
        false,
        fromUserAction: true,
      );
      return true;
    }

    try {
      if (!Platform.isAndroid) {
        await updateAutoMuteEnabled(
          true,
          fromUserAction: true,
        );
        return true;
      }

      var hasPermission = await AutoMuteService.instance.hasPermission();
      if (!hasPermission) {
        await AutoMuteService.instance.openPermissionSettings();
        hasPermission = await AutoMuteService.instance.hasPermission();
      }

      if (!hasPermission) {
        await updateAutoMuteEnabled(
          false,
          fromUserAction: true,
        );
        return false;
      }

      await updateAutoMuteEnabled(
        true,
        fromUserAction: true,
      );
      return true;
    } catch (error, stackTrace) {
      print('[SettingsProvider] toggleAutoMuteWithCheck error: $error');
      print(stackTrace);
      await updateAutoMuteEnabled(
        false,
        fromUserAction: true,
      );
      return false;
    }
  }

  int _appendSessionSlots({
    required List<TimeSlot> slots,
    required TimeOfDay startTime,
    required int count,
    required int periodNumber,
    required String label,
    required bool hasBigBreak,
  }) {
    int currentStartMinutes = _toMinutes(startTime);

    for (int index = 1; index <= count; index++) {
      final int classStartMinutes = currentStartMinutes;
      final int classEndMinutes = classStartMinutes + _classDuration;

      slots.add(
        TimeSlot(
          periodNumber: periodNumber,
          startTime: _fromMinutes(classStartMinutes),
          endTime: _fromMinutes(classEndMinutes),
          label: label,
        ),
      );

      periodNumber += 1;
      currentStartMinutes = classEndMinutes;

      if (index == count) {
        continue;
      }

      currentStartMinutes += hasBigBreak && index == 2
          ? _bigBreak
          : _shortBreak;
    }

    return periodNumber;
  }

  Future<void> _updateTime({
    required String key,
    required String currentValue,
    required TimeOfDay nextValue,
    required ValueChanged<String> apply,
  }) async {
    final formatted = _formatTime(nextValue);
    if (formatted == currentValue) {
      return;
    }

    apply(formatted);
    notifyListeners();
    await _sharedPreferences.setString(key, formatted);
    await _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) {
      return;
    }

    await scheduler();
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _toMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _fromMinutes(int totalMinutes) {
    return TimeOfDay(
      hour: totalMinutes ~/ 60,
      minute: totalMinutes % 60,
    );
  }

  static DateTime _loadSemesterStartDate(SharedPreferences sharedPreferences) {
    final rawValue = sharedPreferences.getString(_semesterStartDateKey);
    if (rawValue == null || rawValue.isEmpty) {
      return _defaultSemesterStartDate();
    }

    final parsed = DateTime.tryParse(rawValue);
    if (parsed == null) {
      return _defaultSemesterStartDate();
    }

    return _alignToMonday(parsed);
  }

  static DateTime _defaultSemesterStartDate() {
    return _alignToMonday(DateTime.now());
  }

  static DateTime _alignToMonday(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }
}
