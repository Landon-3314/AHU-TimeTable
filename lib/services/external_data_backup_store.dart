import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_platform.dart';

abstract interface class ExternalDataBackupFileOperations {
  const ExternalDataBackupFileOperations();

  Future<void> writeString(File file, String contents);

  Future<String> readString(File file);

  Future<void> rename(File file, String newPath);

  Future<void> delete(File file);

  Future<bool> exists(File file);
}

class IoExternalDataBackupFileOperations
    implements ExternalDataBackupFileOperations {
  const IoExternalDataBackupFileOperations();

  @override
  Future<void> writeString(File file, String contents) {
    return file.writeAsString(contents, flush: true);
  }

  @override
  Future<String> readString(File file) => file.readAsString();

  @override
  Future<void> rename(File file, String newPath) async {
    await file.rename(newPath);
  }

  @override
  Future<void> delete(File file) => file.delete();

  @override
  Future<bool> exists(File file) => file.exists();
}

enum ExternalDataRecoveryStatus {
  unavailable,
  noBackup,
  invalidBackup,
  restored,
  failed,
  skippedInternalDataPresent,
}

class _SnapshotCandidate {
  const _SnapshotCandidate({
    required this.file,
    required this.preferences,
    required this.writtenAt,
    required this.priority,
  });

  final File file;
  final Map<String, Object> preferences;
  final DateTime writtenAt;
  final int priority;
}

class _SnapshotSearchResult {
  const _SnapshotSearchResult({
    required this.hadCandidates,
    required this.bestCandidate,
  });

  final bool hadCandidates;
  final _SnapshotCandidate? bestCandidate;
}

class ExternalDataBackupStore {
  const ExternalDataBackupStore({
    Directory? externalFilesDirectory,
    AppStoragePlatform platform = const AppStoragePlatform(),
    ExternalDataBackupFileOperations fileOperations =
        const IoExternalDataBackupFileOperations(),
  }) : _externalFilesDirectory = externalFilesDirectory,
       _platform = platform,
       _fileOperations = fileOperations;

  static const int _schemaVersion = 1;
  static const String _storageDirectoryName = 'storage';
  static const String _backupFileName = 'timetable-data.v1.json';
  static final Map<String, Future<void>> _writeQueues = {};
  static int _temporarySequence = 0;

  final Directory? _externalFilesDirectory;
  final AppStoragePlatform _platform;
  final ExternalDataBackupFileOperations _fileOperations;

  Future<bool> writeFromSharedPreferences(SharedPreferences preferences) async {
    final file = await _backupFileOrNull();
    if (file == null) {
      return false;
    }

    return _enqueueWrite(file.path, () => _writeSnapshot(file, preferences));
  }

  Future<bool> _writeSnapshot(File file, SharedPreferences preferences) async {
    final sequence = _temporarySequence++;
    final suffix = '${DateTime.now().microsecondsSinceEpoch}-$sequence';
    final tempFile = File('${file.path}.tmp-$suffix');
    final previousFile = File('${file.path}.previous-$suffix');
    try {
      await file.parent.create(recursive: true);
      final snapshot = _buildSnapshot(_businessPreferences(preferences));
      await _fileOperations.writeString(tempFile, jsonEncode(snapshot));
      if (!_isValidSnapshotBody(await _fileOperations.readString(tempFile))) {
        return false;
      }

      final movedCurrent = await _moveCurrentToPrevious(file, previousFile);
      try {
        await _fileOperations.rename(tempFile, file.path);
      } catch (_) {
        if (movedCurrent) {
          await _restorePrevious(file, previousFile);
        }
        rethrow;
      }
      await _deleteObsoleteSnapshots(file);
      return true;
    } catch (_) {
      return false;
    } finally {
      await _deleteIfExists(tempFile);
    }
  }

  Future<bool> _enqueueWrite(
    String destinationPath,
    Future<bool> Function() operation,
  ) {
    final previous = _writeQueues[destinationPath] ?? Future<void>.value();
    final completer = Completer<bool>();
    final current = previous.catchError((_) {}).then<void>((_) async {
      try {
        completer.complete(await operation());
      } catch (_) {
        completer.complete(false);
      }
    });
    _writeQueues[destinationPath] = current;
    current.whenComplete(() {
      if (identical(_writeQueues[destinationPath], current)) {
        _writeQueues.remove(destinationPath);
      }
    });
    return completer.future;
  }

  Future<bool> _moveCurrentToPrevious(File file, File previousFile) async {
    if (!await _fileOperations.exists(file)) {
      return false;
    }
    await _fileOperations.rename(file, previousFile.path);
    return true;
  }

  Future<void> _restorePrevious(File file, File previousFile) async {
    if (await _fileOperations.exists(file) ||
        !await _fileOperations.exists(previousFile)) {
      return;
    }
    try {
      await _fileOperations.rename(previousFile, file.path);
    } catch (_) {}
  }

  Future<void> _deleteObsoleteSnapshots(File file) async {
    if (!await file.parent.exists()) {
      return;
    }
    await for (final entity in file.parent.list()) {
      if (entity is File &&
          (entity.path.startsWith('${file.path}.previous-') ||
              entity.path.startsWith('${file.path}.tmp-'))) {
        await _deleteIfExists(entity);
      }
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await _fileOperations.exists(file)) {
        await _fileOperations.delete(file);
      }
    } catch (_) {}
  }

  Future<Map<String, Object>?> readPreferences() async {
    final file = await _backupFileOrNull();
    if (file == null) {
      return null;
    }

    final result = await _findBestSnapshot(file);
    return result.bestCandidate?.preferences;
  }

  Future<ExternalDataRecoveryStatus> restoreToSharedPreferences(
    SharedPreferences preferences,
  ) async {
    final file = await _backupFileOrNull();
    if (file == null) {
      return ExternalDataRecoveryStatus.unavailable;
    }

    final result = await _findBestSnapshot(file);
    final snapshot = result.bestCandidate?.preferences;
    if (snapshot == null) {
      return result.hadCandidates
          ? ExternalDataRecoveryStatus.invalidBackup
          : ExternalDataRecoveryStatus.noBackup;
    }

    try {
      await _clearBusinessPreferences(preferences);
      for (final entry in snapshot.entries) {
        await _writePreference(preferences, entry.key, entry.value);
      }
      return ExternalDataRecoveryStatus.restored;
    } catch (_) {
      return ExternalDataRecoveryStatus.failed;
    }
  }

  Future<File> debugBackupFile() async {
    final directory = await _externalFilesRoot();
    final root = directory ?? Directory.systemTemp;
    return File(
      '${root.path}${Platform.pathSeparator}$_storageDirectoryName'
      '${Platform.pathSeparator}$_backupFileName',
    );
  }

  Future<File?> _backupFileOrNull() async {
    final directory = await _externalFilesRoot();
    if (directory == null) {
      return null;
    }
    return File(
      '${directory.path}${Platform.pathSeparator}$_storageDirectoryName'
      '${Platform.pathSeparator}$_backupFileName',
    );
  }

  Future<Directory?> _externalFilesRoot() async {
    return _externalFilesDirectory ?? _platform.externalFilesDirectory();
  }

  Future<_SnapshotSearchResult> _findBestSnapshot(File mainFile) async {
    final files = <File>[];
    if (await _fileOperations.exists(mainFile)) {
      files.add(mainFile);
    }
    if (await mainFile.parent.exists()) {
      await for (final entity in mainFile.parent.list()) {
        if (entity is! File || entity.path == mainFile.path) {
          continue;
        }
        if (entity.path.startsWith('${mainFile.path}.previous-') ||
            entity.path.startsWith('${mainFile.path}.tmp-')) {
          files.add(entity);
        }
      }
    }

    _SnapshotCandidate? bestCandidate;
    for (final file in files) {
      final candidate = await _readCandidate(mainFile, file);
      if (candidate == null) {
        continue;
      }
      if (_isBetterCandidate(candidate, bestCandidate)) {
        bestCandidate = candidate;
      }
    }
    return _SnapshotSearchResult(
      hadCandidates: files.isNotEmpty,
      bestCandidate: bestCandidate,
    );
  }

  Future<_SnapshotCandidate?> _readCandidate(
    File mainFile,
    File candidateFile,
  ) async {
    try {
      final decoded = jsonDecode(
        await _fileOperations.readString(candidateFile),
      );
      if (decoded is! Map) {
        await _quarantine(candidateFile);
        return null;
      }
      final snapshot = Map<String, Object?>.from(decoded);
      final preferences = _validateSnapshot(snapshot);
      final writtenAt = DateTime.tryParse(
        snapshot['writtenAt'] as String? ?? '',
      );
      if (preferences == null || writtenAt == null) {
        await _quarantine(candidateFile);
        return null;
      }
      return _SnapshotCandidate(
        file: candidateFile,
        preferences: preferences,
        writtenAt: writtenAt,
        priority: _candidatePriority(mainFile, candidateFile),
      );
    } catch (_) {
      await _quarantine(candidateFile);
      return null;
    }
  }

  bool _isBetterCandidate(
    _SnapshotCandidate candidate,
    _SnapshotCandidate? current,
  ) {
    if (current == null || candidate.writtenAt.isAfter(current.writtenAt)) {
      return true;
    }
    return candidate.writtenAt.isAtSameMomentAs(current.writtenAt) &&
        candidate.priority > current.priority;
  }

  int _candidatePriority(File mainFile, File candidateFile) {
    if (candidateFile.path == mainFile.path) {
      return 3;
    }
    if (candidateFile.path.startsWith('${mainFile.path}.previous-')) {
      return 2;
    }
    return 1;
  }

  Map<String, Object> _businessPreferences(SharedPreferences preferences) {
    final result = <String, Object>{};
    final keys = preferences.getKeys().where(isBusinessPreferenceKey).toList()
      ..sort();
    for (final key in keys) {
      final value = preferences.get(key);
      if (value is int || value is double || value is bool || value is String) {
        result[key] = value as Object;
      } else if (value is List<String>) {
        result[key] = List<String>.of(value);
      }
    }
    return result;
  }

  Map<String, Object?> _buildSnapshot(Map<String, Object> preferences) {
    final payload = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'writtenAt': DateTime.now().toUtc().toIso8601String(),
      'preferences': preferences,
    };
    return <String, Object?>{...payload, 'sha256': _sha256For(payload)};
  }

  bool _isValidSnapshotBody(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          _validateSnapshot(Map<String, Object?>.from(decoded)) != null;
    } catch (_) {
      return false;
    }
  }

  Map<String, Object>? _validateSnapshot(Map<String, Object?> snapshot) {
    final schemaVersion = snapshot['schemaVersion'];
    final writtenAt = snapshot['writtenAt'];
    final rawPreferences = snapshot['preferences'];
    final shaValue = snapshot['sha256'];
    if (schemaVersion != _schemaVersion ||
        writtenAt is! String ||
        rawPreferences is! Map ||
        shaValue is! String ||
        !_isValidSha256(shaValue)) {
      return null;
    }

    final normalized = <String, Object>{};
    for (final entry in rawPreferences.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || !isBusinessPreferenceKey(key)) {
        return null;
      }
      if (value is int || value is double || value is bool || value is String) {
        normalized[key] = value as Object;
      } else if (value is List && value.every((item) => item is String)) {
        normalized[key] = value.cast<String>();
      } else {
        return null;
      }
    }

    final payload = <String, Object?>{
      'schemaVersion': schemaVersion,
      'writtenAt': writtenAt,
      'preferences': normalized,
    };
    if (_sha256For(payload) != shaValue.trim().toLowerCase()) {
      return null;
    }
    return normalized;
  }

  Future<void> _clearBusinessPreferences(SharedPreferences preferences) async {
    final keys = preferences.getKeys().where(isBusinessPreferenceKey).toList();
    for (final key in keys) {
      await preferences.remove(key);
    }
  }

  Future<void> _writePreference(
    SharedPreferences preferences,
    String key,
    Object value,
  ) {
    if (value is int) {
      return preferences.setInt(key, value);
    }
    if (value is double) {
      return preferences.setDouble(key, value);
    }
    if (value is bool) {
      return preferences.setBool(key, value);
    }
    if (value is String) {
      return preferences.setString(key, value);
    }
    if (value is List<String>) {
      return preferences.setStringList(key, value);
    }
    return Future<void>.value();
  }

  Future<void> _quarantine(File file) async {
    try {
      if (!await file.exists()) {
        return;
      }
      final invalidFile = File(
        '${file.path}.invalid-${DateTime.now().microsecondsSinceEpoch}',
      );
      await file.rename(invalidFile.path);
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  static bool isBusinessPreferenceKey(String key) {
    return key.startsWith('semesters.') ||
        key.startsWith('settings.') ||
        key.startsWith('onboarding.') ||
        key.startsWith('updates.');
  }

  static String _sha256For(Map<String, Object?> payload) {
    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  static bool _isValidSha256(String value) {
    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value.trim());
  }
}
