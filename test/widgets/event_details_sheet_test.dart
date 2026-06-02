import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/models/event.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/timetable/timetable_detail_sheets.dart';

void main() {
  testWidgets('event deletion snackbar can restore event', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = StorageService(sharedPreferences: preferences);
    await storage.ensureSemesterMigration();
    final settings = SettingsProvider(storageService: storage);
    final courses = CourseProvider(storageService: storage);
    final event = Event(
      id: 'event-to-restore',
      name: '班会',
      location: 'A101',
      dateTime: DateTime(2026, 6, 1, 19),
      enableAlarm: true,
    );
    await courses.addEvent(event);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<CourseProvider>.value(value: courses),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showEventDetailsSheet(context, event),
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
    await tester.tap(find.text('删除日程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除日程').last);
    await tester.pumpAndSettle();

    expect(courses.events, isEmpty);
    expect(find.text('已删除日程'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(courses.events.single.id, event.id);
  });
}
