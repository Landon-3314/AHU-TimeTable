import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/timetable_view_provider.dart';
import 'services/app_services.dart';
import 'services/long_screenshot_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LongScreenshotService.instance.initialize();
  final initFuture = _initAppSafely();
  runApp(MainApp(initFuture: initFuture));
}

Future<_AppInitBundle?> _initAppSafely() async {
  try {
    final storageService = await AppServices.init();

    final settingsProvider = SettingsProvider(storageService: storageService);
    final courseProvider = CourseProvider(storageService: storageService);
    final timetableViewProvider = TimetableViewProvider();

    Future<void> refreshReminders() {
      final courses = courseProvider.courses.toList();
      final events = courseProvider.events.toList();

      return AppServices.refreshSchedules(
        courses: courses,
        events: events,
        settings: settingsProvider,
      );
    }

    settingsProvider.bindReminderScheduler(refreshReminders);
    courseProvider.bindReminderScheduler(refreshReminders);

    timetableViewProvider.initializeRealDate(
      week: settingsProvider.currentRealWeek,
      weekday: settingsProvider.currentRealWeekday,
    );

    await refreshReminders();

    return _AppInitBundle(
      settingsProvider: settingsProvider,
      courseProvider: courseProvider,
      timetableViewProvider: timetableViewProvider,
    );
  } catch (e) {
    debugPrint('[Main] 初始化异常: $e');
    return null;
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices =>
      Set<PointerDeviceKind>.from(PointerDeviceKind.values);
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.initFuture});

  final Future<_AppInitBundle?> initFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppInitBundle?>(
      future: initFuture,
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            bundle == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(
              value: bundle.settingsProvider,
            ),
            ChangeNotifierProvider<CourseProvider>.value(
              value: bundle.courseProvider,
            ),
            ChangeNotifierProvider<TimetableViewProvider>.value(
              value: bundle.timetableViewProvider,
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
      },
    );
  }
}

class _AppInitBundle {
  const _AppInitBundle({
    required this.settingsProvider,
    required this.courseProvider,
    required this.timetableViewProvider,
  });

  final SettingsProvider settingsProvider;
  final CourseProvider courseProvider;
  final TimetableViewProvider timetableViewProvider;
}
