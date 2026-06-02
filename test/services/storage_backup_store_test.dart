import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/models/semester.dart';
import 'package:timetable/services/external_data_backup_store.dart';

void main() {
  test(
    'writes and restores business preferences from Android data snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));

      final semester = Semester(
        id: 'semester-1',
        name: '第 1 学期',
        createdAt: DateTime(2026, 1, 1),
        isInitialized: true,
      );
      final course = Course(
        id: 'course-1',
        name: 'Math',
        location: 'Room 101',
        teacher: 'Dr. Lin',
        weekday: 1,
        weeks: const [1, 2],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
        semesterId: semester.id,
      );

      SharedPreferences.setMockInitialValues({
        'semesters.items': [jsonEncode(semester.toJson())],
        'semesters.currentId': semester.id,
        'semesters.${semester.id}.courses.items': [jsonEncode(course.toJson())],
        'settings.languageCode': 'zh',
        'unrelated.cache': 'not backed up',
      });
      final sourcePrefs = await SharedPreferences.getInstance();
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);

      expect(await store.writeFromSharedPreferences(sourcePrefs), isTrue);

      final snapshot = await store.readPreferences();
      expect(snapshot, isNotNull);
      expect(snapshot!.keys, isNot(contains('unrelated.cache')));
      expect(snapshot['settings.languageCode'], 'zh');

      SharedPreferences.setMockInitialValues({});
      final restoredPrefs = await SharedPreferences.getInstance();
      final status = await store.restoreToSharedPreferences(restoredPrefs);

      expect(status, ExternalDataRecoveryStatus.restored);
      expect(restoredPrefs.getString('semesters.currentId'), semester.id);
      expect(
        restoredPrefs.getStringList('semesters.${semester.id}.courses.items'),
        hasLength(1),
      );
      expect(restoredPrefs.getString('unrelated.cache'), isNull);
    },
  );

  test('invalid snapshots are quarantined without throwing', () async {
    for (final invalidBody in <String>[
      '{broken json',
      jsonEncode({
        'schemaVersion': 99,
        'writtenAt': '2026-01-01T00:00:00.000Z',
        'preferences': <String, Object?>{},
        'sha256': '0' * 64,
      }),
      jsonEncode({
        'schemaVersion': 1,
        'writtenAt': '2026-01-01T00:00:00.000Z',
        'preferences': {'settings.languageCode': 'zh'},
        'sha256': '0' * 64,
      }),
    ]) {
      final directory = await Directory.systemTemp.createTemp('bad-backup-');
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      final file = await store.debugBackupFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(invalidBody);

      expect(await store.readPreferences(), isNull);
      expect(await file.exists(), isFalse);
      final quarantined = await file.parent
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) => file.path.contains('timetable-data.v1.json.invalid'))
          .toList();
      expect(quarantined, hasLength(1));
    }
  });

  test(
    'serializes concurrent snapshot writes and keeps the latest state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'serialized-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final operations = _DelayedFirstFinalRenameOperations();
      final store = ExternalDataBackupStore(
        externalFilesDirectory: directory,
        fileOperations: operations,
      );

      SharedPreferences.setMockInitialValues({
        'settings.languageCode': 'first',
      });
      final preferences = await SharedPreferences.getInstance();
      final firstWrite = store.writeFromSharedPreferences(preferences);
      await operations.firstFinalRenameStarted.future;

      await preferences.setString('settings.languageCode', 'second');
      final secondWrite = store.writeFromSharedPreferences(preferences);
      operations.releaseFirstFinalRename.complete();

      expect(await firstWrite, isTrue);
      expect(await secondWrite, isTrue);
      expect(
        (await store.readPreferences())!['settings.languageCode'],
        'second',
      );
    },
  );

  test(
    'recovers from a valid temporary snapshot when main snapshot is absent',
    () async {
      final directory = await Directory.systemTemp.createTemp('temp-recovery-');
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeLanguageSnapshot(store, 'zh');
      final mainFile = await store.debugBackupFile();
      await mainFile.rename('${mainFile.path}.tmp-interrupted');

      expect((await store.readPreferences())!['settings.languageCode'], 'zh');
    },
  );

  test(
    'recovers from a valid previous snapshot when main snapshot is invalid',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'previous-recovery-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeLanguageSnapshot(store, 'zh');
      final mainFile = await store.debugBackupFile();
      await mainFile.rename('${mainFile.path}.previous-interrupted');
      await mainFile.writeAsString('{broken json');

      expect((await store.readPreferences())!['settings.languageCode'], 'zh');
    },
  );

  test('rename failure preserves a valid recoverable snapshot', () async {
    final directory = await Directory.systemTemp.createTemp('rename-failure-');
    addTearDown(() => directory.delete(recursive: true));
    final store = ExternalDataBackupStore(externalFilesDirectory: directory);
    await _writeLanguageSnapshot(store, 'zh');
    final failingStore = ExternalDataBackupStore(
      externalFilesDirectory: directory,
      fileOperations: const _FailingFinalRenameOperations(),
    );

    expect(await _writeLanguageSnapshot(failingStore, 'en'), isFalse);
    expect((await store.readPreferences())!['settings.languageCode'], 'zh');
  });

  test(
    'successful snapshot commit removes obsolete temporary snapshots',
    () async {
      final directory = await Directory.systemTemp.createTemp('temp-cleanup-');
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeLanguageSnapshot(store, 'zh');
      final mainFile = await store.debugBackupFile();
      await mainFile.rename('${mainFile.path}.tmp-interrupted');

      expect(await _writeLanguageSnapshot(store, 'en'), isTrue);
      final temporaryFiles = await mainFile.parent
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .where((file) => file.path.startsWith('${mainFile.path}.tmp-'))
          .toList();
      expect(temporaryFiles, isEmpty);
    },
  );
}

Future<bool> _writeLanguageSnapshot(
  ExternalDataBackupStore store,
  String languageCode,
) async {
  SharedPreferences.setMockInitialValues({
    'settings.languageCode': languageCode,
  });
  final preferences = await SharedPreferences.getInstance();
  return store.writeFromSharedPreferences(preferences);
}

class _DelayedFirstFinalRenameOperations
    implements ExternalDataBackupFileOperations {
  final ExternalDataBackupFileOperations _delegate =
      const IoExternalDataBackupFileOperations();
  final Completer<void> firstFinalRenameStarted = Completer<void>();
  final Completer<void> releaseFirstFinalRename = Completer<void>();
  bool _didDelayFinalRename = false;

  @override
  Future<void> delete(File file) => _delegate.delete(file);

  @override
  Future<bool> exists(File file) => _delegate.exists(file);

  @override
  Future<String> readString(File file) => _delegate.readString(file);

  @override
  Future<void> rename(File file, String newPath) async {
    if (!_didDelayFinalRename &&
        file.path.contains('.tmp-') &&
        newPath.endsWith('timetable-data.v1.json')) {
      _didDelayFinalRename = true;
      firstFinalRenameStarted.complete();
      await releaseFirstFinalRename.future;
    }
    await _delegate.rename(file, newPath);
  }

  @override
  Future<void> writeString(File file, String contents) {
    return _delegate.writeString(file, contents);
  }
}

class _FailingFinalRenameOperations
    implements ExternalDataBackupFileOperations {
  const _FailingFinalRenameOperations();

  static const ExternalDataBackupFileOperations _delegate =
      IoExternalDataBackupFileOperations();

  @override
  Future<void> delete(File file) => _delegate.delete(file);

  @override
  Future<bool> exists(File file) => _delegate.exists(file);

  @override
  Future<String> readString(File file) => _delegate.readString(file);

  @override
  Future<void> rename(File file, String newPath) {
    if (file.path.contains('.tmp-') &&
        newPath.endsWith('timetable-data.v1.json')) {
      throw const FileSystemException('Injected final rename failure');
    }
    return _delegate.rename(file, newPath);
  }

  @override
  Future<void> writeString(File file, String contents) {
    return _delegate.writeString(file, contents);
  }
}
