import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../models/semester.dart';
import 'corrupt_row_diagnostic_store.dart';
import 'external_data_backup_store.dart';

enum InternalDataState { missing, valid, damaged }

enum AppThemeMode { system, light, dark }

class StorageService {
  StorageService({
    required SharedPreferences sharedPreferences,
    ExternalDataBackupStore? externalDataBackupStore,
    ExternalDataRecoveryStatus lastRecoveryStatus =
        ExternalDataRecoveryStatus.unavailable,
  }) : _sharedPreferences = sharedPreferences,
       _externalDataBackupStore = externalDataBackupStore,
       _lastRecoveryStatus = lastRecoveryStatus;

  final SharedPreferences _sharedPreferences;
  final ExternalDataBackupStore? _externalDataBackupStore;
  final ExternalDataRecoveryStatus _lastRecoveryStatus;

  static const String _coursesKey = 'courses.items';
  static const String _eventsKey = 'events.items';
  static const String _semestersKey = 'semesters.items';
  static const String _currentSemesterIdKey = 'semesters.currentId';
  static const String _semesterMigrationVersionKey =
      'semesters.migrationVersion';
  static const String _semesterMigrationStateKey = 'semesters.migrationState';
  static const String _semesterMigrationTargetIdKey =
      'semesters.migrationTargetId';
  static const String _semesterOperationJournalKey =
      'semesters.operationJournal';
  static const String _semesterOperationCreate = 'create';
  static const String _semesterOperationInitialize = 'initialize';
  static const String _semesterOperationSwitch = 'switch';
  static const String _semesterOperationDelete = 'delete';
  static const int _semesterMigrationVersion = 1;
  static const String _migrationStateInProgress = 'in_progress';
  static const String _migrationStateComplete = 'complete';
  static const String _pixelsPerMinuteKey = 'settings.pixelsPerMinute';
  static const String _classDurationKey = 'settings.classDuration';
  static const String _shortBreakKey = 'settings.shortBreak';
  static const String _bigBreakEnabledKey = 'settings.bigBreakEnabled';
  static const String _bigBreakKey = 'settings.bigBreak';
  static const String _bigBreakAfterPeriodKey = 'settings.bigBreakAfterPeriod';
  static const String _bigBreakAfterPeriodsKey =
      'settings.bigBreakAfterPeriods';
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
  static const String _timetableToolbarGuideConfirmedKey =
      'onboarding.timetableToolbarGuideConfirmed.v1';
  static const String _importWebViewGuideConfirmedKey =
      'onboarding.importWebViewGuideConfirmed.v1';
  static const String _timetableMenuGuideConfirmedKey =
      'onboarding.timetableMenuGuideConfirmed.v1';
  static const String _totalWeeksKey = 'settings.totalWeeks';
  static const String _reminderAdvanceMinutesKey =
      'settings.reminderAdvanceMinutes';
  static const String _eventReminderAdvanceMinutesKey =
      'settings.eventReminderAdvanceMinutes';
  static const String _languageCodeKey = 'settings.languageCode';
  static const String _appThemeModeKey = 'settings.appThemeMode';
  static const String _themePaletteIdKey = 'settings.themePaletteId';
  static const String _customThemePrimaryValueKey =
      'settings.customThemePrimaryValue';
  static const String _customThemeAccentValueKey =
      'settings.customThemeAccentValue';
  static const String _autoMuteEnabledKey = 'settings.autoMuteEnabled';
  static const String _courseReminderPersistentDisplayEnabledKey =
      'settings.courseReminderPersistentDisplayEnabled';
  // Legacy key from the former standalone foreground-service switch.
  static const String _legacyBackgroundServiceEnabledKey =
      'settings.backgroundServiceEnabled';

  static Future<StorageService> create({
    ExternalDataBackupStore? externalDataBackupStore,
  }) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final backupStore =
        externalDataBackupStore ?? const ExternalDataBackupStore();
    final diagnosticStore = CorruptRowDiagnosticStore(
      sharedPreferences: sharedPreferences,
    );
    await diagnosticStore.recordAll(
      _scanCorruptTimetableRows(sharedPreferences).diagnostics,
    );
    try {
      await StorageService(
        sharedPreferences: sharedPreferences,
      ).resumePendingSemesterOperation();
    } catch (_) {
      // Classification below will treat a malformed journal as damaged data.
    }
    final initialInternalState = _classifyInternalData(sharedPreferences);
    final recoveryStatus = initialInternalState == InternalDataState.valid
        ? ExternalDataRecoveryStatus.skippedInternalDataPresent
        : await backupStore.restoreToSharedPreferences(sharedPreferences);
    final postRecoveryScan = _scanCorruptTimetableRows(sharedPreferences);
    await diagnosticStore.recordAll(postRecoveryScan.diagnostics);
    if (_classifyInternalData(sharedPreferences) == InternalDataState.damaged &&
        postRecoveryScan.hasCorruptRows &&
        _classifyInternalData(
              sharedPreferences,
              allowCorruptTimetableRows: true,
            ) ==
            InternalDataState.valid) {
      await postRecoveryScan.sanitize(sharedPreferences);
    }
    if (_classifyInternalData(sharedPreferences) == InternalDataState.damaged) {
      throw StateError('Internal timetable data is damaged');
    }
    final service = StorageService(
      sharedPreferences: sharedPreferences,
      externalDataBackupStore: backupStore,
      lastRecoveryStatus: recoveryStatus,
    );
    await service.ensureSemesterMigration();
    if (_classifyInternalData(sharedPreferences) == InternalDataState.valid) {
      await service.syncExternalBackup();
    }
    return service;
  }

  Future<void> reload() => _sharedPreferences.reload();

  ExternalDataRecoveryStatus get lastRecoveryStatus => _lastRecoveryStatus;

  Future<int> consumePendingCorruptRowNoticeCount() {
    return CorruptRowDiagnosticStore(
      sharedPreferences: _sharedPreferences,
    ).consumePendingCount();
  }

  Future<bool> syncExternalBackup() async {
    final backupStore = _externalDataBackupStore;
    if (backupStore == null) {
      return false;
    }
    return backupStore.writeFromSharedPreferences(_sharedPreferences);
  }

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

    await _writeSemesterOperationJournal({
      'type': _semesterOperationCreate,
      'semester': semester.toJson(),
      'startDate': startDate.toIso8601String(),
    });
    await resumePendingSemesterOperation();
    return semester;
  }

  Future<void> setCurrentSemesterId(String semesterId, {bool sync = true}) {
    if (!sync) {
      return _setString(_currentSemesterIdKey, semesterId, sync: false);
    }
    return switchSemester(semesterId);
  }

  Future<void> switchSemester(String semesterId) async {
    await _writeSemesterOperationJournal({
      'type': _semesterOperationSwitch,
      'semesterId': semesterId,
    });
    await resumePendingSemesterOperation();
  }

  Future<void> initializeExistingSemester(
    String semesterId, {
    required DateTime startDate,
  }) async {
    await _writeSemesterOperationJournal({
      'type': _semesterOperationInitialize,
      'semesterId': semesterId,
      'startDate': startDate.toIso8601String(),
    });
    await resumePendingSemesterOperation();
  }

  Future<void> markSemesterInitialized(String semesterId) async {
    await _markSemesterInitialized(semesterId);
  }

  Future<void> _markSemesterInitialized(
    String semesterId, {
    bool sync = true,
  }) async {
    final semesters = loadSemesters();
    final updated = semesters
        .map(
          (semester) => semester.id == semesterId
              ? semester.copyWith(isInitialized: true)
              : semester,
        )
        .toList();
    await _saveSemesters(updated, sync: sync);
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
    final currentId = currentSemesterId;
    String? replacementSemesterId;
    if (currentId == semesterId) {
      for (final semester in remainingSemesters) {
        if (semester.isInitialized) {
          replacementSemesterId = semester.id;
          break;
        }
      }
    }

    await _writeSemesterOperationJournal({
      'type': _semesterOperationDelete,
      'semesterId': semesterId,
      'replacementSemesterId': replacementSemesterId,
    });
    await resumePendingSemesterOperation();
    return currentSemesterId;
  }

  Future<void> resumePendingSemesterOperation() async {
    final rawJournal = _sharedPreferences.getString(
      _semesterOperationJournalKey,
    );
    if (rawJournal == null) {
      return;
    }

    final decoded = jsonDecode(rawJournal);
    if (decoded is! Map) {
      throw StateError('Semester operation journal is invalid');
    }
    final journal = Map<String, dynamic>.from(decoded);
    switch (journal['type']) {
      case _semesterOperationCreate:
        await _applyCreateSemesterOperation(journal);
      case _semesterOperationInitialize:
        await _applyInitializeSemesterOperation(journal);
      case _semesterOperationSwitch:
        await _applySwitchSemesterOperation(journal);
      case _semesterOperationDelete:
        await _applyDeleteSemesterOperation(journal);
      default:
        throw StateError('Semester operation journal type is invalid');
    }

    await _remove(_semesterOperationJournalKey, sync: false);
    await syncExternalBackup();
  }

  Future<void> _writeSemesterOperationJournal(Map<String, dynamic> journal) {
    return _setString(
      _semesterOperationJournalKey,
      jsonEncode(journal),
      sync: false,
    );
  }

  Future<void> _applyCreateSemesterOperation(
    Map<String, dynamic> journal,
  ) async {
    final rawSemester = journal['semester'];
    final startDate = DateTime.tryParse('${journal['startDate'] ?? ''}');
    if (rawSemester is! Map || startDate == null) {
      throw StateError('Semester creation journal is invalid');
    }
    final semester = Semester.fromJson(Map<String, dynamic>.from(rawSemester));
    final semesters = loadSemesters();
    if (!semesters.any((item) => item.id == semester.id)) {
      await _saveSemesters([...semesters, semester], sync: false);
    }
    await _setString(_currentSemesterIdKey, semester.id, sync: false);
    await _setString(
      _semesterScopedKey(_semesterStartDateKey, semesterId: semester.id),
      startDate.toIso8601String(),
      sync: false,
    );
  }

  Future<void> _applyInitializeSemesterOperation(
    Map<String, dynamic> journal,
  ) async {
    final semesterId = journal['semesterId'];
    final startDate = DateTime.tryParse('${journal['startDate'] ?? ''}');
    if (semesterId is! String ||
        startDate == null ||
        !loadSemesters().any((semester) => semester.id == semesterId)) {
      throw StateError('Semester initialization journal is invalid');
    }
    await _setString(
      _semesterScopedKey(_semesterStartDateKey, semesterId: semesterId),
      startDate.toIso8601String(),
      sync: false,
    );
    await _markSemesterInitialized(semesterId, sync: false);
  }

  Future<void> _applySwitchSemesterOperation(
    Map<String, dynamic> journal,
  ) async {
    final semesterId = journal['semesterId'];
    if (semesterId is! String ||
        !loadSemesters().any((semester) => semester.id == semesterId)) {
      throw StateError('Semester switch journal is invalid');
    }
    await _setString(_currentSemesterIdKey, semesterId, sync: false);
  }

  Future<void> _applyDeleteSemesterOperation(
    Map<String, dynamic> journal,
  ) async {
    final semesterId = journal['semesterId'];
    final replacementSemesterId = journal['replacementSemesterId'];
    if (semesterId is! String ||
        (replacementSemesterId != null && replacementSemesterId is! String)) {
      throw StateError('Semester deletion journal is invalid');
    }

    final remainingSemesters = loadSemesters()
        .where((semester) => semester.id != semesterId)
        .toList();
    await _saveSemesters(remainingSemesters, sync: false);
    await _deleteSemesterScopedData(semesterId, sync: false);
    if (currentSemesterId != semesterId) {
      return;
    }
    if (replacementSemesterId != null &&
        remainingSemesters.any(
          (semester) => semester.id == replacementSemesterId,
        )) {
      await _setString(
        _currentSemesterIdKey,
        replacementSemesterId,
        sync: false,
      );
      return;
    }
    await _remove(_currentSemesterIdKey, sync: false);
  }

  Future<void> ensureSemesterMigration() async {
    await resumePendingSemesterOperation();
    final migrationVersion =
        _sharedPreferences.getInt(_semesterMigrationVersionKey) ?? 0;
    final migrationState = _sharedPreferences.getString(
      _semesterMigrationStateKey,
    );
    var existingSemesters = loadSemesters();
    final legacyUser = _hasLegacyTimetableData();
    if (migrationVersion >= _semesterMigrationVersion &&
        existingSemesters.isNotEmpty &&
        currentSemesterId != null &&
        migrationState != _migrationStateInProgress &&
        (migrationState == _migrationStateComplete || !legacyUser)) {
      return;
    }

    Semester targetSemester;
    final recordedTargetId = _sharedPreferences.getString(
      _semesterMigrationTargetIdKey,
    );
    final currentId = currentSemesterId;
    final reusableTargetId =
        recordedTargetId != null &&
            existingSemesters.any((semester) => semester.id == recordedTargetId)
        ? recordedTargetId
        : currentId;
    Semester? reusableTarget;
    for (final semester in existingSemesters) {
      if (semester.id == reusableTargetId) {
        reusableTarget = semester;
        break;
      }
    }
    if (reusableTarget != null) {
      targetSemester = reusableTarget;
    } else if (existingSemesters.isNotEmpty) {
      targetSemester = existingSemesters.first;
    } else {
      targetSemester = Semester(
        id: Semester.createId(),
        name: _defaultSemesterName(1),
        createdAt: DateTime.now(),
        isInitialized: legacyUser,
      );
      existingSemesters = [targetSemester];
      await _saveSemesters(existingSemesters, sync: false);
    }

    await _setString(
      _semesterMigrationTargetIdKey,
      targetSemester.id,
      sync: false,
    );
    await _setString(
      _semesterMigrationStateKey,
      _migrationStateInProgress,
      sync: false,
    );
    await setCurrentSemesterId(targetSemester.id, sync: false);
    await _migrateLegacyTimetableData(
      targetSemester.id,
      legacyUser: legacyUser,
      sync: false,
    );
    final scopedCoursesKey = _semesterScopedKey(
      _coursesKey,
      semesterId: targetSemester.id,
    );
    final scopedEventsKey = _semesterScopedKey(
      _eventsKey,
      semesterId: targetSemester.id,
    );
    if (!_canDecodeCourses(_sharedPreferences, scopedCoursesKey) ||
        !_canDecodeEvents(_sharedPreferences, scopedEventsKey)) {
      throw StateError('Migrated timetable payload is invalid');
    }
    await _setInt(
      _semesterMigrationVersionKey,
      _semesterMigrationVersion,
      sync: false,
    );
    await _setString(
      _semesterMigrationStateKey,
      _migrationStateComplete,
      sync: false,
    );
    await syncExternalBackup();
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
    return _remove(
      _semesterScopedKey(_coursesKey, semesterId: currentSemesterId),
    );
  }

  Future<void> clearAllTimetableData() async {
    final semesterId = currentSemesterId;
    await _remove(
      _semesterScopedKey(_coursesKey, semesterId: semesterId),
      sync: false,
    );
    await _remove(
      _semesterScopedKey(_eventsKey, semesterId: semesterId),
      sync: false,
    );
    await syncExternalBackup();
  }

  double readPixelsPerMinute({required double fallback}) {
    return _sharedPreferences.getDouble(
          _currentSemesterKey(_pixelsPerMinuteKey),
        ) ??
        fallback;
  }

  Future<void> writePixelsPerMinute(double value) {
    return _setDouble(_currentSemesterKey(_pixelsPerMinuteKey), value);
  }

  int readClassDuration({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_classDurationKey)) ??
        fallback;
  }

  Future<void> writeClassDuration(int value) {
    return _setInt(_currentSemesterKey(_classDurationKey), value);
  }

  int readShortBreak({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_shortBreakKey)) ??
        fallback;
  }

  Future<void> writeShortBreak(int value) {
    return _setInt(_currentSemesterKey(_shortBreakKey), value);
  }

  bool readBigBreakEnabled({required bool fallback}) {
    return _sharedPreferences.getBool(
          _currentSemesterKey(_bigBreakEnabledKey),
        ) ??
        fallback;
  }

  Future<void> writeBigBreakEnabled(bool value) {
    return _setBool(_currentSemesterKey(_bigBreakEnabledKey), value);
  }

  int readBigBreak({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_bigBreakKey)) ??
        fallback;
  }

  Future<void> writeBigBreak(int value) {
    return _setInt(_currentSemesterKey(_bigBreakKey), value);
  }

  int readBigBreakAfterPeriod({required int fallback}) {
    return _sharedPreferences.getInt(
          _currentSemesterKey(_bigBreakAfterPeriodKey),
        ) ??
        fallback;
  }

  Future<void> writeBigBreakAfterPeriod(int value) {
    return _setInt(_currentSemesterKey(_bigBreakAfterPeriodKey), value);
  }

  List<int>? readBigBreakAfterPeriods() {
    final values = _sharedPreferences.getStringList(
      _currentSemesterKey(_bigBreakAfterPeriodsKey),
    );
    if (values != null) {
      return values.map(int.tryParse).whereType<int>().toList(growable: false);
    }

    final legacyKey = _currentSemesterKey(_bigBreakAfterPeriodKey);
    if (!_sharedPreferences.containsKey(legacyKey)) {
      return null;
    }
    final legacyValue = _sharedPreferences.getInt(legacyKey);
    return legacyValue == null ? null : <int>[legacyValue];
  }

  Future<void> writeBigBreakAfterPeriods(List<int> values) {
    return _setStringList(
      _currentSemesterKey(_bigBreakAfterPeriodsKey),
      values.map((value) => value.toString()).toList(growable: false),
    );
  }

  String readMorningStartTime({required String fallback}) {
    return _sharedPreferences.getString(
          _currentSemesterKey(_morningStartTimeKey),
        ) ??
        fallback;
  }

  Future<void> writeMorningStartTime(String value) {
    return _setString(_currentSemesterKey(_morningStartTimeKey), value);
  }

  int readMorningClasses({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_morningClassesKey)) ??
        fallback;
  }

  Future<void> writeMorningClasses(int value) {
    return _setInt(_currentSemesterKey(_morningClassesKey), value);
  }

  List<String>? readMorningPeriodStartTimes() {
    return _sharedPreferences.getStringList(
      _currentSemesterKey(_morningPeriodStartTimesKey),
    );
  }

  Future<void> writeMorningPeriodStartTimes(List<String> values) {
    return _setStringList(
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
    return _setString(_currentSemesterKey(_afternoonStartTimeKey), value);
  }

  int readAfternoonClasses({required int fallback}) {
    return _sharedPreferences.getInt(
          _currentSemesterKey(_afternoonClassesKey),
        ) ??
        fallback;
  }

  Future<void> writeAfternoonClasses(int value) {
    return _setInt(_currentSemesterKey(_afternoonClassesKey), value);
  }

  List<String>? readAfternoonPeriodStartTimes() {
    return _sharedPreferences.getStringList(
      _currentSemesterKey(_afternoonPeriodStartTimesKey),
    );
  }

  Future<void> writeAfternoonPeriodStartTimes(List<String> values) {
    return _setStringList(
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
    return _setString(_currentSemesterKey(_eveningStartTimeKey), value);
  }

  int readEveningClasses({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_eveningClassesKey)) ??
        fallback;
  }

  Future<void> writeEveningClasses(int value) {
    return _setInt(_currentSemesterKey(_eveningClassesKey), value);
  }

  List<String>? readEveningPeriodStartTimes() {
    return _sharedPreferences.getStringList(
      _currentSemesterKey(_eveningPeriodStartTimesKey),
    );
  }

  Future<void> writeEveningPeriodStartTimes(List<String> values) {
    return _setStringList(
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
    return _setString(
      _currentSemesterKey(_semesterStartDateKey),
      value.toIso8601String(),
    );
  }

  Future<void> writeSemesterStartDateFor(String semesterId, DateTime value) {
    return _setString(
      _semesterScopedKey(_semesterStartDateKey, semesterId: semesterId),
      value.toIso8601String(),
    );
  }

  bool readSemesterStartDatePromptShown({required bool fallback}) {
    return _sharedPreferences.getBool(_semesterStartDatePromptShownKey) ??
        fallback;
  }

  Future<void> writeSemesterStartDatePromptShown(bool value) {
    return _setBool(_semesterStartDatePromptShownKey, value);
  }

  bool readTimetableToolbarGuideConfirmed({required bool fallback}) {
    return _sharedPreferences.getBool(_timetableToolbarGuideConfirmedKey) ??
        fallback;
  }

  Future<void> writeTimetableToolbarGuideConfirmed(bool value) {
    return _setBool(_timetableToolbarGuideConfirmedKey, value);
  }

  bool readTimetableMenuGuideConfirmed({required bool fallback}) {
    return _sharedPreferences.getBool(_timetableMenuGuideConfirmedKey) ??
        fallback;
  }

  Future<void> writeTimetableMenuGuideConfirmed(bool value) {
    return _setBool(_timetableMenuGuideConfirmedKey, value);
  }

  bool readImportWebViewGuideConfirmed({required bool fallback}) {
    return _sharedPreferences.getBool(_importWebViewGuideConfirmedKey) ??
        fallback;
  }

  Future<void> writeImportWebViewGuideConfirmed(bool value) {
    return _setBool(_importWebViewGuideConfirmedKey, value);
  }

  int readTotalWeeks({required int fallback}) {
    return _sharedPreferences.getInt(_currentSemesterKey(_totalWeeksKey)) ??
        fallback;
  }

  Future<void> writeTotalWeeks(int value) {
    return _setInt(_currentSemesterKey(_totalWeeksKey), value);
  }

  int readReminderAdvanceMinutes({required int fallback}) {
    return _sharedPreferences.getInt(_reminderAdvanceMinutesKey) ?? fallback;
  }

  Future<void> writeReminderAdvanceMinutes(int value) {
    return _setInt(_reminderAdvanceMinutesKey, value);
  }

  int readEventReminderAdvanceMinutes({required int fallback}) {
    return _sharedPreferences.getInt(_eventReminderAdvanceMinutesKey) ??
        fallback;
  }

  Future<void> writeEventReminderAdvanceMinutes(int value) {
    return _setInt(_eventReminderAdvanceMinutesKey, value);
  }

  String readLanguageCode({required String fallback}) {
    return _sharedPreferences.getString(_languageCodeKey) ?? fallback;
  }

  AppThemeMode readAppThemeMode({AppThemeMode fallback = AppThemeMode.system}) {
    final stored = _sharedPreferences.getString(_appThemeModeKey);
    return AppThemeMode.values
            .where((mode) => mode.name == stored)
            .firstOrNull ??
        fallback;
  }

  Future<void> writeAppThemeMode(AppThemeMode value) {
    return _setString(_appThemeModeKey, value.name);
  }

  String readThemePaletteId({required String fallback}) {
    return _sharedPreferences.getString(_themePaletteIdKey) ?? fallback;
  }

  Future<void> writeThemePaletteId(String value) {
    return _setString(_themePaletteIdKey, value);
  }

  int readCustomThemePrimaryValue({required int fallback}) {
    return _sharedPreferences.getInt(_customThemePrimaryValueKey) ?? fallback;
  }

  Future<void> writeCustomThemePrimaryValue(int value) {
    return _setInt(_customThemePrimaryValueKey, value);
  }

  int readCustomThemeAccentValue({required int fallback}) {
    return _sharedPreferences.getInt(_customThemeAccentValueKey) ?? fallback;
  }

  Future<void> writeCustomThemeAccentValue(int value) {
    return _setInt(_customThemeAccentValueKey, value);
  }

  bool readAutoMuteEnabled({required bool fallback}) {
    return _sharedPreferences.getBool(_autoMuteEnabledKey) ?? fallback;
  }

  Future<void> writeAutoMuteEnabled(bool value) {
    return _setBool(_autoMuteEnabledKey, value);
  }

  bool readCourseReminderPersistentDisplayEnabled({required bool fallback}) {
    return _sharedPreferences.getBool(
          _courseReminderPersistentDisplayEnabledKey,
        ) ??
        _sharedPreferences.getBool(_legacyBackgroundServiceEnabledKey) ??
        fallback;
  }

  Future<void> writeCourseReminderPersistentDisplayEnabled(bool value) async {
    await _setBool(
      _courseReminderPersistentDisplayEnabledKey,
      value,
      sync: false,
    );
    await _setBool(_legacyBackgroundServiceEnabledKey, value, sync: false);
    await syncExternalBackup();
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

  Future<void> _saveSemesters(List<Semester> semesters, {bool sync = true}) {
    return _encodeList(
      key: _semestersKey,
      items: semesters.map((semester) => semester.toJson()),
      sync: sync,
    );
  }

  bool _hasLegacyTimetableData() {
    final keys = [
      _coursesKey,
      _eventsKey,
      _pixelsPerMinuteKey,
      _classDurationKey,
      _shortBreakKey,
      _bigBreakEnabledKey,
      _bigBreakKey,
      _bigBreakAfterPeriodKey,
      _bigBreakAfterPeriodsKey,
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
    bool sync = true,
  }) async {
    final scopedCoursesKey = _semesterScopedKey(
      _coursesKey,
      semesterId: semesterId,
    );
    if (_sharedPreferences.containsKey(_coursesKey) ||
        !_sharedPreferences.containsKey(scopedCoursesKey)) {
      final legacyCourses = _decodeList(
        key: _coursesKey,
        decode: Course.fromJson,
      ).map((course) => course.copyWith(semesterId: semesterId).toJson());
      await _encodeList(
        key: scopedCoursesKey,
        items: legacyCourses,
        sync: false,
      );
    }

    final scopedEventsKey = _semesterScopedKey(
      _eventsKey,
      semesterId: semesterId,
    );
    if (_sharedPreferences.containsKey(_eventsKey) ||
        !_sharedPreferences.containsKey(scopedEventsKey)) {
      final legacyEvents = _decodeList(
        key: _eventsKey,
        decode: Event.fromJson,
      ).map((event) => event.copyWith(semesterId: semesterId).toJson());
      await _encodeList(key: scopedEventsKey, items: legacyEvents, sync: false);
    }

    await _copyLegacySetting(_pixelsPerMinuteKey, semesterId: semesterId);
    await _copyLegacySetting(_classDurationKey, semesterId: semesterId);
    await _copyLegacySetting(_shortBreakKey, semesterId: semesterId);
    await _copyLegacySetting(_bigBreakEnabledKey, semesterId: semesterId);
    await _copyLegacySetting(_bigBreakKey, semesterId: semesterId);
    await _copyLegacySetting(_bigBreakAfterPeriodKey, semesterId: semesterId);
    await _copyLegacySetting(_bigBreakAfterPeriodsKey, semesterId: semesterId);
    await _copyLegacySetting(_morningStartTimeKey, semesterId: semesterId);
    await _copyLegacySetting(_morningClassesKey, semesterId: semesterId);
    await _copyLegacySetting(
      _morningPeriodStartTimesKey,
      semesterId: semesterId,
    );
    await _copyLegacySetting(_afternoonStartTimeKey, semesterId: semesterId);
    await _copyLegacySetting(_afternoonClassesKey, semesterId: semesterId);
    await _copyLegacySetting(
      _afternoonPeriodStartTimesKey,
      semesterId: semesterId,
    );
    await _copyLegacySetting(_eveningStartTimeKey, semesterId: semesterId);
    await _copyLegacySetting(_eveningClassesKey, semesterId: semesterId);
    await _copyLegacySetting(
      _eveningPeriodStartTimesKey,
      semesterId: semesterId,
    );
    await _copyLegacySetting(_semesterStartDateKey, semesterId: semesterId);
    await _copyLegacySetting(
      _semesterStartDatePromptShownKey,
      semesterId: semesterId,
    );
    await _copyLegacySetting(_totalWeeksKey, semesterId: semesterId);

    if (legacyUser && !_sharedPreferences.containsKey(_semesterStartDateKey)) {
      await _setString(
        _semesterScopedKey(_semesterStartDateKey, semesterId: semesterId),
        _defaultSemesterStartDate().toIso8601String(),
        sync: false,
      );
    }
    if (sync) {
      await syncExternalBackup();
    }
  }

  Future<void> _copyLegacySetting(
    String key, {
    required String semesterId,
  }) async {
    if (!_sharedPreferences.containsKey(key)) {
      return;
    }

    final scopedKey = _semesterScopedKey(key, semesterId: semesterId);
    final value = _sharedPreferences.get(key);
    if (value is int) {
      await _setInt(scopedKey, value, sync: false);
    } else if (value is double) {
      await _setDouble(scopedKey, value, sync: false);
    } else if (value is bool) {
      await _setBool(scopedKey, value, sync: false);
    } else if (value is String) {
      await _setString(scopedKey, value, sync: false);
    } else if (value is List<String>) {
      await _setStringList(scopedKey, value, sync: false);
    }
  }

  Future<void> _deleteSemesterScopedData(
    String semesterId, {
    bool sync = true,
  }) async {
    final prefix = 'semesters.$semesterId.';
    final keysToRemove = _sharedPreferences
        .getKeys()
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keysToRemove) {
      await _remove(key, sync: false);
    }
    if (sync) {
      await syncExternalBackup();
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
    bool sync = true,
  }) async {
    final rawItems = items.map(jsonEncode).toList();
    await _setStringList(key, rawItems, sync: sync);
  }

  Future<void> _setString(String key, String value, {bool sync = true}) async {
    await _sharedPreferences.setString(key, value);
    if (sync) {
      await syncExternalBackup();
    }
  }

  Future<void> _setStringList(
    String key,
    List<String> value, {
    bool sync = true,
  }) async {
    await _sharedPreferences.setStringList(key, value);
    if (sync) {
      await syncExternalBackup();
    }
  }

  Future<void> _setInt(String key, int value, {bool sync = true}) async {
    await _sharedPreferences.setInt(key, value);
    if (sync) {
      await syncExternalBackup();
    }
  }

  Future<void> _setDouble(String key, double value, {bool sync = true}) async {
    await _sharedPreferences.setDouble(key, value);
    if (sync) {
      await syncExternalBackup();
    }
  }

  Future<void> _setBool(String key, bool value, {bool sync = true}) async {
    await _sharedPreferences.setBool(key, value);
    if (sync) {
      await syncExternalBackup();
    }
  }

  Future<void> _remove(String key, {bool sync = true}) async {
    await _sharedPreferences.remove(key);
    if (sync) {
      await syncExternalBackup();
    }
  }

  static InternalDataState _classifyInternalData(
    SharedPreferences preferences, {
    bool allowCorruptTimetableRows = false,
  }) {
    try {
      final keys = preferences.getKeys();
      final scopedKeys = keys
          .where((key) => RegExp(r'^semesters\.[^.]+\.').hasMatch(key))
          .toList();
      final hasLegacyData =
          preferences.containsKey(_coursesKey) ||
          preferences.containsKey(_eventsKey);
      final hasSemesterData =
          preferences.containsKey(_semestersKey) ||
          preferences.containsKey(_currentSemesterIdKey) ||
          preferences.containsKey(_semesterOperationJournalKey) ||
          scopedKeys.isNotEmpty;
      if (!hasLegacyData && !hasSemesterData) {
        return InternalDataState.missing;
      }

      if (!_hasValidSemesterOperationJournal(preferences)) {
        return InternalDataState.damaged;
      }

      if (!_canDecodeCourses(
            preferences,
            _coursesKey,
            skipInvalidRows: allowCorruptTimetableRows,
          ) ||
          !_canDecodeEvents(
            preferences,
            _eventsKey,
            skipInvalidRows: allowCorruptTimetableRows,
          )) {
        return InternalDataState.damaged;
      }

      if (!preferences.containsKey(_semestersKey)) {
        return hasSemesterData
            ? InternalDataState.damaged
            : InternalDataState.valid;
      }

      final semesters = _tryDecodeList(
        preferences: preferences,
        key: _semestersKey,
        decode: Semester.fromJson,
        validateJson: _isValidSemesterJson,
      );
      if (semesters == null) {
        return InternalDataState.damaged;
      }
      if (semesters.isEmpty) {
        return hasLegacyData
            ? InternalDataState.valid
            : InternalDataState.missing;
      }

      final semesterIds = semesters.map((semester) => semester.id).toSet();
      if (semesterIds.length != semesters.length) {
        return InternalDataState.damaged;
      }
      if (!_hasValidMigrationMetadata(preferences, semesterIds)) {
        return InternalDataState.damaged;
      }
      final currentSemesterId = preferences.getString(_currentSemesterIdKey);
      if (currentSemesterId == null ||
          !semesterIds.contains(currentSemesterId)) {
        return InternalDataState.damaged;
      }

      for (final key in scopedKeys) {
        final semesterId = key.split('.')[1];
        if (!semesterIds.contains(semesterId)) {
          return InternalDataState.damaged;
        }
        if (key.endsWith('.courses.items') &&
            !_canDecodeCourses(
              preferences,
              key,
              skipInvalidRows: allowCorruptTimetableRows,
            )) {
          return InternalDataState.damaged;
        }
        if (key.endsWith('.events.items') &&
            !_canDecodeEvents(
              preferences,
              key,
              skipInvalidRows: allowCorruptTimetableRows,
            )) {
          return InternalDataState.damaged;
        }
      }
      return InternalDataState.valid;
    } catch (_) {
      return InternalDataState.damaged;
    }
  }

  static bool _canDecodeCourses(
    SharedPreferences preferences,
    String key, {
    bool skipInvalidRows = false,
  }) {
    return _tryDecodeList(
          preferences: preferences,
          key: key,
          decode: Course.fromJson,
          validateJson: _isValidCourseJson,
          skipInvalidRows: skipInvalidRows,
        ) !=
        null;
  }

  static bool _canDecodeEvents(
    SharedPreferences preferences,
    String key, {
    bool skipInvalidRows = false,
  }) {
    return _tryDecodeList(
          preferences: preferences,
          key: key,
          decode: Event.fromJson,
          validateJson: _isValidEventJson,
          skipInvalidRows: skipInvalidRows,
        ) !=
        null;
  }

  static List<T>? _tryDecodeList<T>({
    required SharedPreferences preferences,
    required String key,
    required T Function(Map<String, dynamic> json) decode,
    bool Function(Map<String, dynamic> json)? validateJson,
    bool skipInvalidRows = false,
  }) {
    try {
      if (!preferences.containsKey(key)) {
        return <T>[];
      }
      final rawItems = preferences.getStringList(key);
      if (rawItems == null) {
        return null;
      }

      final result = <T>[];
      for (final raw in rawItems) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) {
            throw const FormatException('Expected JSON object');
          }
          final json = Map<String, dynamic>.from(decoded);
          if (validateJson != null && !validateJson(json)) {
            throw const FormatException('Invalid row');
          }
          result.add(decode(json));
        } catch (_) {
          if (!skipInvalidRows) {
            return null;
          }
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  static bool _isValidSemesterJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = json['createdAt'];
    return id is String &&
        id.trim().isNotEmpty &&
        json['name'] is String &&
        createdAt is String &&
        DateTime.tryParse(createdAt) != null &&
        json['isInitialized'] is bool;
  }

  static bool _hasValidMigrationMetadata(
    SharedPreferences preferences,
    Set<String> semesterIds,
  ) {
    if (preferences.containsKey(_semesterMigrationVersionKey)) {
      final version = preferences.getInt(_semesterMigrationVersionKey);
      if (version == null || version < 0) {
        return false;
      }
    }
    if (preferences.containsKey(_semesterMigrationStateKey)) {
      final state = preferences.getString(_semesterMigrationStateKey);
      if (state != _migrationStateInProgress &&
          state != _migrationStateComplete) {
        return false;
      }
    }
    if (preferences.containsKey(_semesterMigrationTargetIdKey)) {
      final targetId = preferences.getString(_semesterMigrationTargetIdKey);
      if (targetId == null || !semesterIds.contains(targetId)) {
        return false;
      }
    }
    return true;
  }

  static bool _hasValidSemesterOperationJournal(SharedPreferences preferences) {
    if (!preferences.containsKey(_semesterOperationJournalKey)) {
      return true;
    }
    try {
      final raw = preferences.getString(_semesterOperationJournalKey);
      if (raw == null) {
        return false;
      }
      final decoded = jsonDecode(raw);
      return decoded is Map && decoded['type'] is String;
    } catch (_) {
      return false;
    }
  }

  static bool _isValidCourseJson(Map<String, dynamic> json) {
    final weeks = json['weeks'];
    return json['name'] is String &&
        json['weekday'] is int &&
        weeks is List &&
        weeks.every((week) => week is num || int.tryParse('$week') != null) &&
        json['startPeriod'] is int &&
        json['endPeriod'] is int &&
        json['colorValue'] is int;
  }

  static bool _isValidEventJson(Map<String, dynamic> json) {
    final dateTime = json['dateTime'];
    return json['name'] is String &&
        json['location'] is String &&
        dateTime is String &&
        DateTime.tryParse(dateTime) != null &&
        json['enableAlarm'] is bool;
  }

  static _CorruptTimetableRowScan _scanCorruptTimetableRows(
    SharedPreferences preferences,
  ) {
    final diagnostics = <CorruptRowDiagnosticCandidate>[];
    final sanitizedRowsByKey = <String, List<String>>{};
    for (final key in preferences.getKeys().where(_isTimetableRowListKey)) {
      List<String>? rawRows;
      try {
        rawRows = preferences.getStringList(key);
      } catch (_) {
        continue;
      }
      if (rawRows == null) {
        continue;
      }

      final validRows = <String>[];
      for (final rawRow in rawRows) {
        if (_isValidStoredTimetableRow(key, rawRow)) {
          validRows.add(rawRow);
          continue;
        }
        diagnostics.add(
          CorruptRowDiagnosticCandidate(
            sourceKey: key,
            rawValue: rawRow,
            reason: key.endsWith(_coursesKey)
                ? 'invalid_course_row'
                : 'invalid_event_row',
          ),
        );
      }
      if (validRows.length != rawRows.length) {
        sanitizedRowsByKey[key] = validRows;
      }
    }
    return _CorruptTimetableRowScan(
      diagnostics: diagnostics,
      sanitizedRowsByKey: sanitizedRowsByKey,
    );
  }

  static bool _isTimetableRowListKey(String key) {
    return key == _coursesKey ||
        key == _eventsKey ||
        key.endsWith('.$_coursesKey') ||
        key.endsWith('.$_eventsKey');
  }

  static bool _isValidStoredTimetableRow(String key, String rawRow) {
    try {
      final decoded = jsonDecode(rawRow);
      if (decoded is! Map) {
        return false;
      }
      final json = Map<String, dynamic>.from(decoded);
      if (key.endsWith(_coursesKey)) {
        if (!_isValidCourseJson(json)) {
          return false;
        }
        Course.fromJson(json);
        return true;
      }
      if (!_isValidEventJson(json)) {
        return false;
      }
      Event.fromJson(json);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _CorruptTimetableRowScan {
  const _CorruptTimetableRowScan({
    required this.diagnostics,
    required this.sanitizedRowsByKey,
  });

  final List<CorruptRowDiagnosticCandidate> diagnostics;
  final Map<String, List<String>> sanitizedRowsByKey;

  bool get hasCorruptRows => sanitizedRowsByKey.isNotEmpty;

  Future<void> sanitize(SharedPreferences preferences) async {
    for (final entry in sanitizedRowsByKey.entries) {
      await preferences.setStringList(entry.key, entry.value);
    }
  }
}
