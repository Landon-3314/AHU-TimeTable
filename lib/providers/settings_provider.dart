import 'dart:io';

import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../models/clock_time.dart';
import '../models/time_slot.dart';
import '../services/auto_mute_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required StorageService storageService})
    : _storageService = storageService,
      _pixelsPerMinute = storageService.readPixelsPerMinute(
        fallback: _defaultPixelsPerMinute,
      ),
      _classDuration = storageService.readClassDuration(
        fallback: _defaultClassDuration,
      ),
      _shortBreak = storageService.readShortBreak(fallback: _defaultShortBreak),
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
      _semesterStartDate = _loadSemesterStartDate(storageService),
      _totalWeeks = storageService.readTotalWeeks(fallback: _defaultTotalWeeks),
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
    await _storageService.writeLanguageCode(code);
  }

  List<TimeSlot> generateTimeSlots() {
    final List<TimeSlot> slots = [];
    int periodNumber = 1;

    periodNumber = _appendSessionSlots(
      slots: slots,
      startTime: ClockTime.fromString(_morningStartTime),
      count: _morningClasses,
      periodNumber: periodNumber,
      label: 'Morning',
      hasBigBreak: true,
    );
    periodNumber = _appendSessionSlots(
      slots: slots,
      startTime: ClockTime.fromString(_afternoonStartTime),
      count: _afternoonClasses,
      periodNumber: periodNumber,
      label: 'Afternoon',
      hasBigBreak: true,
    );
    _appendSessionSlots(
      slots: slots,
      startTime: ClockTime.fromString(_eveningStartTime),
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
    final aligned = _alignToMonday(value);
    if (DateUtils.isSameDay(aligned, _semesterStartDate)) {
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
    await _storageService.writeAutoMuteEnabled(value);
    await _refreshReminders();
  }

  Future<bool> toggleAutoMuteWithCheck(bool value) async {
    if (!value) {
      await updateAutoMuteEnabled(false, fromUserAction: true);
      return true;
    }

    try {
      if (!Platform.isAndroid) {
        await updateAutoMuteEnabled(true, fromUserAction: true);
        return true;
      }

      var hasPermission = await AutoMuteService.instance.hasPermission();
      if (!hasPermission) {
        await AutoMuteService.instance.openPermissionSettings();
        hasPermission = await AutoMuteService.instance.hasPermission();
      }

      if (!hasPermission) {
        await updateAutoMuteEnabled(false, fromUserAction: true);
        return false;
      }

      await updateAutoMuteEnabled(true, fromUserAction: true);
      return true;
    } catch (error, stackTrace) {
      print('[SettingsProvider] toggleAutoMuteWithCheck error: $error');
      print(stackTrace);
      await updateAutoMuteEnabled(false, fromUserAction: true);
      return false;
    }
  }

  int _appendSessionSlots({
    required List<TimeSlot> slots,
    required ClockTime startTime,
    required int count,
    required int periodNumber,
    required String label,
    required bool hasBigBreak,
  }) {
    int currentStartMinutes = startTime.toMinutes();

    for (int index = 1; index <= count; index++) {
      final int classStartMinutes = currentStartMinutes;
      final int classEndMinutes = classStartMinutes + _classDuration;

      slots.add(
        TimeSlot(
          periodNumber: periodNumber,
          startTime: ClockTime.fromMinutes(classStartMinutes),
          endTime: ClockTime.fromMinutes(classEndMinutes),
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

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static DateTime _loadSemesterStartDate(StorageService storageService) {
    final rawValue = storageService.readSemesterStartDate();
    if (rawValue == null) {
      return _defaultSemesterStartDate();
    }
    return _alignToMonday(rawValue);
  }

  static DateTime _defaultSemesterStartDate() {
    return _alignToMonday(DateTime.now());
  }

  static DateTime _alignToMonday(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }
}
