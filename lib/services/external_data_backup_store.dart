import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_platform.dart';

enum ExternalDataRecoveryStatus {
  unavailable,
  noBackup,
  invalidBackup,
  restored,
  failed,
  skippedInternalDataPresent,
}

class ExternalDataBackupStore {
  const ExternalDataBackupStore({
    Directory? externalFilesDirectory,
    AppStoragePlatform platform = const AppStoragePlatform(),
  }) : _externalFilesDirectory = externalFilesDirectory,
       _platform = platform;

  static const int _schemaVersion = 1;
  static const String _storageDirectoryName = 'storage';
  static const String _backupFileName = 'timetable-data.v1.json';

  final Directory? _externalFilesDirectory;
  final AppStoragePlatform _platform;

  Future<bool> writeFromSharedPreferences(SharedPreferences preferences) async {
    final file = await _backupFileOrNull();
    if (file == null) {
      return false;
    }

    try {
      await file.parent.create(recursive: true);
      final snapshot = _buildSnapshot(_businessPreferences(preferences));
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonEncode(snapshot), flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, Object>?> readPreferences() async {
    final file = await _backupFileOrNull();
    if (file == null || !await file.exists()) {
      return null;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _quarantine(file);
        return null;
      }

      final preferences = _validateSnapshot(Map<String, Object?>.from(decoded));
      if (preferences == null) {
        await _quarantine(file);
      }
      return preferences;
    } catch (_) {
      await _quarantine(file);
      return null;
    }
  }

  Future<ExternalDataRecoveryStatus> restoreToSharedPreferences(
    SharedPreferences preferences,
  ) async {
    final file = await _backupFileOrNull();
    if (file == null) {
      return ExternalDataRecoveryStatus.unavailable;
    }
    if (!await file.exists()) {
      return ExternalDataRecoveryStatus.noBackup;
    }

    final snapshot = await readPreferences();
    if (snapshot == null) {
      return ExternalDataRecoveryStatus.invalidBackup;
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
