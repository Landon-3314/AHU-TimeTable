part of 'storage_service.dart';

InternalDataState _classifyInternalData(
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
    if (currentSemesterId == null || !semesterIds.contains(currentSemesterId)) {
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

bool _canDecodeCourses(
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

bool _canDecodeEvents(
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

List<T>? _tryDecodeList<T>({
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

bool _isValidSemesterJson(Map<String, dynamic> json) {
  final id = json['id'];
  final createdAt = json['createdAt'];
  return id is String &&
      id.trim().isNotEmpty &&
      json['name'] is String &&
      createdAt is String &&
      DateTime.tryParse(createdAt) != null &&
      json['isInitialized'] is bool;
}

bool _hasValidMigrationMetadata(
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

bool _hasValidSemesterOperationJournal(SharedPreferences preferences) {
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

bool _isValidCourseJson(Map<String, dynamic> json) {
  final weeks = json['weeks'];
  return json['name'] is String &&
      json['weekday'] is int &&
      weeks is List &&
      weeks.every((week) => week is num || int.tryParse('$week') != null) &&
      json['startPeriod'] is int &&
      json['endPeriod'] is int &&
      json['colorValue'] is int;
}

bool _isValidEventJson(Map<String, dynamic> json) {
  final dateTime = json['dateTime'];
  return json['name'] is String &&
      json['location'] is String &&
      dateTime is String &&
      DateTime.tryParse(dateTime) != null &&
      json['enableAlarm'] is bool;
}

_CorruptTimetableRowScan _scanCorruptTimetableRows(
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

bool _isTimetableRowListKey(String key) {
  return key == _coursesKey ||
      key == _eventsKey ||
      key.endsWith('.$_coursesKey') ||
      key.endsWith('.$_eventsKey');
}

bool _isValidStoredTimetableRow(String key, String rawRow) {
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
