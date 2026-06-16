import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:AnKe/models/course.dart';
import 'package:AnKe/models/event.dart';
import 'package:AnKe/models/semester.dart';
import 'package:AnKe/services/corrupt_row_diagnostic_store.dart';
import 'package:AnKe/services/external_data_backup_store.dart';
import 'package:AnKe/services/storage_service.dart';

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

  test(
    'restores valid external backup when internal business state is damaged',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeSnapshot(store, _sampleValues(languageCode: 'zh'));

      SharedPreferences.setMockInitialValues({
        'semesters.items': ['{broken json'],
        'semesters.currentId': 'broken-semester',
      });
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );

      expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
      expect(service.currentSemesterId, 'semester-1');
      expect(service.loadCourses().single.name, 'Math');
    },
  );

  test(
    'restores external backup when a scoped course row is damaged',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeSnapshot(store, _sampleValues(languageCode: 'zh'));
      final damagedInternal = _sampleValues(languageCode: 'en');
      damagedInternal['semesters.semester-1.courses.items'] = ['{broken json'];

      SharedPreferences.setMockInitialValues(damagedInternal);
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );

      expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
      expect(service.readLanguageCode(fallback: 'en'), 'zh');
      expect(service.loadCourses().single.name, 'Math');
    },
  );

  test(
    'resumes interrupted legacy timetable migration into recorded semester',
    () async {
      final semester = Semester(
        id: 'semester-target',
        name: '第 1 学期',
        createdAt: DateTime(2026, 1, 1),
        isInitialized: true,
      );
      final legacyCourse = Course(
        id: 'legacy-course',
        name: 'Math',
        location: 'Room 101',
        teacher: 'Dr. Lin',
        weekday: 1,
        weeks: const [1, 2],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      );
      SharedPreferences.setMockInitialValues({
        'semesters.items': [jsonEncode(semester.toJson())],
        'semesters.currentId': semester.id,
        'semesters.migrationState': 'in_progress',
        'semesters.migrationTargetId': semester.id,
        'courses.items': [jsonEncode(legacyCourse.toJson())],
      });

      final service = await StorageService.create(
        externalDataBackupStore: const _UnavailableBackupStore(),
      );
      final preferences = await SharedPreferences.getInstance();

      expect(service.loadCourses().single.name, 'Math');
      expect(preferences.getInt('semesters.migrationVersion'), 1);
      expect(preferences.getString('semesters.migrationState'), 'complete');
    },
  );

  test(
    'completing migration metadata preserves existing scoped courses',
    () async {
      final values = _sampleValues(languageCode: 'zh')
        ..remove('semesters.migrationVersion');
      SharedPreferences.setMockInitialValues(values);

      final service = await StorageService.create(
        externalDataBackupStore: const _UnavailableBackupStore(),
      );

      expect(service.loadCourses().single.name, 'Math');
    },
  );

  test(
    'restores external backup when migration metadata is malformed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeSnapshot(store, _sampleValues(languageCode: 'zh'));
      final damagedInternal = _sampleValues(languageCode: 'en');
      damagedInternal['semesters.migrationState'] = 42;

      SharedPreferences.setMockInitialValues(damagedInternal);
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );

      expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
      expect(service.readLanguageCode(fallback: 'en'), 'zh');
    },
  );

  test(
    'resumes interrupted semester creation from operation journal',
    () async {
      final firstSemester = Semester(
        id: 'semester-1',
        name: '第 1 学期',
        createdAt: DateTime(2026, 1, 1),
        isInitialized: true,
      );
      final secondSemester = Semester(
        id: 'semester-2',
        name: '第 2 学期',
        createdAt: DateTime(2026, 6, 1),
        isInitialized: true,
      );
      SharedPreferences.setMockInitialValues({
        'semesters.items': [jsonEncode(firstSemester.toJson())],
        'semesters.currentId': firstSemester.id,
        'semesters.operationJournal': jsonEncode({
          'type': 'create',
          'semester': secondSemester.toJson(),
          'startDate': '2026-09-07T00:00:00.000',
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      final service = await StorageService.create(
        externalDataBackupStore: const _UnavailableBackupStore(),
      );

      expect(service.currentSemesterId, secondSemester.id);
      expect(service.loadSemesters().map((semester) => semester.id), [
        firstSemester.id,
        secondSemester.id,
      ]);
      expect(service.readSemesterStartDate(), DateTime(2026, 9, 7));
      expect(preferences.containsKey('semesters.operationJournal'), isFalse);
    },
  );

  test(
    'resumes interrupted semester deletion and removes scoped data',
    () async {
      final firstSemester = Semester(
        id: 'semester-1',
        name: '第 1 学期',
        createdAt: DateTime(2026, 1, 1),
        isInitialized: true,
      );
      final secondSemester = Semester(
        id: 'semester-2',
        name: '第 2 学期',
        createdAt: DateTime(2026, 6, 1),
        isInitialized: true,
      );
      SharedPreferences.setMockInitialValues({
        'semesters.items': [jsonEncode(secondSemester.toJson())],
        'semesters.currentId': firstSemester.id,
        'semesters.semester-1.courses.items': <String>[],
        'semesters.operationJournal': jsonEncode({
          'type': 'delete',
          'semesterId': firstSemester.id,
          'replacementSemesterId': secondSemester.id,
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      final service = StorageService(sharedPreferences: preferences);

      await service.resumePendingSemesterOperation();

      expect(service.currentSemesterId, secondSemester.id);
      expect(
        preferences.containsKey('semesters.semester-1.courses.items'),
        isFalse,
      );
      expect(preferences.containsKey('semesters.operationJournal'), isFalse);
    },
  );

  test('resumes interrupted semester initialization', () async {
    final semester = Semester(
      id: 'semester-1',
      name: '第 1 学期',
      createdAt: DateTime(2026, 1, 1),
      isInitialized: false,
    );
    SharedPreferences.setMockInitialValues({
      'semesters.items': [jsonEncode(semester.toJson())],
      'semesters.currentId': semester.id,
      'semesters.operationJournal': jsonEncode({
        'type': 'initialize',
        'semesterId': semester.id,
        'startDate': '2026-02-23T00:00:00.000',
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final service = StorageService(sharedPreferences: preferences);

    await service.resumePendingSemesterOperation();

    expect(service.readCurrentSemester()!.isInitialized, isTrue);
    expect(service.readSemesterStartDate(), DateTime(2026, 2, 23));
    expect(preferences.containsKey('semesters.operationJournal'), isFalse);
  });

  test('resumes interrupted semester switch', () async {
    final firstSemester = Semester(
      id: 'semester-1',
      name: '第 1 学期',
      createdAt: DateTime(2026, 1, 1),
      isInitialized: true,
    );
    final secondSemester = Semester(
      id: 'semester-2',
      name: '第 2 学期',
      createdAt: DateTime(2026, 6, 1),
      isInitialized: true,
    );
    SharedPreferences.setMockInitialValues({
      'semesters.items': [
        jsonEncode(firstSemester.toJson()),
        jsonEncode(secondSemester.toJson()),
      ],
      'semesters.currentId': firstSemester.id,
      'semesters.operationJournal': jsonEncode({
        'type': 'switch',
        'semesterId': secondSemester.id,
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final service = StorageService(sharedPreferences: preferences);

    await service.resumePendingSemesterOperation();

    expect(service.currentSemesterId, secondSemester.id);
    expect(preferences.containsKey('semesters.operationJournal'), isFalse);
  });

  test(
    'restores external backup when semester operation journal is malformed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeSnapshot(store, _sampleValues(languageCode: 'zh'));
      final damagedInternal = _sampleValues(languageCode: 'en');
      damagedInternal['semesters.operationJournal'] = '{broken json';

      SharedPreferences.setMockInitialValues(damagedInternal);
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );
      final preferences = await SharedPreferences.getInstance();

      expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
      expect(service.readLanguageCode(fallback: 'en'), 'zh');
      expect(preferences.containsKey('semesters.operationJournal'), isFalse);
    },
  );

  test(
    'restores external backup and quarantines a scoped event row with invalid date time',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeSnapshot(store, _sampleValues(languageCode: 'zh'));
      final damagedInternal = _sampleValues(languageCode: 'en');
      final rawDamagedEvent = jsonEncode({
        'name': 'Broken Exam',
        'location': 'Room 404',
        'dateTime': 'not-a-date',
        'enableAlarm': true,
      });
      damagedInternal['semesters.semester-1.events.items'] = [rawDamagedEvent];

      SharedPreferences.setMockInitialValues(damagedInternal);
      final service = await StorageService.create(
        externalDataBackupStore: store,
      );
      final preferences = await SharedPreferences.getInstance();
      final diagnostics = CorruptRowDiagnosticStore(
        sharedPreferences: preferences,
      );

      expect(service.lastRecoveryStatus, ExternalDataRecoveryStatus.restored);
      expect(service.loadEvents().single.name, 'Exam');
      expect(diagnostics.loadRecords().single.rawValue, rawDamagedEvent);
      expect(await service.consumePendingCorruptRowNoticeCount(), 1);
    },
  );

  test(
    'removes only corrupt timetable rows when external backup is unavailable',
    () async {
      final values = _sampleValues(languageCode: 'zh');
      final validCourseRows =
          values['semesters.semester-1.courses.items']! as List<String>;
      final validEventRows =
          values['semesters.semester-1.events.items']! as List<String>;
      values['semesters.semester-1.courses.items'] = [
        ...validCourseRows,
        '{broken course',
      ];
      values['semesters.semester-1.events.items'] = [
        ...validEventRows,
        jsonEncode({
          'name': 'Broken Exam',
          'location': 'Room 404',
          'dateTime': 'not-a-date',
          'enableAlarm': true,
        }),
      ];

      SharedPreferences.setMockInitialValues(values);
      final service = await StorageService.create(
        externalDataBackupStore: const _UnavailableBackupStore(),
      );
      final preferences = await SharedPreferences.getInstance();
      final diagnostics = CorruptRowDiagnosticStore(
        sharedPreferences: preferences,
      );

      expect(service.loadCourses().single.name, 'Math');
      expect(service.loadEvents().single.name, 'Exam');
      expect(
        preferences.getStringList('semesters.semester-1.courses.items'),
        hasLength(1),
      );
      expect(
        preferences.getStringList('semesters.semester-1.events.items'),
        hasLength(1),
      );
      expect(diagnostics.loadRecords(), hasLength(2));
      expect(await service.consumePendingCorruptRowNoticeCount(), 2);
      expect(await service.consumePendingCorruptRowNoticeCount(), 0);
    },
  );

  test('does not sanitize structural damage without external backup', () async {
    SharedPreferences.setMockInitialValues({
      'semesters.items': ['{broken semester'],
      'semesters.currentId': 'semester-1',
    });

    expect(
      () => StorageService.create(
        externalDataBackupStore: const _UnavailableBackupStore(),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'rejects structurally damaged external backup when internal preferences are empty',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      await _writeSnapshot(store, {
        'semesters.items': ['{broken semester'],
        'semesters.currentId': 'semester-1',
      });
      SharedPreferences.setMockInitialValues({});

      expect(
        () => StorageService.create(externalDataBackupStore: store),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'does not publish local corrupt-row diagnostics to external backup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'storage-service-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = ExternalDataBackupStore(externalFilesDirectory: directory);
      final values = _sampleValues(languageCode: 'zh');
      values[CorruptRowDiagnosticStore.recordsKey] = ['diagnostic'];
      values[CorruptRowDiagnosticStore.pendingCountKey] = 1;
      SharedPreferences.setMockInitialValues(values);
      final preferences = await SharedPreferences.getInstance();

      expect(await store.writeFromSharedPreferences(preferences), isTrue);

      final snapshot = await store.readPreferences();
      expect(snapshot, isNotNull);
      expect(
        snapshot!.containsKey(CorruptRowDiagnosticStore.recordsKey),
        isFalse,
      );
      expect(
        snapshot.containsKey(CorruptRowDiagnosticStore.pendingCountKey),
        isFalse,
      );
    },
  );

  test(
    'app theme mode defaults to system and rejects unknown values',
    () async {
      SharedPreferences.setMockInitialValues({});
      var preferences = await SharedPreferences.getInstance();
      var storage = StorageService(sharedPreferences: preferences);

      expect(storage.readAppThemeMode(), AppThemeMode.system);

      await storage.writeAppThemeMode(AppThemeMode.dark);
      expect(storage.readAppThemeMode(), AppThemeMode.dark);

      SharedPreferences.setMockInitialValues({
        'settings.appThemeMode': 'unknown',
      });
      preferences = await SharedPreferences.getInstance();
      storage = StorageService(sharedPreferences: preferences);

      expect(storage.readAppThemeMode(), AppThemeMode.system);
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
