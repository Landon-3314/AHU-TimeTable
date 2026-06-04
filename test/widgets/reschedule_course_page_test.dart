import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/reschedule_course_page.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  testWidgets('reschedule conflict asks before saving', (tester) async {
    final bundle = await _createProviderBundle();
    final existing = _course(id: 'existing', name: '大学英语');
    final moved = _course(id: 'moved', name: '线性代数');
    await bundle.courses.addCourse(existing);
    await bundle.courses.addCourse(moved, allowConflicts: true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: MaterialApp(
          home: RescheduleCoursePage(course: moved, sourceWeek: 1),
        ),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('发现课程时间冲突'), findsOneWidget);
    expect(find.textContaining('线性代数'), findsWidgets);
    expect(find.textContaining('大学英语'), findsWidgets);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      bundle.courses.courses.where((course) => course.id == moved.id),
      hasLength(1),
    );
  });
}

Future<_ProviderBundle> _createProviderBundle() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  final settings = SettingsProvider(storageService: storage);
  await settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23));
  return _ProviderBundle(
    settings: settings,
    courses: CourseProvider(storageService: storage),
  );
}

Course _course({required String id, required String name}) {
  return Course(
    id: id,
    name: name,
    location: 'A101',
    teacher: '教师',
    weekday: DateTime.monday,
    weeks: const [1],
    startPeriod: 1,
    endPeriod: 2,
    colorValue: 0xFF2563EB,
  );
}

class _ProviderBundle {
  const _ProviderBundle({required this.settings, required this.courses});

  final SettingsProvider settings;
  final CourseProvider courses;
}
