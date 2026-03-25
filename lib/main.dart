import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'background_service.dart';
import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/timetable_view_provider.dart';
import 'screens/main_scaffold.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.create();
  await NotificationService.instance.initialize();

  runApp(MainApp(storageService: storageService));
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
  const MainApp({super.key, required this.storageService});

  final StorageService storageService;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final SettingsProvider _settingsProvider;
  late final CourseProvider _courseProvider;
  late final TimetableViewProvider _timetableViewProvider;

  @override
  void initState() {
    super.initState();

    _settingsProvider = SettingsProvider(storageService: widget.storageService);
    _courseProvider = CourseProvider(storageService: widget.storageService);
    _timetableViewProvider = TimetableViewProvider();

    Future<void> refreshReminders() {
      final courses = _courseProvider.courses.toList();
      final events = _courseProvider.events.toList();

      print(
        '[Main] refreshReminders start: '
        'courseReminderAdvanceMinutes=${_settingsProvider.reminderAdvanceMinutes}, '
        'eventReminderAdvanceMinutes=${_settingsProvider.eventReminderAdvanceMinutes}, '
        'courses=${courses.length}, events=${events.length}, '
        'autoMuteEnabled=${_settingsProvider.autoMuteEnabled}',
      );

      return Future.wait([
        NotificationService.instance.refreshAllReminders(
          courses: courses,
          events: events,
          settings: _settingsProvider,
        ),
        if (_settingsProvider.autoMuteEnabled)
          requestBackgroundServiceSync()
        else
          stopBackgroundServiceIfRunning(),
      ]).then((_) {});
    }

    _settingsProvider.bindReminderScheduler(refreshReminders);
    _courseProvider.bindReminderScheduler(refreshReminders);

    _timetableViewProvider.initializeRealDate(
      week: _settingsProvider.currentRealWeek,
      weekday: _settingsProvider.currentRealWeekday,
    );
    unawaited(refreshReminders());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<CourseProvider>.value(value: _courseProvider),
        ChangeNotifierProvider<TimetableViewProvider>.value(
          value: _timetableViewProvider,
        ),
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
