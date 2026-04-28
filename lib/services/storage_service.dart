import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../models/semester.dart';

class StorageService {
  StorageService({required SharedPreferences sharedPreferences})
    : _sharedPreferences = sharedPreferences;

  final SharedPreferences _sharedPreferences;

  static const String _coursesKey = 'courses.items';
  static const String _eventsKey = 'events.items';
  static const String _semestersKey = 'semesters.items';
  static const String _currentSemesterIdKey = 'semesters.currentId';
  static const String _semesterMigrationVersionKey =
      'semesters.migrationVersion';
  static const int _semesterMigrationVersion = 1;
  static const String _pixelsPerMinuteKey = 'settings.pixelsPerMinute';
  static const String _classDurationKey = 'settings.classDuration';
  static const String _shortBreakKey = 'settings.shortBreak';
  static const String _bigBreakKey = 'settings.bigBreak';
  static const String _bigBreakAfterPeriodKey = 'settings.bigBreakAfterPeriod';
  static const String _morningStartTimeKey = 'settings.morningStartTime';
  static const String _morningClassesKey = 'settings.morningClasses';
  static const String _morningPeriodStartTimesKey =
      'settings.morningPeriodStartTimes';
  static const String _afternoonStartTimeKey = 'settings.afternoonStartTime';
  static const String _afternoonClassesKey = 'settings.afternoonClasses';
  static const String _afternoonPeriodStartTimesKey =
      'settings.afternoonPeriodStartTimes';
  static const String _eveningStartTimeKey = 'settings.eveningStartTime';
  static const String _eveningClassesKey = 'settings.eveningClasses';
  static const String _eveningPeriodStartTimesKey =
      'settings.eveningPeriodStartTimes';
  static const String _semesterStartDateKey = 'settings.semesterStartDate';
  static const String _semesterStartDatePromptShownKey =
      'settings.semesterStartDatePromptShown';
  static const String _totalWeeksKey = 'settings.totalWeeks';
  static const String _reminderAdvanceMinutesKey =
      'settings.reminderAdvanceMinutes';
  static const String _eventReminderAdvanceMinutesKey =
      'settings.eventReminderAdvanceMinutes';
  static const String _languageCodeKey = 'settings.languageCode';
  static const String _themePaletteIdKey = 'settings.themePaletteId';
  static const String _customThemePrimaryValueKey =
      'settings.customThemePrimaryValue';
  static const String _customThemeAccentValueKey =
      'settings.customThemeAccentValue';
  static const String _autoMuteEnabledKey = 'settings.autoMuteEnabled';
  static const String _backgroundServiceEnabledKey =
      'settings.backgroundServiceEnabled';

  static Future<StorageService> create() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final service = StorageService(sharedPreferences: sharedPreferences);
    await service.ensureSemesterMigration();
    return service;
  }

  Future<void> reload() => _sharedPreferences.reload();

  String? get currentSemesterId =>
      _sharedPreferences.getString(_currentSemesterIdKey);

  List<Semester> loadSemesters() {
    return _decodeList(key: _semestersKey, decode: Semester.fromJson);
  }

  Semester? readCurrentSemester() {
    final semesterId = currentSemesterId;
    if (semesterId == null) {
      return null;
    }
    for (final semester in loadSemesters()) {
      if (semester.id == semesterId) {
        return semester;
      }
    }
    return null;
  }

  Future<Semester> createSemesterWithInitialData({
    required DateTime startDate,
    String? customName,
  }) async {
    final semesters = loadSemesters();
    final nextNumber = semesters.length + 1;
    final semester = Semester(
      id: Semester.createId(),
      name:
          _normalizeSemesterName(customName) ??
          _defaultSemesterName(nextNumber),
      createdAt: DateTime.now(),
      isInitialized: true,
    );

    await _saveSemesters([...semesters, semester]);
    await setCurrentSemesterId(semester.id);
    await writeSemesterStartDateFor(semester.id, startDate);
    return semester;
  }

  Future<void> setCurrentSemesterId(String semesterId) {
    return _sharedPreferences.setString(_currentSemesterIdKey, semesterId);
  }

  Future<void> initializeExistingSemester(
    String semesterId, {
    required DateTime startDate,
  }) async {
    await writeSemesterStartDateFor(semesterId, startDate);
    await markSemesterInitialized(semesterId);
  }

  Future<void> markSemesterInitialized(String semesterId) async {
    final semesters = loadSemesters();
    final updated = semesters
        .map(
          (semester) => semester.id == semesterId
              ? semester.copyWith(isInitialized: true)
              : semester,
        )
        .toList();
    await _saveSemesters(updated);
  }

  Future<void> renameSemester(String semesterId, String newName) async {
    final normalizedName = _normalizeSemesterName(newName);
    if (normalizedName == null) {
      return;
    }

    final semesters = loadSemesters();
    final updated = semesters
        .map(
          (semester) => semester.id == semesterId
              ? semester.copyWith(name: normalizedName)
              : semester,
        )
        .toList();
    await _saveSemesters(updated);
  }

  Future<String?> deleteSemester(String semesterId) async {
    final remainingSemesters = loadSemesters()
        .where((semester) => semester.id != semesterId)
        .toList();
    await _saveSemesters(remainingSemesters);
    await _deleteSemesterScopedData(semesterId);

    final currentId = currentSemesterId;
    if (currentId != semesterId) {
      return currentId;
    }

    if (remainingSemesters.isEmpty) {
      await _sharedPreferences.remove(_currentSemesterIdKey);
      return null;
    }

    for (final semester in remainingSemesters) {
      if (semester.isInitialized) {
        await setCurrentSemesterId(semester.id);
        return semester.id;
      }
    }

    await _sharedPreferences.remove(_currentSemesterIdKey);
    return null;
  }

  Future<void> ensureSemesterMigration() async {
    final migrationVersion =
        _sharedPreferences.getInt(_semesterMigrationVersionKey) ?? 0;
    final existingSemesters = loadSemesters();
    if (migrationVersion >= _semesterMigrationVersion &&
        existingSemesters.isNotEmpty &&
        currentSemesterId != null) {
      return;
    }

    if (existingSemesters.isNotEmpty) {
      final currentId = currentSemesterId ?? existingSemesters.first.id;
      await setCurrentSemesterId(currentId);
      await _sharedPreferences.setInt(
        _semesterMigrationVersionKey,
        _semesterMigrationVersion,
      );
      return;
    }

    final legacyUser = _hasLegacyTimetableData();
    final firstSemester = Semester(
      id: Semester.createId(),
      name: _defaultSemesterName(1),
      createdAt: DateTime.now(),
      isInitialized: legacyUser,
    );

    await _saveSemesters([firstSemester]);
    await setCurrentSemesterId(firstSemester.id);
    await _migrateLegacyTimetableData(firstSemester.id, legacyUser: legacyUser);
    await _sharedPreferences.setInt(
      _semesterMigrationVersionKey,
      _semesterMigrationVersion,
    );
  }

  List<Course> loadCourses() {
    final semesterId = currentSemesterId;
    return _decodeList(
      key: _semesterScopedKey(_coursesKey, semesterId: semesterId),
      decode: Course.fromJson,
    );
  }

  List<Event> loadEvents() {
    final semesterId = currentSemesterId;
    return _decodeList(
      key: _semesterScopedKey(_eventsKey, semesterId: semesterId),
      decode: Event.fromJson,
    );
  }

  Future<void> saveCourses(Iterable<Course> courses) {
    final semesterId = currentSemesterId;
    return _encodeList(
      key: _semesterScopedKey(_coursesKey, semesterId: semesterId),
      items: courses.map(
        (course) => course.copyWith(semesterId: semesterId).toJson(),
      ),
    );
  }

  Future<void> saveEvents(Iterable<Event> events) {
    final semesterId = currentSemesterId;
    return _encodeList(
      key: _semesterScopedKey(_eventsKey, semesterId: semesterId),
      items: events.map(
        (event) => event.copyWith(semesterId: semesterId).toJson(),
      ),
    );
  }

  Future<void> clearCourses() {
    return _sharedPreferences.remove(
      _semesterScopedKey(_coursesKey, semesterId: currentSemesterId),
    );
  }

  Future<void> clearAllTimetableData() async {
    final semesterId = currentSemesterId;
    await _sharedPreferences.remove(
      _semesterScopedKey(_coursesKey, semesterId: semesterId),
    );
    await _sharedPreferences.remove(
      _semesterScopedKey(_eventsKey, semesterId: semesterId),
    );
  }

  double readPixelsPerMinute({required double fallback}) {
    return _sharedPreferences.getDouble(
          _currentSemesterKey(_pixelsPerMinuteKey),
        ) ??
        fallback;
  }

  Future<void> writePixelsPerMinute(double value) {
    return _sharedPreferences.setDouble(
      _currentSemesterKey(_pixelsPerMinuteKey),
      value,
    );
  }

  int readClassDuration({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_classDurationKey)) ??
        fallback;
  }

  Future<void> writeClassDuration(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_classDurationKey),
      value,
    );
  }

  int readShortBreak({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_shortBreakKey)) ??
        fallback;
  }

  Future<void> writeShortBreak(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_shortBreakKey),
      value,
    );
  }

  int readBigBreak({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_bigBreakKey)) ??
        fallback;
  }

  Future<void> writeBigBreak(int value) {
    return _sharedPreferences.setInt(_currentSemesterKey(_bigBreakKey), value);
  }

  int readBigBreakAfterPeriod({required int fallback}) {
    return _sharedPreferences.getInt(
          _currentSemesterKey(_bigBreakAfterPeriodKey),
        ) ??
        fallback;
  }

  Future<void> writeBigBreakAfterPeriod(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_bigBreakAfterPeriodKey),
      value,
    );
  }

  String readMorningStartTime({required String fallback}) {
    return _sharedPreferences.getString(
          _currentSemesterKey(_morningStartTimeKey),
        ) ??
        fallback;
  }

  Future<void> writeMorningStartTime(String value) {
    return _sharedPreferences.setString(
      _currentSemesterKey(_morningStartTimeKey),
      value,
    );
  }

  int readMorningClasses({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_morningClassesKey)) ??
        fallback;
  }

  Future<void> writeMorningClasses(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_morningClassesKey),
      value,
    );
  }

  List<String>? readMorningPeriodStartTimes() {
    return _sharedPreferences.getStringList(
      _currentSemesterKey(_morningPeriodStartTimesKey),
    );
  }

  Future<void> writeMorningPeriodStartTimes(List<String> values) {
    return _sharedPreferences.setStringList(
      _currentSemesterKey(_morningPeriodStartTimesKey),
      values,
    );
  }

  String readAfternoonStartTime({required String fallback}) {
    return _sharedPreferences.getString(
          _currentSemesterKey(_afternoonStartTimeKey),
        ) ??
        fallback;
  }

  Future<void> writeAfternoonStartTime(String value) {
    return _sharedPreferences.setString(
      _currentSemesterKey(_afternoonStartTimeKey),
      value,
    );
  }

  int readAfternoonClasses({required int fallback}) {
    return _sharedPreferences.getInt(
          _currentSemesterKey(_afternoonClassesKey),
        ) ??
        fallback;
  }

  Future<void> writeAfternoonClasses(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_afternoonClassesKey),
      value,
    );
  }

  List<String>? readAfternoonPeriodStartTimes() {
    return _sharedPreferences.getStringList(
      _currentSemesterKey(_afternoonPeriodStartTimesKey),
    );
  }

  Future<void> writeAfternoonPeriodStartTimes(List<String> values) {
    return _sharedPreferences.setStringList(
      _currentSemesterKey(_afternoonPeriodStartTimesKey),
      values,
    );
  }

  String readEveningStartTime({required String fallback}) {
    return _sharedPreferences.getString(
          _currentSemesterKey(_eveningStartTimeKey),
        ) ??
        fallback;
  }

  Future<void> writeEveningStartTime(String value) {
    return _sharedPreferences.setString(
      _currentSemesterKey(_eveningStartTimeKey),
      value,
    );
  }

  int readEveningClasses({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_eveningClassesKey)) ??
        fallback;
  }

  Future<void> writeEveningClasses(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_eveningClassesKey),
      value,
    );
  }

  List<String>? readEveningPeriodStartTimes() {
    return _sharedPreferences.getStringList(
      _currentSemesterKey(_eveningPeriodStartTimesKey),
    );
  }

  Future<void> writeEveningPeriodStartTimes(List<String> values) {
    return _sharedPreferences.setStringList(
      _currentSemesterKey(_eveningPeriodStartTimesKey),
      values,
    );
  }

  DateTime? readSemesterStartDate() {
    final rawValue = _sharedPreferences.getString(
      _currentSemesterKey(_semesterStartDateKey),
    );
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return DateTime.tryParse(rawValue);
  }

  bool hasSemesterStartDate() {
    return _sharedPreferences.containsKey(
      _currentSemesterKey(_semesterStartDateKey),
    );
  }

  Future<void> writeSemesterStartDate(DateTime value) {
    return _sharedPreferences.setString(
      _currentSemesterKey(_semesterStartDateKey),
      value.toIso8601String(),
    );
  }

  Future<void> writeSemesterStartDateFor(String semesterId, DateTime value) {
    return _sharedPreferences.setString(
      _semesterScopedKey(_semesterStartDateKey, semesterId: semesterId),
      value.toIso8601String(),
    );
  }

  bool readSemesterStartDatePromptShown({required bool fallback}) {
    return _sharedPreferences.getBool(_semesterStartDatePromptShownKey) ??
        fallback;
  }

  Future<void> writeSemesterStartDatePromptShown(bool value) {
    return _sharedPreferences.setBool(_semesterStartDatePromptShownKey, value);
  }

  int readTotalWeeks({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_totalWeeksKey)) ??
        fallback;
  }

  Future<void> writeTotalWeeks(int value) {
    return _sharedPreferences.setInt(
      _currentSemesterKey(_totalWeeksKey),
      value,
    );
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

  String readThemePaletteId({required String fallback}) {
    return _sharedPreferences.getString(_themePaletteIdKey) ?? fallback;
  }

  Future<void> writeThemePaletteId(String value) {
    return _sharedPreferences.setString(_themePaletteIdKey, value);
  }

  int readCustomThemePrimaryValue({required int fallback}) {
    return _sharedPreferences.getInt(_customThemePrimaryValueKey) ?? fallback;
  }

  Future<void> writeCustomThemePrimaryValue(int value) {
    return _sharedPreferences.setInt(_customThemePrimaryValueKey, value);
  }

  int readCustomThemeAccentValue({required int fallback}) {
    return _sharedPreferences.getInt(_customThemeAccentValueKey) ?? fallback;
  }

  Future<void> writeCustomThemeAccentValue(int value) {
    return _sharedPreferences.setInt(_customThemeAccentValueKey, value);
  }

  bool readAutoMuteEnabled({required bool fallback}) {
    return _sharedPreferences.getBool(_autoMuteEnabledKey) ?? fallback;
  }

  Future<void> writeAutoMuteEnabled(bool value) {
    return _sharedPreferences.setBool(_autoMuteEnabledKey, value);
  }

  bool readBackgroundServiceEnabled({required bool fallback}) {
    return _sharedPreferences.getBool(_backgroundServiceEnabledKey) ?? fallback;
  }

  Future<void> writeBackgroundServiceEnabled(bool value) {
    return _sharedPreferences.setBool(_backgroundServiceEnabledKey, value);
  }

  String _currentSemesterKey(String key) {
    return _semesterScopedKey(key, semesterId: currentSemesterId);
  }

  String _semesterScopedKey(String key, {required String? semesterId}) {
    if (semesterId == null || semesterId.isEmpty) {
      return key;
    }
    return 'semesters.$semesterId.$key';
  }

  Future<void> _saveSemesters(List<Semester> semesters) {
    return _encodeList(
      key: _semestersKey,
      items: semesters.map((semester) => semester.toJson()),
    );
  }

  bool _hasLegacyTimetableData() {
    final keys = [
      _coursesKey,
      _eventsKey,
      _pixelsPerMinuteKey,
      _classDurationKey,
      _shortBreakKey,
      _bigBreakKey,
      _bigBreakAfterPeriodKey,
      _morningStartTimeKey,
      _morningClassesKey,
      _morningPeriodStartTimesKey,
      _afternoonStartTimeKey,
      _afternoonClassesKey,
      _afternoonPeriodStartTimesKey,
      _eveningStartTimeKey,
      _eveningClassesKey,
      _eveningPeriodStartTimesKey,
      _semesterStartDateKey,
      _semesterStartDatePromptShownKey,
      _totalWeeksKey,
    ];
    return keys.any(_sharedPreferences.containsKey);
  }

  Future<void> _migrateLegacyTimetableData(
    String semesterId, {
    required bool legacyUser,
  }) async {
    final legacyCourses = _decodeList(
      key: _coursesKey,
      decode: Course.fromJson,
    ).map((course) => course.copyWith(semesterId: semesterId).toJson());
    await _encodeList(
      key: _semesterScopedKey(_coursesKey, semesterId: semesterId),
      items: legacyCourses,
    );

    final legacyEvents = _decodeList(
      key: _eventsKey,
      decode: Event.fromJson,
    ).map((event) => event.copyWith(semesterId: semesterId).toJson());
    await _encodeList(
      key: _semesterScopedKey(_eventsKey, semesterId: semesterId),
      items: legacyEvents,
    );

    await _copyLegacySetting(_pixelsPerMinuteKey);
    await _copyLegacySetting(_classDurationKey);
    await _copyLegacySetting(_shortBreakKey);
    await _copyLegacySetting(_bigBreakKey);
    await _copyLegacySetting(_bigBreakAfterPeriodKey);
    await _copyLegacySetting(_morningStartTimeKey);
    await _copyLegacySetting(_morningClassesKey);
    await _copyLegacySetting(_morningPeriodStartTimesKey);
    await _copyLegacySetting(_afternoonStartTimeKey);
    await _copyLegacySetting(_afternoonClassesKey);
    await _copyLegacySetting(_afternoonPeriodStartTimesKey);
    await _copyLegacySetting(_eveningStartTimeKey);
    await _copyLegacySetting(_eveningClassesKey);
    await _copyLegacySetting(_eveningPeriodStartTimesKey);
    await _copyLegacySetting(_semesterStartDateKey);
    await _copyLegacySetting(_semesterStartDatePromptShownKey);
    await _copyLegacySetting(_totalWeeksKey);

    if (legacyUser && !_sharedPreferences.containsKey(_semesterStartDateKey)) {
      await _sharedPreferences.setString(
        _semesterScopedKey(_semesterStartDateKey, semesterId: semesterId),
        _defaultSemesterStartDate().toIso8601String(),
      );
    }
  }

  Future<void> _copyLegacySetting(String key) async {
    if (!_sharedPreferences.containsKey(key)) {
      return;
    }

    final scopedKey = _currentSemesterKey(key);
    final value = _sharedPreferences.get(key);
    if (value is int) {
      await _sharedPreferences.setInt(scopedKey, value);
    } else if (value is double) {
      await _sharedPreferences.setDouble(scopedKey, value);
    } else if (value is bool) {
      await _sharedPreferences.setBool(scopedKey, value);
    } else if (value is String) {
      await _sharedPreferences.setString(scopedKey, value);
    } else if (value is List<String>) {
      await _sharedPreferences.setStringList(scopedKey, value);
    }
  }

  Future<void> _deleteSemesterScopedData(String semesterId) async {
    final prefix = 'semesters.$semesterId.';
    final keysToRemove = _sharedPreferences
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keysToRemove) {
      await _sharedPreferences.remove(key);
    }
  }

  String _defaultSemesterName(int number) {
    return '第 $number 学期';
  }

  String? _normalizeSemesterName(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized.length > 20 ? normalized.substring(0, 20) : normalized;
  }

  DateTime _defaultSemesterStartDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
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
