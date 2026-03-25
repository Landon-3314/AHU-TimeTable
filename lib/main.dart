import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'background_service.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/timetable_view_provider.dart';
import 'services/app_services.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  final storageService = await AppServices.init();
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
      final hasCourseReminderRuntime =
          _settingsProvider.reminderAdvanceMinutes > 0 && courses.isNotEmpty;
      final hasEventReminderRuntime =
          _settingsProvider.eventReminderAdvanceMinutes > 0 &&
          events.any((event) => event.enableAlarm);
      final shouldKeepBackgroundRuntime =
          _settingsProvider.autoMuteEnabled ||
          hasCourseReminderRuntime ||
          hasEventReminderRuntime;

      return Future.wait([
        NotificationService.instance.refreshAllReminders(
          courses: courses,
          events: events,
          settings: _settingsProvider,
        ),
        if (shouldKeepBackgroundRuntime)
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
            theme: AppTheme.light(),
            initialRoute: AppRoutes.home,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
