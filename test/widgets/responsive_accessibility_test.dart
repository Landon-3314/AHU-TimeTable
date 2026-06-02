import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/core/app_theme.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/theme_settings_page.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/common/app_wheel_pickers.dart';

void main() {
  testWidgets('theme color options expose numbered Chinese semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = await _createSettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ThemeSettingsPage(),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    final firstColor = find.byKey(const ValueKey('theme-primary-color-0'));
    expect(find.bySemanticsLabel('颜色 1，蓝色'), findsWidgets);
    expect(tester.getSemantics(firstColor).label, contains('颜色 1，蓝色'));
    expect(
      tester.getSemantics(firstColor).flagsCollection.isSelected.toBoolOrNull(),
      isTrue,
    );

    semantics.dispose();
  });

  testWidgets('clock picker stays usable at 200 percent text scale', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return TextButton(
                  onPressed: () {
                    showAppClockTimePicker(
                      hostContext,
                      initialTime: const TimeOfDay(hour: 8, minute: 0),
                    );
                  },
                  child: const Text('打开时间选择器'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开时间选择器'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });
}

Future<SettingsProvider> _createSettingsProvider() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return SettingsProvider(storageService: storage);
}
