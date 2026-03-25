import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/event.dart';

class StorageService {
  StorageService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  static const String _coursesKey = 'courses.items';
  static const String _eventsKey = 'events.items';
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

  static Future<StorageService> create() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    return StorageService(sharedPreferences: sharedPreferences);
  }

  Future<void> reload() => _sharedPreferences.reload();

  List<Course> loadCourses() {
    return _decodeList(key: _coursesKey, decode: Course.fromJson);
  }

  List<Event> loadEvents() {
    return _decodeList(key: _eventsKey, decode: Event.fromJson);
  }

  Future<void> saveCourses(Iterable<Course> courses) {
    return _encodeList(
      key: _coursesKey,
      items: courses.map((course) => course.toJson()),
    );
  }

  Future<void> saveEvents(Iterable<Event> events) {
    return _encodeList(
      key: _eventsKey,
      items: events.map((event) => event.toJson()),
    );
  }

  Future<void> clearCourses() => _sharedPreferences.remove(_coursesKey);

  Future<void> clearAllTimetableData() async {
    await _sharedPreferences.remove(_coursesKey);
    await _sharedPreferences.remove(_eventsKey);
  }

  double readPixelsPerMinute({required double fallback}) {
    return _sharedPreferences.getDouble(_pixelsPerMinuteKey) ?? fallback;
  }

  Future<void> writePixelsPerMinute(double value) {
    return _sharedPreferences.setDouble(_pixelsPerMinuteKey, value);
  }

  int readClassDuration({required int fallback}) {
    return _sharedPreferences.getInt(_classDurationKey) ?? fallback;
  }

  Future<void> writeClassDuration(int value) {
    return _sharedPreferences.setInt(_classDurationKey, value);
  }

  int readShortBreak({required int fallback}) {
    return _sharedPreferences.getInt(_shortBreakKey) ?? fallback;
  }

  Future<void> writeShortBreak(int value) {
    return _sharedPreferences.setInt(_shortBreakKey, value);
  }

  int readBigBreak({required int fallback}) {
    return _sharedPreferences.getInt(_bigBreakKey) ?? fallback;
  }

  Future<void> writeBigBreak(int value) {
    return _sharedPreferences.setInt(_bigBreakKey, value);
  }

  String readMorningStartTime({required String fallback}) {
    return _sharedPreferences.getString(_morningStartTimeKey) ?? fallback;
  }

  Future<void> writeMorningStartTime(String value) {
    return _sharedPreferences.setString(_morningStartTimeKey, value);
  }

  int readMorningClasses({required int fallback}) {
    return _sharedPreferences.getInt(_morningClassesKey) ?? fallback;
  }

  Future<void> writeMorningClasses(int value) {
    return _sharedPreferences.setInt(_morningClassesKey, value);
  }

  String readAfternoonStartTime({required String fallback}) {
    return _sharedPreferences.getString(_afternoonStartTimeKey) ?? fallback;
  }

  Future<void> writeAfternoonStartTime(String value) {
    return _sharedPreferences.setString(_afternoonStartTimeKey, value);
  }

  int readAfternoonClasses({required int fallback}) {
    return _sharedPreferences.getInt(_afternoonClassesKey) ?? fallback;
  }

  Future<void> writeAfternoonClasses(int value) {
    return _sharedPreferences.setInt(_afternoonClassesKey, value);
  }

  String readEveningStartTime({required String fallback}) {
    return _sharedPreferences.getString(_eveningStartTimeKey) ?? fallback;
  }

  Future<void> writeEveningStartTime(String value) {
    return _sharedPreferences.setString(_eveningStartTimeKey, value);
  }

  int readEveningClasses({required int fallback}) {
    return _sharedPreferences.getInt(_eveningClassesKey) ?? fallback;
  }

  Future<void> writeEveningClasses(int value) {
    return _sharedPreferences.setInt(_eveningClassesKey, value);
  }

  DateTime? readSemesterStartDate() {
    final rawValue = _sharedPreferences.getString(_semesterStartDateKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue);
  }

  Future<void> writeSemesterStartDate(DateTime value) {
    return _sharedPreferences.setString(
      _semesterStartDateKey,
      value.toIso8601String(),
    );
  }

  int readTotalWeeks({required int fallback}) {
    return _sharedPreferences.getInt(_totalWeeksKey) ?? fallback;
  }

  Future<void> writeTotalWeeks(int value) {
    return _sharedPreferences.setInt(_totalWeeksKey, value);
  }

  int readReminderAdvanceMinutes({required int fallback}) {
    return _sharedPreferences.getInt(_reminderAdvanceMinutesKey) ?? fallback;
  }

  Future<void> writeReminderAdvanceMinutes(int value) {
    return _sharedPreferences.setInt(_reminderAdvanceMinutesKey, value);
  }

  int readEventReminderAdvanceMinutes({required int fallback}) {
    return _sharedPreferences.getInt(_eventReminderAdvanceMinutesKey) ??
        fallback;
  }

  Future<void> writeEventReminderAdvanceMinutes(int value) {
    return _sharedPreferences.setInt(_eventReminderAdvanceMinutesKey, value);
  }

  String readLanguageCode({required String fallback}) {
    return _sharedPreferences.getString(_languageCodeKey) ?? fallback;
  }

  Future<void> writeLanguageCode(String value) {
    return _sharedPreferences.setString(_languageCodeKey, value);
  }

  bool readAutoMuteEnabled({required bool fallback}) {
    return _sharedPreferences.getBool(_autoMuteEnabledKey) ?? fallback;
  }

  Future<void> writeAutoMuteEnabled(bool value) {
    return _sharedPreferences.setBool(_autoMuteEnabledKey, value);
  }

  List<T> _decodeList<T>({
    required String key,
    required T Function(Map<String, dynamic> json) decode,
  }) {
    final rawItems = _sharedPreferences.getStringList(key);
    if (rawItems == null || rawItems.isEmpty) {
      return <T>[];
    }

    final result = <T>[];
    for (final raw in rawItems) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        result.add(decode(json));
      } catch (_) {
        // Skip corrupted rows and keep the rest of local data readable.
      }
    }
    return result;
  }

  Future<void> _encodeList({
    required String key,
    required Iterable<Map<String, dynamic>> items,
  }) {
    final rawItems = items.map(jsonEncode).toList();
    return _sharedPreferences.setStringList(key, rawItems);
  }
}
