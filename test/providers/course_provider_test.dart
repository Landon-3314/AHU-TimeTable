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
}
