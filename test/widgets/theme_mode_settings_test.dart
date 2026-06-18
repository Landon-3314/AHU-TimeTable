import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:AnKe/core/app_theme.dart';
import 'package:AnKe/core/app_theme_tokens.dart';
import 'package:AnKe/providers/course_provider.dart';
import 'package:AnKe/providers/settings_provider.dart';
import 'package:AnKe/providers/timetable_view_provider.dart';
import 'package:AnKe/screens/settings_page.dart';
import 'package:AnKe/services/storage_service.dart';
import 'package:AnKe/widgets/timetable_app.dart';
import 'package:AnKe/widgets/common/app_ui.dart';

void main() {
  testWidgets('settings page changes the app display mode', (tester) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      _SettingsHost(
        settings: bundle.settings,
        courses: bundle.courses,
        child: const SettingsPage(),
      ),
    );

    expect(find.text('显示模式'), findsNothing);

    await tester.tap(find.text('主题颜色'));
    await tester.pumpAndSettle();

    expect(find.text('显示模式'), findsWidgets);

    await tester.tap(find.widgetWithText(AppActionTile, '显示模式'));
    await tester.pumpAndSettle();

    expect(find.text('跟随系统'), findsWidgets);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);

    await tester.drag(find.byType(ListWheelScrollView), const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(bundle.settings.appThemeMode, AppThemeMode.dark);
  });

  testWidgets('theme mode save failure shows settings save message', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    final settings = _ThrowingThemeSettingsProvider(
      storageService: bundle.storage,
      themeModeError: StateError('save failed'),
    );

    await tester.pumpWidget(
      _SettingsHost(
        settings: settings,
        courses: bundle.courses,
        child: const SettingsPage(),
      ),
    );

    await tester.tap(find.text('主题颜色'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppActionTile, '显示模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('保存失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('root app forwards the selected material theme mode', (
    tester,
  ) async {
    final bundle = await _createProviderBundle(
      initialValues: const {'settings.appThemeMode': 'dark'},
    );
    final timetableView = TimetableViewProvider()
      ..initializeRealDate(
        week: bundle.settings.currentRealWeek,
        weekday: bundle.settings.currentRealWeekday,
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(
            value: bundle.settings,
          ),
          ChangeNotifierProvider<CourseProvider>.value(value: bundle.courses),
          ChangeNotifierProvider<TimetableViewProvider>.value(
            value: timetableView,
          ),
        ],
        child: TimetableApp(settingsProvider: bundle.settings),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    expect(app.darkTheme, isNotNull);
    expect(app.supportedLocales, const [Locale('zh')]);
    expect(app.localizationsDelegates, isNotEmpty);
  });

  testWidgets('common surfaces use dark semantic tokens', (tester) async {
    final darkTheme = AppTheme.dark();
    final darkTokens = darkTheme.extension<AppThemeTokens>()!;

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              AppSurface(key: ValueKey('default-surface'), child: Text('普通表面')),
              Expanded(
                child: AppEmptyState(
                  icon: Icons.event_busy_outlined,
                  title: '暂无内容',
                  subtitle: '稍后再试',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final defaultMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const ValueKey('default-surface')),
            matching: find.byType(Material),
          )
          .first,
    );
    final emptyMaterial = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(AppEmptyState),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(defaultMaterial.color, darkTokens.surface);
    expect(emptyMaterial.color, darkTokens.surfaceRaised);
    expect(tester.takeException(), isNull);
  });
}

class _SettingsHost extends StatelessWidget {
  const _SettingsHost({
    required this.settings,
    required this.courses,
    required this.child,
  });

  final SettingsProvider settings;
  final CourseProvider courses;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<CourseProvider>.value(value: courses),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }
}

Future<_ProviderBundle> _createProviderBundle({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return _ProviderBundle(
    storage: storage,
    settings: SettingsProvider(storageService: storage),
    courses: CourseProvider(storageService: storage),
  );
}

class _ProviderBundle {
  const _ProviderBundle({
    required this.storage,
    required this.settings,
    required this.courses,
  });

  final StorageService storage;
  final SettingsProvider settings;
  final CourseProvider courses;
}

class _ThrowingThemeSettingsProvider extends SettingsProvider {
  _ThrowingThemeSettingsProvider({
    required super.storageService,
    required this.themeModeError,
  });

  final Object themeModeError;

  @override
  Future<void> changeAppThemeMode(AppThemeMode mode) async {
    throw themeModeError;
  }
}
