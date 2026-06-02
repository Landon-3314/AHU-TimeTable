import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_routes.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/models/event.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/exam_overview_page.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  testWidgets('exam overview only shows academic exams and countdown labels', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    final now = DateTime.now();
    await bundle.courses.addEvent(
      Event(
        id: 'manual',
        name: '手工会议',
        location: '会议室',
        dateTime: now,
        enableAlarm: false,
      ),
    );
    await bundle.courses.addEvent(
      _academicExam(
        id: 'past',
        name: '历史考试',
        dateTime: now.subtract(const Duration(days: 1)),
      ),
    );
    await bundle.courses.addEvent(
      _academicExam(id: 'today', name: '今日考试', dateTime: now),
    );
    await bundle.courses.addEvent(
      _academicExam(
        id: 'future',
        name: '未来考试',
        dateTime: now.add(const Duration(days: 2)),
        importedAt: DateTime(2026, 6, 1, 10, 30),
      ),
    );

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();

    expect(find.text('教务考试'), findsOneWidget);
    expect(find.text('手工会议'), findsNothing);
    expect(find.text('历史考试'), findsOneWidget);
    expect(find.text('今日考试'), findsOneWidget);
    expect(find.text('未来考试'), findsOneWidget);
    expect(find.text('教务系统'), findsNWidgets(3));
    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('还有 2 天'), findsOneWidget);
    expect(find.textContaining('最近导入：未知'), findsNWidgets(2));
    expect(find.textContaining('最近导入：2026/06/01 10:30'), findsOneWidget);
  });

  testWidgets('empty exam overview opens academic import', (tester) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(_buildPage(bundle));
    await tester.pumpAndSettle();

    expect(find.text('暂无教务考试'), findsOneWidget);
    expect(find.text('导入考试'), findsOneWidget);

    await tester.tap(find.text('导入考试'));
    await tester.pumpAndSettle();

    expect(find.text('导入目标'), findsOneWidget);
  });
}

Widget _buildPage(_ProviderBundle bundle) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: bundle.settings),
      ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      routes: {
        AppRoutes.importCourses: (_) =>
            const Scaffold(body: Center(child: Text('导入目标'))),
      },
      home: const ExamOverviewPage(),
    ),
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

Event _academicExam({
  required String id,
  required String name,
  required DateTime dateTime,
  DateTime? importedAt,
}) {
  return Event(
    id: id,
    name: name,
    location: 'A101',
    note: '座位号 1',
    dateTime: dateTime,
    enableAlarm: true,
    importSource: CourseProvider.academicExamImportSource,
    importedAt: importedAt,
  );
}

class _ProviderBundle {
  const _ProviderBundle({required this.settings, required this.courses});

  final SettingsProvider settings;
  final CourseProvider courses;
}
