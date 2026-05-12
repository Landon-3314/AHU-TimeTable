import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/add_course_page.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/common/capsule_multi_select.dart';

void main() {
  testWidgets('weekday and teaching weeks use capsule multi-select widgets', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    expect(find.byType(CapsuleMultiSelect<int>), findsNWidgets(2));
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('saving a new course creates one record per selected weekday', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    await tester.enterText(find.byType(TextFormField).at(0), 'Math');
    await tester.enterText(find.byType(TextFormField).at(1), 'Room 101');
    await tester.enterText(find.byType(TextFormField).at(2), 'Dr. Chen');
    await tester.tap(find.text('周三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(bundle.courses.courses, hasLength(2));
    expect(bundle.courses.courses.map((course) => course.weekday), [1, 3]);
    expect(bundle.courses.courses.map((course) => course.name).toSet(), {
      'Math',
    });
    expect(bundle.courses.courses.map((course) => course.location).toSet(), {
      'Room 101',
    });
    expect(bundle.courses.courses.map((course) => course.teacher).toSet(), {
      'Dr. Chen',
    });
  });

  testWidgets('saving without selected weekdays shows validation message', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    await tester.enterText(find.byType(TextFormField).at(0), 'Math');
    await tester.enterText(find.byType(TextFormField).at(1), 'Room 101');
    await tester.tap(find.text('周一'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('请至少选择一个星期几'), findsOneWidget);
    expect(bundle.courses.courses, isEmpty);
  });

  testWidgets('editing a course keeps weekday selection single-record', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    await bundle.courses.addCourse(
      Course(
        id: 'course-edit-target',
        name: 'Math',
        location: 'Room 101',
        teacher: 'Dr. Chen',
        weekday: 1,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      ),
    );
    final existingCourse = bundle.courses.courses.single;

    await tester.pumpWidget(_buildPage(bundle, existingCourse: existingCourse));

    await tester.tap(find.text('周三'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();

    expect(bundle.courses.courses, hasLength(1));
    expect(bundle.courses.courses.single.id, existingCourse.id);
    expect(bundle.courses.courses.single.weekday, 3);
  });

  testWidgets('saving a course keeps selected weeks sorted', (tester) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    await tester.enterText(find.byType(TextFormField).at(0), 'Math');
    await tester.enterText(find.byType(TextFormField).at(1), 'Room 101');
    await tester.tap(find.text('第 3 周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 2 周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(bundle.courses.courses, hasLength(1));
    expect(bundle.courses.courses.single.weeks, [1, 2, 3]);
  });

  testWidgets('saving without teaching weeks shows validation message', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    await tester.enterText(find.byType(TextFormField).at(0), 'Math');
    await tester.enterText(find.byType(TextFormField).at(1), 'Room 101');
    await tester.tap(find.text('第 1 周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('请至少选择一个上课周次'), findsOneWidget);
    expect(bundle.courses.courses, isEmpty);
  });

  testWidgets('keeps selected teaching weeks after switching tabs', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    await tester.tap(find.text('第 3 周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加日程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加课程'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Math');
    await tester.enterText(find.byType(TextFormField).at(1), 'Room 101');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(bundle.courses.courses, hasLength(1));
    expect(bundle.courses.courses.single.weeks, [1, 3]);
  });

  testWidgets('disables page scrolling while dragging teaching weeks', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    final listViewFinder = find.byType(ListView);
    expect(
      tester.widget<ListView>(listViewFinder).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );
    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('第 1 周')),
    );
    await tester.pump();

    expect(
      tester.widget<ListView>(listViewFinder).physics,
      isA<NeverScrollableScrollPhysics>(),
    );
    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)).physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.widget<ListView>(listViewFinder).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );
    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)).physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );
  });
}

Widget _buildPage(_ProviderBundle bundle, {Course? existingCourse}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: bundle.settings),
      ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
    ],
    child: MaterialApp(home: AddCoursePage(existingCourse: existingCourse)),
  );
}

Future<_ProviderBundle> _createProviderBundle() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return _ProviderBundle(
    settings: SettingsProvider(storageService: storage),
    courses: CourseProvider(storageService: storage),
  );
}

class _ProviderBundle {
  const _ProviderBundle({required this.settings, required this.courses});

  final SettingsProvider settings;
  final CourseProvider courses;
}
