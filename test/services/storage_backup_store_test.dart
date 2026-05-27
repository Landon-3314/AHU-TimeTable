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
}
