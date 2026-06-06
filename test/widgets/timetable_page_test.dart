import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_constants.dart';
import 'package:timetable/core/app_routes.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/models/event.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/providers/timetable_view_provider.dart';
import 'package:timetable/screens/academic_account_page.dart';
import 'package:timetable/screens/add_course_page.dart';
import 'package:timetable/screens/exam_overview_page.dart';
import 'package:timetable/screens/timetable_page.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/services/timetable_navigation_controller.dart';
import 'package:timetable/widgets/common/app_ui.dart';
import 'package:timetable/widgets/timetable/course_overview_panel.dart';
import 'package:timetable/widgets/timetable/timetable_detail_sheets.dart';

void main() {
  testWidgets('today button target switches navigation back to day mode', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    final controller = TimetableNavigationController(
      settingsProvider: bundle.settings,
      timetableViewProvider: bundle.timetableView,
      holidayWeekIndex: AppConstants.holidayWeekIndex,
    );
    addTearDown(controller.dispose);

    controller.setMode(TimetableMode.week);
    expect(controller.state.mode, TimetableMode.week);

    await controller.jumpToToday();

    expect(controller.state.mode, TimetableMode.day);
    expect(controller.state.currentWeek, bundle.settings.currentRealWeek);
    expect(controller.state.currentWeekday, bundle.settings.currentRealWeekday);
  });

  testWidgets('day and week view switcher uses one text-only pill indicator', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    final switcher = find.byKey(const ValueKey('timetable-mode-switcher'));
    expect(switcher, findsOneWidget);
    expect(find.byType(SegmentedButton<dynamic>), findsNothing);
    expect(
      find.descendant(
        of: switcher,
        matching: find.byKey(
          const ValueKey('timetable-mode-switcher-indicator'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: switcher,
        matching: find.byIcon(Icons.view_day_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: switcher,
        matching: find.byIcon(Icons.calendar_view_week_outlined),
      ),
      findsNothing,
    );

    await tester.tap(find.text('周视图'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done), findsNothing);
  });

  testWidgets(
    'today button from holiday week opens the real current week day',
    (tester) async {
      final bundle = await _createProviderBundle(totalWeeks: 2);
      final todayWeek = bundle.settings.currentRealWeek;
      final todayWeekday = bundle.settings.currentRealWeekday;
      expect(todayWeek, greaterThan(1));
      await bundle.courses.addCourses([
        Course(
          name: 'Wrong first-week course',
          location: 'Room 101',
          teacher: 'Dr. Old',
          weekday: todayWeekday,
          weeks: const [1],
          startPeriod: 1,
          endPeriod: 2,
          colorValue: 0xFF7C9AF2,
        ),
        Course(
          name: 'Correct today course',
          location: 'Room 202',
          teacher: 'Dr. Today',
          weekday: todayWeekday,
          weeks: [todayWeek],
          startPeriod: 3,
          endPeriod: 4,
          colorValue: 0xFF7C9AF2,
        ),
      ]);

      await tester.pumpWidget(_buildPage(bundle));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppPickerPill));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 1 周'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong first-week course'), findsOneWidget);
      expect(find.text('Correct today course'), findsNothing);

      await tester.tap(find.text('周视图'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppPickerPill));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('假期中'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('假期中'));
      await tester.pumpAndSettle();

      expect(find.text('假期中'), findsWidgets);

      await tester.tap(find.byTooltip('回到今日'));
      await tester.pump();

      expect(find.text('Correct today course'), findsOneWidget);
      expect(find.text('Wrong first-week course'), findsNothing);
    },
  );

  testWidgets('toolbar guide appears before semester initialization', (
    tester,
  ) async {
    final bundle = await _createProviderBundle(
      initialized: false,
      confirmGuides: false,
    );

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();

    expect(bundle.settings.shouldShowSemesterStartDatePrompt, isTrue);
    expect(find.text('切换周次'), findsOneWidget);
  });

  testWidgets('narrow toolbar guide only covers visible actions', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));
    final bundle = await _createProviderBundle(confirmGuides: false);

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();

    expect(find.text('切换周次'), findsOneWidget);
    expect(find.text('第 1/2 步'), findsOneWidget);
    expect(find.text('第 1/4 步'), findsNothing);

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.text('回到今天'), findsOneWidget);
    expect(find.text('第 2/2 步'), findsOneWidget);
  });

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

      final overviewCourse = find.descendant(
        of: find.byType(CourseOverviewPanel),
        matching: find.text('Grouped Course'),
      );
      expect(overviewCourse, findsOneWidget);
      expect(find.text('4个时段'), findsOneWidget);
      expect(find.byType(AppSurface), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(CourseOverviewPanel),
          matching: find.textContaining('Room A'),
        ),
        findsNothing,
      );

      await tester.tap(overviewCourse);
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
      expect(
        find.descendant(
          of: find.byType(DetailRow),
          matching: find.text('第 1-2 节'),
        ),
        findsOneWidget,
      );
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
      expect(
        find.descendant(
          of: find.byType(CourseOverviewPanel),
          matching: find.text('Grouped Course'),
        ),
        findsOneWidget,
      );
      expect(find.text('4个时段'), findsOneWidget);
    },
  );

  testWidgets('empty timetable import action opens academic account page', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    expect(find.widgetWithText(FilledButton, '添加课程/日程'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '导入教务课表'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '添加课程/日程'));
    await tester.pumpAndSettle();

    expect(find.byType(AddCoursePage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '导入教务课表'));
    await tester.pumpAndSettle();

    expect(find.byType(AcademicAccountPage), findsOneWidget);
  });

  testWidgets('empty day after timetable import exposes only add action', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    final otherWeekday = bundle.settings.currentRealWeekday == 1 ? 2 : 1;
    await bundle.courses.mergeImportedCourses([
      Course(
        name: 'Imported Course',
        location: 'Room A',
        teacher: 'Dr. Chen',
        weekday: otherWeekday,
        weeks: [bundle.settings.currentRealWeek],
        startPeriod: 1,
        endPeriod: 2,
        colorValue: 0xFF7C9AF2,
      ),
    ]);

    await tester.pumpWidget(_buildPage(bundle));

    expect(find.widgetWithText(FilledButton, '添加课程/日程'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '导入教务课表'), findsNothing);
  });

  testWidgets('empty week view exposes add and import actions', (tester) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.tap(find.text('周视图'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '添加课程/日程'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '导入教务课表'), findsOneWidget);
  });

  testWidgets('empty overview exposes add and import actions', (tester) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();

    final overviewPanel = find.byType(CourseOverviewPanel);
    expect(
      find.descendant(
        of: overviewPanel,
        matching: find.widgetWithText(FilledButton, '添加课程/日程'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: overviewPanel,
        matching: find.widgetWithText(OutlinedButton, '导入教务课表'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('toolbar no longer exposes standalone exam action', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    expect(find.byTooltip('教务考试'), findsNothing);
  });

  testWidgets('toolbar no longer exposes academic import action', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));

    expect(find.byTooltip('导入教务课表'), findsNothing);
  });

  testWidgets('narrow toolbar uses themed anchored action menu', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    final menuCard = find.byKey(const ValueKey('narrow-toolbar-menu-card'));
    expect(menuCard, findsOneWidget);
    expect(tester.getSize(menuCard).width, lessThan(208));
    expect(tester.getSize(menuCard).width, greaterThan(150));
    final menuShadow = find.byKey(const ValueKey('narrow-toolbar-menu-shadow'));
    expect(menuShadow, findsOneWidget);
    final shadowDecoration =
        tester.widget<DecoratedBox>(menuShadow).decoration as BoxDecoration;
    expect(shadowDecoration.borderRadius, BorderRadius.circular(AppRadii.xxl));
    expect(shadowDecoration.boxShadow, isNotEmpty);
    expect(tester.widget<Material>(menuCard).elevation, 0);
    expect(
      find.byKey(const ValueKey('narrow-toolbar-menu-action-overview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('narrow-toolbar-menu-action-exams')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('narrow-toolbar-menu-action-academic-import')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('narrow-toolbar-menu-action-add-course')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: menuCard,
        matching: find.byIcon(Icons.dashboard_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('教务考试'), findsNothing);
    expect(find.byIcon(Icons.assignment_outlined), findsNothing);
    expect(
      find.descendant(of: menuCard, matching: find.text('导入教务课表')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: menuCard,
        matching: find.byIcon(Icons.cloud_download_outlined),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: menuCard, matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
  });

  testWidgets('narrow toolbar menu reveals container before content', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final containerOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('narrow-toolbar-menu-container-opacity')),
    );
    final contentOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('narrow-toolbar-menu-content-opacity')),
    );
    expect(containerOpacity.opacity, greaterThan(0));
    expect(contentOpacity.opacity, 0);

    await tester.pumpAndSettle();

    final settledContentOpacity = tester.widget<Opacity>(
      find.byKey(const ValueKey('narrow-toolbar-menu-content-opacity')),
    );
    expect(settledContentOpacity.opacity, 1);
  });

  testWidgets('narrow toolbar menu closes when tapping outside', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('narrow-toolbar-menu-card')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(12, 700));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('narrow-toolbar-menu-card')),
      findsNothing,
    );
  });

  testWidgets('overview sheet switches from course to exam page by swipe', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final bundle = await _createProviderBundle();
    await bundle.courses.addEvent(
      Event(
        id: 'academic-exam',
        name: '线性代数考试',
        location: 'A101',
        note: '座位号 1',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        enableAlarm: true,
        importSource: CourseProvider.academicExamImportSource,
      ),
    );

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();

    final coursesTab = find.byKey(const ValueKey('overview-tab-courses'));
    final examsTab = find.byKey(const ValueKey('overview-tab-exams'));
    expect(coursesTab, findsOneWidget);
    expect(examsTab, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-tabs')),
        matching: find.byKey(const ValueKey('overview-tabs-indicator')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(coursesTab).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(examsTab).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    await tester.fling(
      find.byKey(const ValueKey('overview-pages')),
      const Offset(-600, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(coursesTab).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    expect(
      tester.getSemantics(examsTab).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('线性代数考试'), findsOneWidget);
    semantics.dispose();
  });
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
        if (settings.name == AppRoutes.exams) {
          return MaterialPageRoute<void>(
            builder: (_) => const ExamOverviewPage(),
            settings: settings,
          );
        }
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

Future<_ProviderBundle> _createProviderBundle({
  bool initialized = true,
  bool confirmGuides = true,
  int? totalWeeks,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  final settings = SettingsProvider(storageService: storage);
  if (initialized) {
    await settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23));
  }
  if (totalWeeks != null) {
    await settings.updateTotalWeeks(totalWeeks);
  }
  if (confirmGuides) {
    await settings.confirmTimetableToolbarGuide();
    await settings.confirmTimetableMenuGuide();
  }
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
