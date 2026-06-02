import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/providers/timetable_view_provider.dart';
import 'package:timetable/screens/main_scaffold.dart';
import 'package:timetable/services/corrupt_row_diagnostic_store.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  testWidgets('shows newly isolated corrupt row count once on startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      CorruptRowDiagnosticStore.pendingCountKey: 2,
    });
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final timetableView = TimetableViewProvider()
      ..initializeRealDate(
        week: settings.currentRealWeek,
        weekday: settings.currentRealWeekday,
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CourseProvider>(
            create: (_) => CourseProvider(storageService: storage),
          ),
          ChangeNotifierProvider<TimetableViewProvider>.value(
            value: timetableView,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const MainScaffold()),
      ),
    );
    await tester.pump();

    expect(find.text('已跳过并保留 2 条损坏日程记录'), findsOneWidget);
    expect(await storage.consumePendingCorruptRowNoticeCount(), 0);
  });
}
