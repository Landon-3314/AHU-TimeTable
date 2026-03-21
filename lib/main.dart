import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_scaffold.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  await NotificationService.instance.initialize();

  runApp(
    MainApp(sharedPreferences: sharedPreferences),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class MainApp extends StatefulWidget {
  const MainApp({
    super.key,
    required this.sharedPreferences,
  });

  final SharedPreferences sharedPreferences;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final SettingsProvider _settingsProvider;
  late final CourseProvider _courseProvider;

  @override
  void initState() {
    super.initState();

    _settingsProvider = SettingsProvider(
      sharedPreferences: widget.sharedPreferences,
    );
    _courseProvider = CourseProvider(
      sharedPreferences: widget.sharedPreferences,
    );

    _courseProvider.initializeRealDate(
      week: _settingsProvider.currentRealWeek,
      weekday: _settingsProvider.currentRealWeekday,
    );

    Future<void> refreshReminders() {
      return NotificationService.instance.refreshAllReminders(
        courses: _courseProvider.courses.toList(),
        events: _courseProvider.events.toList(),
        settings: _settingsProvider,
      );
    }

    _settingsProvider.bindReminderScheduler(refreshReminders);
    _courseProvider.bindReminderScheduler(refreshReminders);

    unawaited(refreshReminders());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: _settingsProvider),
        ChangeNotifierProvider<CourseProvider>.value(value: _courseProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(settingsProvider.languageCode),
            scrollBehavior: const AppScrollBehavior(),
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF5F7FB),
              useMaterial3: true,
            ),
            home: const MainScaffold(),
          );
        },
      ),
    );
  }
}
