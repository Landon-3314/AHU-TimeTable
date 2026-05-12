import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_routes.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/providers/timetable_view_provider.dart';
import 'package:timetable/screens/add_course_page.dart';
import 'package:timetable/screens/timetable_page.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/common/app_ui.dart';

void main() {
  testWidgets(
    'day and week view switcher does not show a selected check icon',
    (tester) async {
      final bundle = await _createProviderBundle();

      await tester.pumpWidget(_buildPage(bundle));

      await tester.tap(find.text('周视图'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.done), findsNothing);
    },
  );

  testWidgets(
    'overview groups courses by name and opens a single record edit',
    (tester) async {
      final bundle = await _createProviderBundle();
      await bundle.courses.addCourses([
        Course(
          name: 'Grouped Course',
          location: 'Room A',
          teacher: 'Dr. Chen',
          weekday: 1,
          weeks: const [1, 2],
          startPeriod: 1,
          endPeriod: 2,
          colorValue: 0xFF7C9AF2,
        ),
        Course(
          name: 'grouped course',
          location: 'Room B',
          teacher: 'Dr. Chen',
          weekday: 3,
          weeks: const [3, 4],
          startPeriod: 3,
          endPeriod: 4,
          colorValue: 0xFF7C9AF2,
        ),
      ]);

      await tester.pumpWidget(_buildPage(bundle));

      await tester.tap(find.text('总览'));
      await tester.pumpAndSettle();

      expect(find.text('Grouped Course'), findsOneWidget);
      expect(find.text('2个时段'), findsOneWidget);
      expect(find.byType(AppSurface), findsWidgets);
      expect(find.textContaining('Room A'), findsNothing);

      await tester.tap(find.text('Grouped Course'));
      await tester.pumpAndSettle();

      expect(find.text('周一 第1-2节 第1-2周 Room A'), findsOneWidget);
      expect(find.text('周三 第3-4节 第3-4周 Room B'), findsOneWidget);

      await tester.tap(find.text('周三 第3-4节 第3-4周 Room B'));
      await tester.pumpAndSettle();

      expect(find.byType(AddCoursePage), findsOneWidget);
      expect(find.text('保存修改'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AddCoursePage), findsNothing);
      expect(find.text('Grouped Course'), findsOneWidget);
      expect(find.text('2个时段'), findsOneWidget);
    },
  );
}

Widget _buildPage(_ProviderBundle bundle) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: bundle.settings),
      ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
      ChangeNotifierProvider<TimetableViewProvider>.value(
        value: bundle.timetableView,
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const TimetablePage(),
      onGenerateRoute: (settings) {
        if (settings.name != AppRoutes.addCourse) {
          return null;
        }
        final arguments = settings.arguments;
        final existingCourse = arguments is AddCourseRouteArgs
            ? arguments.existingCourse
            : null;
        return MaterialPageRoute<void>(
          builder: (_) => AddCoursePage(existingCourse: existingCourse),
          settings: settings,
        );
      },
    ),
  );
}

Future<_ProviderBundle> _createProviderBundle() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  final settings = SettingsProvider(storageService: storage);
  final timetableView = TimetableViewProvider()
    ..initializeRealDate(
      week: settings.currentRealWeek,
      weekday: settings.currentRealWeekday,
    );
  return _ProviderBundle(
    settings: settings,
    courses: CourseProvider(storageService: storage),
    timetableView: timetableView,
  );
}

class _ProviderBundle {
  const _ProviderBundle({
    required this.settings,
    required this.courses,
    required this.timetableView,
  });

  final SettingsProvider settings;
  final CourseProvider courses;
  final TimetableViewProvider timetableView;
}
