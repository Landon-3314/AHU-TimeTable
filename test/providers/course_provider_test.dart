import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/models/event.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  test('sortedCourseGroups groups by name and sorts records', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    await storage.ensureSemesterMigration();
    final provider = CourseProvider(storageService: storage);

    await provider.addCourses([
      Course(
        name: 'Math',
        location: 'Room B',
        teacher: 'Dr. Chen',
        weekday: 3,
        weeks: const [3, 4],
        startPeriod: 3,
        endPeriod: 4,
        colorValue: 0xFF7C9AF2,
      ),
      Course(
        name: 'Algorithms',
        location: 'Room C',
        teacher: 'Dr. Lin',
        weekday: 2,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF5BBE88,
      ),
      Course(
        name: 'math',
        location: 'Room A',
        teacher: 'Dr. Chen',
        weekday: 1,
        weeks: const [1, 2],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      ),
    ]);

    final groups = provider.sortedCourseGroups;

    expect(groups.map((group) => group.name), ['Algorithms', 'Math']);
    expect(groups.last.courses.map((course) => course.weekday), [1, 3]);
    expect(groups.last.courses.map((course) => course.location), [
      'Room A',
      'Room B',
    ]);
  });

  test(
    'mergeImportedEvents imports new exams once and skips duplicates',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = StorageService(sharedPreferences: preferences);
      await storage.ensureSemesterMigration();
      final provider = CourseProvider(storageService: storage);
      var reminderRefreshCount = 0;
      provider.bindReminderScheduler(() async {
        reminderRefreshCount += 1;
      });

      final exam = Event(
        id: 'exam-1',
        name: '离散数学（下）（期中）',
        location: '博学南楼B209',
        note: '座位号(1)',
        dateTime: DateTime(2026, 5, 18, 19),
        enableAlarm: true,
      );

      final firstImportCount = await provider.mergeImportedEvents([
        exam,
        exam.copyWith(id: 'exam-duplicate-in-batch'),
      ]);
      final secondImportCount = await provider.mergeImportedEvents([
        exam.copyWith(id: 'exam-duplicate-later'),
      ]);

      expect(firstImportCount, 1);
      expect(secondImportCount, 0);
      expect(provider.events, hasLength(1));
      expect(provider.events.single.name, '离散数学（下）（期中）');
      expect(provider.events.single.location, '博学南楼B209');
      expect(provider.events.single.note, '座位号(1)');
      expect(provider.events.single.dateTime, DateTime(2026, 5, 18, 19));
      expect(provider.events.single.enableAlarm, isTrue);
      expect(provider.events.single.semesterId, storage.currentSemesterId);
      expect(reminderRefreshCount, 1);
    },
  );

  test(
    'course imports replace their source batch and keep manual courses',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = StorageService(sharedPreferences: preferences);
      await storage.ensureSemesterMigration();
      final provider = CourseProvider(storageService: storage);
      final manualCourse = Course(
        id: 'manual-course',
        name: '手工课程',
        location: 'A101',
        teacher: '陈老师',
        weekday: DateTime.friday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      );
      final importedCourse = Course(
        id: 'imported-course-old',
        name: '编译原理',
        location: 'B201',
        teacher: '李老师',
        weekday: DateTime.monday,
        weeks: const [1, 2],
        startPeriod: 3,
        endPeriod: 4,
        colorValue: 0xFF56C8B4,
      );

      await provider.addCourse(manualCourse);
      await provider.mergeImportedCourses([importedCourse]);
      await provider.mergeImportedCourses([
        importedCourse.copyWith(
          id: 'imported-course-new',
          weekday: DateTime.tuesday,
          startPeriod: 5,
          endPeriod: 6,
        ),
      ]);

      expect(provider.courses, hasLength(2));
      expect(
        provider.courses.where((course) => course.id == 'manual-course'),
        hasLength(1),
      );
      final imported = provider.courses.singleWhere(
        (course) =>
            course.importSource == CourseProvider.academicTimetableImportSource,
      );
      expect(imported.id, 'imported-course-new');
      expect(imported.weekday, DateTime.tuesday);
      expect(imported.startPeriod, 5);
      expect(imported.importBatchId, isNotEmpty);
      final reloadedCourses = CourseProvider(storageService: storage).courses;
      expect(
        reloadedCourses
            .singleWhere(
              (course) =>
                  course.importSource ==
                  CourseProvider.academicTimetableImportSource,
            )
            .importBatchId,
        imported.importBatchId,
      );

      await provider.mergeImportedCourses(const []);

      expect(provider.courses, hasLength(1));
      expect(provider.courses.single.id, 'manual-course');
    },
  );

  test(
    'exam imports replace their source batch and keep manual events',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = StorageService(sharedPreferences: preferences);
      await storage.ensureSemesterMigration();
      final provider = CourseProvider(storageService: storage);
      final manualEvent = Event(
        id: 'manual-event',
        name: '社团活动',
        location: '操场',
        dateTime: DateTime(2026, 5, 18, 8),
        enableAlarm: false,
      );
      final exam = Event(
        id: 'exam-old',
        name: '离散数学（期中）',
        location: 'B209',
        note: '座位号(1)',
        dateTime: DateTime(2026, 5, 18, 19),
        enableAlarm: true,
      );

      await provider.addEvent(manualEvent);
      await provider.mergeImportedEvents([exam]);
      await provider.mergeImportedEvents([
        exam.copyWith(
          id: 'exam-new',
          location: 'A205',
          note: '座位号(9)',
          dateTime: DateTime(2026, 5, 22, 19),
        ),
      ]);

      expect(provider.events, hasLength(2));
      expect(
        provider.events.where((event) => event.id == 'manual-event'),
        hasLength(1),
      );
      final imported = provider.events.singleWhere(
        (event) =>
            event.importSource == CourseProvider.academicExamImportSource,
      );
      expect(imported.id, 'exam-new');
      expect(imported.location, 'A205');
      expect(imported.note, '座位号(9)');
      expect(imported.dateTime, DateTime(2026, 5, 22, 19));
      expect(imported.importBatchId, isNotEmpty);
      final reloadedEvents = CourseProvider(storageService: storage).events;
      expect(
        reloadedEvents
            .singleWhere(
              (event) =>
                  event.importSource == CourseProvider.academicExamImportSource,
            )
            .importBatchId,
        imported.importBatchId,
      );

      await provider.mergeImportedEvents(const []);

      expect(provider.events, hasLength(1));
      expect(provider.events.single.id, 'manual-event');
    },
  );

  test('course conflict requires explicit allowance before add', () async {
    final provider = await _createProvider();
    final existing = _course(id: 'existing', name: '大学英语');
    final conflicting = _course(
      id: 'conflicting',
      name: '线性代数',
      startPeriod: 2,
      endPeriod: 3,
    );

    expect(await provider.addCourse(existing), isTrue);
    expect(provider.findCourseConflicts([conflicting]), hasLength(1));
    expect(await provider.addCourse(conflicting), isFalse);
    expect(
      provider.courses.map((course) => course.id),
      isNot(contains('conflicting')),
    );

    expect(await provider.addCourse(conflicting, allowConflicts: true), isTrue);
    expect(
      provider.courses.map((course) => course.id),
      contains('conflicting'),
    );
  });

  test('duplicate course stays rejected when conflicts are allowed', () async {
    final provider = await _createProvider();
    final existing = _course(id: 'existing', name: '大学英语');
    final duplicate = existing.copyWith(id: 'duplicate');

    expect(await provider.addCourse(existing), isTrue);
    expect(await provider.addCourse(duplicate, allowConflicts: true), isFalse);
    expect(provider.courses, hasLength(1));
  });

  test('course update conflict requires explicit allowance', () async {
    final provider = await _createProvider();
    final existing = _course(id: 'existing', name: '大学英语');
    final edited = _course(
      id: 'edited',
      name: '线性代数',
      weekday: DateTime.tuesday,
    );

    await provider.addCourse(existing);
    await provider.addCourse(edited);
    final conflictingEdit = edited.copyWith(
      weekday: DateTime.monday,
      startPeriod: 2,
      endPeriod: 3,
    );

    expect(
      provider.findCourseConflicts([
        conflictingEdit,
      ], ignoredCourseId: edited.id),
      hasLength(1),
    );
    expect(
      await provider.updateCourse(
        originalCourse: edited,
        updatedCourse: conflictingEdit,
      ),
      isFalse,
    );
    expect(
      await provider.updateCourse(
        originalCourse: edited,
        updatedCourse: conflictingEdit,
        allowConflicts: true,
      ),
      isTrue,
    );
  });

  test('reschedule conflict requires explicit allowance', () async {
    final provider = await _createProvider();
    final existing = _course(id: 'existing', name: '大学英语');
    final moved = _course(id: 'moved', name: '线性代数', weekday: DateTime.tuesday);

    await provider.addCourse(existing);
    await provider.addCourse(moved);

    expect(
      provider.findRescheduleCourseConflicts(
        originalCourse: moved,
        sourceWeek: 1,
        targetWeek: 1,
        targetWeekday: DateTime.monday,
        targetStartPeriod: 1,
      ),
      hasLength(1),
    );
    expect(
      await provider.rescheduleCourseOccurrence(
        originalCourse: moved,
        sourceWeek: 1,
        targetWeek: 1,
        targetWeekday: DateTime.monday,
        targetStartPeriod: 1,
      ),
      isFalse,
    );
    expect(
      await provider.rescheduleCourseOccurrence(
        originalCourse: moved,
        sourceWeek: 1,
        targetWeek: 1,
        targetWeekday: DateTime.monday,
        targetStartPeriod: 1,
        allowConflicts: true,
      ),
      isTrue,
    );
  });

  test(
    'import conflict preflight ignores old batch and includes manual and incoming overlaps',
    () async {
      final provider = await _createProvider();
      await provider.addCourse(_course(id: 'manual', name: '手工课程'));
      await provider.mergeImportedCourses([
        _course(
          id: 'old-imported',
          name: '旧教务课程',
          weekday: DateTime.thursday,
          startPeriod: 7,
          endPeriod: 8,
        ),
      ]);

      final incoming = [
        _course(id: 'manual-conflict', name: '高等数学'),
        _course(
          id: 'batch-first',
          name: '数据结构',
          weekday: DateTime.wednesday,
          startPeriod: 3,
          endPeriod: 4,
        ),
        _course(
          id: 'batch-conflict',
          name: '操作系统',
          weekday: DateTime.wednesday,
          startPeriod: 4,
          endPeriod: 5,
        ),
        _course(
          id: 'old-only-conflict',
          name: '新教务课程',
          weekday: DateTime.thursday,
          startPeriod: 7,
          endPeriod: 8,
        ),
      ];

      final conflicts = provider.findImportedCourseConflicts(incoming);

      expect(
        conflicts.map((conflict) => conflict.candidate.id),
        containsAll(['manual-conflict', 'batch-conflict']),
      );
      expect(
        conflicts.map((conflict) => conflict.candidate.id),
        isNot(contains('old-only-conflict')),
      );
      expect(await provider.mergeImportedCourses(incoming), 0);
      expect(
        await provider.mergeImportedCourses(incoming, allowConflicts: true),
        incoming.length,
      );
    },
  );

  test(
    'course deletion returns record and restore is persistent and idempotent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = StorageService(sharedPreferences: preferences);
      await storage.ensureSemesterMigration();
      final provider = CourseProvider(storageService: storage);
      var reminderRefreshCount = 0;
      provider.bindReminderScheduler(() async {
        reminderRefreshCount += 1;
      });
      final course = _course(id: 'restore-course', name: '离散数学');
      await provider.addCourse(course);
      reminderRefreshCount = 0;

      final removed = await provider.removeCourse(course);

      expect(removed?.id, course.id);
      expect(provider.courses, isEmpty);
      expect(CourseProvider(storageService: storage).courses, isEmpty);
      expect(reminderRefreshCount, 1);

      await provider.restoreCourse(removed!);

      expect(provider.courses.single.id, course.id);
      expect(
        CourseProvider(storageService: storage).courses.single.id,
        course.id,
      );
      expect(reminderRefreshCount, 2);

      await provider.restoreCourse(removed);

      expect(provider.courses, hasLength(1));
      expect(reminderRefreshCount, 2);
    },
  );

  test(
    'event deletion returns record and restore is persistent and idempotent',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = StorageService(sharedPreferences: preferences);
      await storage.ensureSemesterMigration();
      final provider = CourseProvider(storageService: storage);
      var reminderRefreshCount = 0;
      provider.bindReminderScheduler(() async {
        reminderRefreshCount += 1;
      });
      final event = Event(
        id: 'restore-event',
        name: '班会',
        location: 'A101',
        dateTime: DateTime(2026, 6, 1, 19),
        enableAlarm: true,
      );
      await provider.addEvent(event);
      reminderRefreshCount = 0;

      final removed = await provider.deleteEvent(event.id);

      expect(removed?.id, event.id);
      expect(provider.events, isEmpty);
      expect(CourseProvider(storageService: storage).events, isEmpty);
      expect(reminderRefreshCount, 1);

      await provider.restoreEvent(removed!);

      expect(provider.events.single.id, event.id);
      expect(
        CourseProvider(storageService: storage).events.single.id,
        event.id,
      );
      expect(reminderRefreshCount, 2);

      await provider.restoreEvent(removed);

      expect(provider.events, hasLength(1));
      expect(reminderRefreshCount, 2);
    },
  );

  test('exam import records one timestamp for the whole batch', () async {
    final provider = await _createProvider();
    final manual = Event(
      id: 'manual',
      name: '班会',
      location: 'A101',
      dateTime: DateTime(2026, 6, 1, 19),
      enableAlarm: true,
    );
    await provider.addEvent(manual);

    await provider.mergeImportedEvents([
      Event(
        id: 'exam-one',
        name: '高等数学',
        location: 'A102',
        dateTime: DateTime(2026, 6, 8, 9),
        enableAlarm: true,
      ),
      Event(
        id: 'exam-two',
        name: '大学英语',
        location: 'A103',
        dateTime: DateTime(2026, 6, 9, 9),
        enableAlarm: true,
      ),
    ]);

    final importedTimes = provider.events
        .where(
          (event) =>
              event.importSource == CourseProvider.academicExamImportSource,
        )
        .map((event) => event.importedAt)
        .toSet();
    expect(importedTimes, hasLength(1));
    expect(importedTimes.single, isNotNull);
    expect(
      provider.events.singleWhere((event) => event.id == manual.id).importedAt,
      isNull,
    );
  });
}

Future<CourseProvider> _createProvider() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return CourseProvider(storageService: storage);
}

Course _course({
  required String id,
  required String name,
  String location = 'A101',
  String teacher = '教师',
  int weekday = DateTime.monday,
  List<int> weeks = const [1],
  int startPeriod = 1,
  int endPeriod = 2,
}) {
  return Course(
    id: id,
    name: name,
    location: location,
    teacher: teacher,
    weekday: weekday,
    weeks: weeks,
    startPeriod: startPeriod,
    endPeriod: endPeriod,
    colorValue: 0xFF2563EB,
  );
}
