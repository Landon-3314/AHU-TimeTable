import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/models/event.dart';
import 'package:timetable/models/semester.dart';
import 'package:timetable/services/external_data_backup_store.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  test(
    'restores from external backup when internal preferences are empty',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);

      await _writeSnapshot(store, _sampleValues(languageCode: 'zh'));

      SharedPreferences.setMockInitialValues({});
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );

      expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
      expect(service.currentSemesterId, 'semester-1');
      expect(service.loadCourses().single.name, 'Math');
      expect(service.loadEvents().single.name, 'Exam');
      expect(service.readLanguageCode(fallback: 'en'), 'zh');
    },
  );

  test(
    'keeps existing internal data and refreshes a stale external backup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);

      await _writeSnapshot(store, _sampleValues(languageCode: 'stale'));

      SharedPreferences.setMockInitialValues(_sampleValues(languageCode: 'en'));
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );

      expect(
        service.lastRecoveryStatus,
        ExternalDataRecoveryStatus.skippedInternalDataPresent,
      );
      expect(service.readLanguageCode(fallback: 'zh'), 'en');

      final refreshedSnapshot = await store.readPreferences();
      expect(refreshedSnapshot!['settings.languageCode'], 'en');
    },
  );

  test(
    'clearing timetable data updates backup so deleted records stay deleted',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);

      SharedPreferences.setMockInitialValues(_sampleValues(languageCode: 'zh'));
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );

      await service.clearAllTimetableData();

      final snapshot = await store.readPreferences();
      expect(snapshot, isNotNull);
      expect(
        snapshot!.containsKey('semesters.semester-1.courses.items'),
        isFalse,
      );
      expect(
        snapshot.containsKey('semesters.semester-1.events.items'),
        isFalse,
      );

      SharedPreferences.setMockInitialValues({});
      final restored = await StorageService.create(
        externalDataBackupStore: store,
      );

      expect(restored.loadCourses(), isEmpty);
      expect(restored.loadEvents(), isEmpty);
    },
  );

  test(
    'external backup unavailable keeps SharedPreferences behavior',
    () async {
      SharedPreferences.setMockInitialValues({});

      final service = await StorageService.create(
        externalDataBackupStore: const _UnavailableBackupStore(),
      );

      expect(
        service.lastRecoveryStatus,
        ExternalDataRecoveryStatus.unavailable,
      );
      expect(service.currentSemesterId, isNotNull);
      expect(service.loadCourses(), isEmpty);
    },
  );
}

Future<void> _writeSnapshot(
  ExternalDataBackupStore store,
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  expect(await store.writeFromSharedPreferences(prefs), isTrue);
}

Map<String, Object> _sampleValues({required String languageCode}) {
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
  final event = Event(
    id: 'event-1',
    name: 'Exam',
    location: 'Room 102',
    dateTime: DateTime(2026, 5, 20, 9),
    enableAlarm: true,
    semesterId: semester.id,
  );

  return {
    'semesters.items': [jsonEncode(semester.toJson())],
    'semesters.currentId': semester.id,
    'semesters.migrationVersion': 1,
    'semesters.${semester.id}.courses.items': [jsonEncode(course.toJson())],
    'semesters.${semester.id}.events.items': [jsonEncode(event.toJson())],
    'settings.languageCode': languageCode,
  };
}

class _UnavailableBackupStore extends ExternalDataBackupStore {
  const _UnavailableBackupStore();

  @override
  Future<bool> writeFromSharedPreferences(SharedPreferences preferences) async {
    return false;
  }

  @override
  Future<ExternalDataRecoveryStatus> restoreToSharedPreferences(
    SharedPreferences preferences,
  ) async {
    return ExternalDataRecoveryStatus.unavailable;
  }
}
