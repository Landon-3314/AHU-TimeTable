import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/add_course_page.dart';
import 'package:timetable/screens/reminder_settings_page.dart';
import 'package:timetable/screens/semester_time_settings_page.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/common/app_ui.dart';
import 'package:timetable/widgets/common/app_wheel_pickers.dart';

void main() {
  testWidgets('opens detailed period start time settings page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final courses = CourseProvider(storageService: storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CourseProvider>.value(value: courses),
        ],
        child: const MaterialApp(home: SemesterTimeSettingsPage()),
      ),
    );

    await _tapVisible(tester, find.text('详细调整每节课起始时间'));

    expect(find.text('每节课起始时间'), findsOneWidget);
    expect(find.text('上午'), findsOneWidget);
    expect(find.text('第 1 节'), findsOneWidget);
  });

  testWidgets('period start time uses wheel time picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: SemesterTimeSettingsPage()),
      ),
    );

    await _tapVisible(tester, find.text('详细调整每节课起始时间'));
    await tester.tap(find.text('第 1 节'));
    await tester.pumpAndSettle();

    expect(find.text('上午'), findsWidgets);
    expect(find.text('下午'), findsWidgets);
    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
  });

  testWidgets('tapping a visible wheel value jumps to that value', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: SemesterTimeSettingsPage()),
      ),
    );

    await _tapVisible(tester, find.text('详细调整每节课起始时间'));
    await tester.tap(find.text('第 1 节'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.textContaining('09:00'), findsOneWidget);
  });

  testWidgets('calendar weeks and session counts use wheel pickers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: SemesterTimeSettingsPage()),
      ),
    );

    await tester.tap(find.byType(AppPickerPill).first);
    await tester.pumpAndSettle();

    expect(
      find.byType(AppWheelPicker<AppWheelPickerOption<int>>),
      findsOneWidget,
    );
    expect(find.byType(GridView), findsNothing);
    expect(find.text('确定'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('上午几节课'));

    expect(
      find.byType(AppWheelPicker<AppWheelPickerOption<int>>),
      findsOneWidget,
    );
    expect(find.byType(GridView), findsNothing);
    expect(find.text('确定'), findsOneWidget);
  });

  testWidgets('big break settings use bottom sheet capsule selector', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: SemesterTimeSettingsPage()),
      ),
    );

    await tester.tap(find.text('大课间'));
    await tester.pumpAndSettle();

    expect(find.text('大课间设置'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('big-break-position-selector')),
      findsOneWidget,
    );
    expect(find.text('第2节后'), findsOneWidget);
    expect(find.text('第7节后'), findsOneWidget);

    await tester.tap(find.text('第7节后'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(bundle.settings.bigBreakAfterPeriods, [2]);
  });

  testWidgets('event time uses wheel time picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: AddCoursePage()),
      ),
    );

    await tester.tap(find.text('添加日程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请选择时间'));
    await tester.pumpAndSettle();

    expect(find.text('上午'), findsOneWidget);
    expect(find.text('下午'), findsOneWidget);
    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
  });

  testWidgets('course reminder advance uses hour and minute wheels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle(
      courseReminderMinutes: 10,
      eventReminderMinutes: 10,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: ReminderSettingsPage()),
      ),
    );

    await tester.tap(find.text('提前提醒时间'));
    await tester.pumpAndSettle();

    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
    expect(find.text('天'), findsNothing);
  });

  testWidgets('event reminder advance uses day hour and minute wheels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle(
      courseReminderMinutes: 10,
      eventReminderMinutes: 10,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: ReminderSettingsPage()),
      ),
    );

    await tester.tap(find.text('日程提前提醒时间'));
    await tester.pumpAndSettle();

    expect(find.text('天'), findsOneWidget);
    expect(find.text('时'), findsOneWidget);
    expect(find.text('分'), findsOneWidget);
  });

  testWidgets('course period single choice uses grid picker', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
        ],
        child: const MaterialApp(home: AddCoursePage()),
      ),
    );

    await tester.tap(find.text('第 1 节'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('确定'), findsNothing);

    await tester.tap(find.text('第 3 节'));
    await tester.pumpAndSettle();

    expect(find.text('第 3 节'), findsNWidgets(2));
  });

  testWidgets(
    'course reminder style uses wheel picker with selected subtitle',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bundle = await _createProviderBundle(courseReminderMinutes: 10);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(
              value: bundle.settings,
            ),
            ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
          ],
          child: const MaterialApp(home: ReminderSettingsPage()),
        ),
      );

      await tester.tap(find.text('提醒样式'));
      await tester.pumpAndSettle();

      expect(find.text('确定'), findsOneWidget);
      expect(find.text('按提前时间发送一次系统通知'), findsOneWidget);
    },
  );

  test('wheel scroll physics limits fling velocity', () {
    const physics = AppWheelScrollPhysics();

    expect(physics.maxFlingVelocity, 1800);
    expect(physics.carriedMomentum(5000), lessThanOrEqualTo(360));
  });
}

Future<_ProviderBundle> _createProviderBundle({
  int courseReminderMinutes = 0,
  int eventReminderMinutes = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  await storage.writeReminderAdvanceMinutes(courseReminderMinutes);
  await storage.writeEventReminderAdvanceMinutes(eventReminderMinutes);
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

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
