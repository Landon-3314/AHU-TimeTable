import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/screens/import_course_page.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  testWidgets(
    'timetable import conflict confirms once and cancellation keeps old batch',
    (tester) async {
      final provider = await _createProvider();
      final manual = _course(id: 'manual', name: '手工课程');
      final oldImported = _course(
        id: 'old-imported',
        name: '旧教务课程',
        weekday: DateTime.tuesday,
      );
      final incoming = [
        _course(id: 'incoming-one', name: '高等数学'),
        _course(id: 'incoming-two', name: '大学英语'),
      ];
      await provider.addCourse(manual);
      await provider.mergeImportedCourses([oldImported]);

      await tester.pumpWidget(
        MaterialApp(
          home: _ImportHarness(provider: provider, incoming: incoming),
        ),
      );

      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(find.text('发现课程时间冲突'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        provider.courses.map((course) => course.id),
        contains('old-imported'),
      );
      expect(
        provider.courses.map((course) => course.id),
        isNot(contains('incoming-one')),
      );

      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(find.text('发现课程时间冲突'), findsOneWidget);
      await tester.tap(find.text('仍然保存'));
      await tester.pumpAndSettle();

      expect(
        provider.courses.map((course) => course.id),
        isNot(contains('old-imported')),
      );
      expect(
        provider.courses.map((course) => course.id),
        contains('incoming-one'),
      );
      expect(
        provider.courses.map((course) => course.id),
        contains('incoming-two'),
      );
    },
  );
}

class _ImportHarness extends StatelessWidget {
  const _ImportHarness({required this.provider, required this.incoming});

  final CourseProvider provider;
  final List<Course> incoming;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => importTimetableCoursesWithConflictConfirmation(
            context: context,
            courseProvider: provider,
            courses: incoming,
          ),
          child: const Text('导入'),
        ),
      ),
    );
  }
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
  int weekday = DateTime.monday,
}) {
  return Course(
    id: id,
    name: name,
    location: 'A101',
    teacher: '教师',
    weekday: weekday,
    weeks: const [1],
    startPeriod: 1,
    endPeriod: 2,
    colorValue: 0xFF2563EB,
  );
}
