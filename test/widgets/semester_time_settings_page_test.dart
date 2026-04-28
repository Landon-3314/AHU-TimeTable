import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/semester_time_settings_page.dart';
import 'package:timetable/services/storage_service.dart';

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

    await tester.tap(find.text('详细调整每节课起始时间'));
    await tester.pumpAndSettle();

    expect(find.text('每节课起始时间'), findsOneWidget);
    expect(find.text('上午'), findsOneWidget);
    expect(find.text('第 1 节'), findsOneWidget);
  });
}
