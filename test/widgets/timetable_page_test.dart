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
        Course(
          name: 'Grouped Course',
          location: 'Room C',
          teacher: 'Dr. Wang',
          weekday: 4,
          weeks: const [5],
          startPeriod: 5,
          endPeriod: 6,
          colorValue: 0xFF7C9AF2,
        ),
        Course(
          name: 'Grouped Course',
          location: 'Room D',
          teacher: 'Dr. Zhao',
          weekday: 5,
          weeks: const [6],
          startPeriod: 7,
          endPeriod: 8,
          colorValue: 0xFF7C9AF2,
        ),
      ]);

      await tester.pumpWidget(_buildPage(bundle));

      await tester.tap(find.text('总览'));
      await tester.pumpAndSettle();

      expect(find.text('Grouped Course'), findsOneWidget);
      expect(find.text('4个时段'), findsOneWidget);
      expect(find.byType(AppSurface), findsWidgets);
      expect(find.textContaining('Room A'), findsNothing);

      await tester.tap(find.text('Grouped Course'));
      await tester.pumpAndSettle();

      expect(find.text('周一 第1-2节 第1-2周 Room A'), findsNothing);
      expect(find.text('周三 第3-4节 第3-4周 Room B'), findsNothing);
      expect(find.text('周四 第5-6节 第5周 Room C'), findsNothing);
      expect(find.text('教师'), findsNWidgets(4));
      expect(find.text('地点'), findsNWidgets(4));
      expect(find.text('节次'), findsNWidgets(4));
      expect(find.text('时间'), findsNWidgets(4));
      expect(find.text('星期'), findsNWidgets(4));
      expect(find.text('周次'), findsNWidgets(4));
      expect(find.text('Dr. Chen'), findsNWidgets(2));
      expect(find.text('Room A'), findsOneWidget);
      expect(find.text('第 1-2 节'), findsOneWidget);
      expect(find.text('周一'), findsAtLeastNWidgets(1));
      expect(find.text('1, 2'), findsOneWidget);
      expect(find.text('Room D'), findsOneWidget);
      expect(find.text('查看更多'), findsNothing);
      expect(find.text('收起'), findsNothing);

      expect(
        tester.getTopLeft(find.text('Room A')).dy,
        lessThan(tester.getTopLeft(find.text('Room B')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Room B')).dy,
        lessThan(tester.getTopLeft(find.text('Room C')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Room C')).dy,
        lessThan(tester.getTopLeft(find.text('Room D')).dy),
      );

      await tester.tap(find.text('Room B'));
      await tester.pumpAndSettle();

      expect(find.byType(AddCoursePage), findsOneWidget);
      expect(find.text('保存修改'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AddCoursePage), findsNothing);
      expect(find.text('Grouped Course'), findsOneWidget);
      expect(find.text('4个时段'), findsOneWidget);
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
