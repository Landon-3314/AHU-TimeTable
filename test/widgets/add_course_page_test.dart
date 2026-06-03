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

    expect(find.byType(CapsuleMultiSelect<int>), findsOneWidget);
    await _scrollTeachingWeeksIntoView(tester);
    expect(
      find.byKey(const ValueKey('teaching-week-selector')),
      findsOneWidget,
    );
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
    await _scrollTeachingWeeksIntoView(tester);
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
    await _scrollTeachingWeeksIntoView(tester);
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

    await tester.enterText(find.byType(TextFormField).at(0), 'Math');
    await tester.enterText(find.byType(TextFormField).at(1), 'Room 101');
    await _scrollTeachingWeeksIntoView(tester);
    await tester.tap(find.text('第 3 周'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加日程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加课程/日程'));
    await tester.pumpAndSettle();

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
    await _scrollTeachingWeeksIntoView(tester);

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

  testWidgets('teaching week quick actions replace the current selection', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await _scrollTeachingWeeksIntoView(tester);

    Set<int> selectedTeachingWeeks() {
      return tester
          .widget<CapsuleMultiSelect<int>>(
            find.byKey(const ValueKey('teaching-week-selector')),
          )
          .selectedValues;
    }

    final allWeeks = {
      for (int week = 1; week <= bundle.settings.totalWeeks; week++) week,
    };

    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(selectedTeachingWeeks(), allWeeks);

    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(selectedTeachingWeeks(), isEmpty);

    await tester.tap(find.text('单周'));
    await tester.pump();
    expect(selectedTeachingWeeks(), allWeeks.where((week) => week.isOdd));

    await tester.tap(find.text('双周'));
    await tester.pump();
    expect(selectedTeachingWeeks(), allWeeks.where((week) => week.isEven));
  });

  testWidgets('course color options expose distinct semantics labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    final firstColor = find.byKey(const ValueKey('course-color-0'));
    expect(find.bySemanticsLabel('颜色 1，青绿'), findsOneWidget);
    expect(find.bySemanticsLabel('颜色 2，蓝色'), findsOneWidget);
    expect(tester.getSemantics(firstColor).label, contains('颜色 1，青绿'));
    expect(
      tester.getSemantics(firstColor).flagsCollection.isSelected.toBoolOrNull(),
      isTrue,
    );

    semantics.dispose();
  });

  testWidgets('course conflict asks before saving and supports cancellation', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    await bundle.courses.addCourse(
      Course(
        id: 'existing-course',
        name: '大学英语',
        location: 'A101',
        teacher: '王老师',
        weekday: DateTime.monday,
        weeks: const [1],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF2563EB,
      ),
    );

    await tester.pumpWidget(_buildPage(bundle));
    await tester.enterText(find.byType(TextFormField).at(0), '线性代数');
    await tester.enterText(find.byType(TextFormField).at(1), 'A102');
    await tester.enterText(find.byType(TextFormField).at(2), '李老师');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('发现课程时间冲突'), findsOneWidget);
    expect(find.textContaining('线性代数'), findsWidgets);
    expect(find.textContaining('大学英语'), findsWidgets);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(bundle.courses.courses, hasLength(1));

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍然保存'));
    await tester.pumpAndSettle();

    expect(bundle.courses.courses, hasLength(2));
    expect(
      bundle.courses.courses.map((course) => course.name),
      contains('线性代数'),
    );
  });
}

Future<void> _scrollTeachingWeeksIntoView(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -360));
  await tester.pumpAndSettle();
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
