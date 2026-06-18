import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'providers/course_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/timetable_view_provider.dart';
import 'services/app_services.dart';
import 'services/long_screenshot_service.dart';
import 'widgets/timetable_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LongScreenshotService.instance.initialize();
  final initFuture = _initAppSafely();
  runApp(_MainApp(initFuture: initFuture));
}

Future<_AppInitBundle> _initAppSafely() async {
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
    settingsProvider.bindSemesterChangeHandler(() async {
      await courseProvider.reloadForCurrentSemester(refreshReminders: false);
      timetableViewProvider.setCurrentWeekAndWeekday(
        week: settingsProvider.currentRealWeek,
        weekday: settingsProvider.currentRealWeekday,
      );
      await refreshReminders();
    });

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
    rethrow;
  }
}

class _MainApp extends StatefulWidget {
  const _MainApp({required this.initFuture});

  final Future<_AppInitBundle> initFuture;

  @override
  State<_MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<_MainApp> {
  late Future<_AppInitBundle> _initFuture;
  _AppInitBundle? _activeBundle;

  @override
  void initState() {
    super.initState();
    _initFuture = widget.initFuture;
  }

  void _retryInitialization() {
    _disposeActiveBundle();
    setState(() {
      _initFuture = _initAppSafely();
    });
  }

  void _disposeActiveBundle() {
    _activeBundle?.dispose();
    _activeBundle = null;
  }

  @override
  void dispose() {
    _disposeActiveBundle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppInitBundle>(
      future: _initFuture,
      builder: (context, snapshot) {
        final bundle = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            supportedLocales: const [Locale('zh')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || bundle == null) {
          if (_activeBundle != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _disposeActiveBundle();
              }
            });
          }
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            supportedLocales: const [Locale('zh')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: _AppInitErrorPage(
              error: snapshot.error,
              onRetry: _retryInitialization,
            ),
          );
        }

        if (!identical(_activeBundle, bundle)) {
          final previousBundle = _activeBundle;
          _activeBundle = bundle;
          if (previousBundle != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              previousBundle.dispose();
            });
          }
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
              return TimetableApp(settingsProvider: settingsProvider);
            },
          ),
        );
      },
    );
  }
}

class _AppInitErrorPage extends StatelessWidget {
  const _AppInitErrorPage({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final errorMessage = error?.toString() ?? '未知初始化错误';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '应用初始化失败',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  void dispose() {
    settingsProvider.dispose();
    courseProvider.dispose();
    timetableViewProvider.dispose();
  }
}
