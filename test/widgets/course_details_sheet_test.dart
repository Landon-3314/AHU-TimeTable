import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_colors.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/timetable/timetable_detail_sheets.dart';

void main() {
  Future<({CourseProvider courses, SettingsProvider settings})>
  buildProviders() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    await storage.ensureSemesterMigration();

    final settings = SettingsProvider(storageService: storage);
    await settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23));
    final courses = CourseProvider(storageService: storage);
    final course = Course(
      name: 'Linear Algebra',
      location: 'Room 201',
      teacher: 'Dr. Chen',
      weekday: 1,
      weeks: const [1, 2],
      startPeriod: 1,
      endPeriod: 2,
      colorValue: AppColors.coursePaletteValues.first,
    );
    await courses.addCourse(course);
    return (courses: courses, settings: settings);
  }

  testWidgets('course deletion requires confirmation and cancel keeps course', (
    tester,
  ) async {
    final providers = await buildProviders();
    final course = providers.courses.courses.first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: providers.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(
            value: providers.courses,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showCourseDetailsSheet(context, course),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除课程'));
    await tester.pumpAndSettle();

    expect(find.text('删除这门课程？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(providers.courses.courses, hasLength(1));
    expect(find.text('Linear Algebra'), findsOneWidget);
  });

  testWidgets('course deletion snackbar can restore course', (tester) async {
    final providers = await buildProviders();
    final course = providers.courses.courses.first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: providers.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(
            value: providers.courses,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showCourseDetailsSheet(context, course),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除课程').last);
    await tester.pumpAndSettle();

    expect(providers.courses.courses, isEmpty);
    expect(find.text('已删除课程'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(providers.courses.courses.single.id, course.id);
  });
}
