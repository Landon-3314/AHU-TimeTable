import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/import_course_page.dart';
import 'package:timetable/services/academic_daily_auto_import_service.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/widgets/daily_academic_auto_import_host.dart';

void main() {
  testWidgets(
    'daily auto import host starts hidden timetable import when due',
    (tester) async {
      final settings = await _createSettingsProvider();
      final dailyService = _FakeDailyAutoImportService(shouldRun: true);
      final launchedActions = <AcademicAutoAction>[];

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: DailyAcademicAutoImportHost(
                dailyAutoImportService: dailyService,
                silentAutoImportBuilder: (context, action, onResult, onError) {
                  launchedActions.add(action);
                  return _SilentAutoImportProbe(onResult: onResult);
                },
                child: const Text('home'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('home'), findsOneWidget);
      expect(launchedActions, [AcademicAutoAction.timetable]);
      expect(dailyService.markCompletedCount, 1);
      expect(find.text('课表导入完成，已导入 3 门课程。'), findsNothing);
    },
  );

  testWidgets('daily auto import host does nothing when not due', (
    tester,
  ) async {
    final settings = await _createSettingsProvider();
    final dailyService = _FakeDailyAutoImportService(shouldRun: false);
    final launchedActions = <AcademicAutoAction>[];

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: DailyAcademicAutoImportHost(
              dailyAutoImportService: dailyService,
              silentAutoImportBuilder: (context, action, onResult, onError) {
                launchedActions.add(action);
                return _SilentAutoImportProbe(onResult: onResult);
              },
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(launchedActions, isEmpty);
    expect(dailyService.markCompletedCount, 0);
  });

  testWidgets('daily auto import host retries after a silent failure', (
    tester,
  ) async {
    final settings = await _createSettingsProvider();
    final dailyService = _FakeDailyAutoImportService(shouldRun: true);
    final launchedActions = <AcademicAutoAction>[];

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: DailyAcademicAutoImportHost(
              dailyAutoImportService: dailyService,
              retryDelays: const [Duration.zero],
              silentAutoImportBuilder: (context, action, onResult, onError) {
                launchedActions.add(action);
                if (launchedActions.length == 1) {
                  return _SilentAutoImportFailureProbe(onError: onError);
                }
                return _SilentAutoImportProbe(onResult: onResult);
              },
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump();

    expect(launchedActions, [
      AcademicAutoAction.timetable,
      AcademicAutoAction.timetable,
    ]);
    expect(dailyService.markCompletedCount, 1);
  });
}

Future<SettingsProvider> _createSettingsProvider() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  return _InitializedSettingsProvider(storageService: storage);
}

class _InitializedSettingsProvider extends SettingsProvider {
  _InitializedSettingsProvider({required super.storageService});

  @override
  bool get isCurrentSemesterInitialized => true;
}

class _FakeDailyAutoImportService implements AcademicDailyAutoImportService {
  _FakeDailyAutoImportService({required this.shouldRun});

  final bool shouldRun;
  int markCompletedCount = 0;

  @override
  Future<void> markDailyTimetableImportCompleted({DateTime? now}) async {
    markCompletedCount += 1;
  }

  @override
  Future<bool> shouldRunDailyTimetableImport({DateTime? now}) async {
    return shouldRun;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SilentAutoImportProbe extends StatefulWidget {
  const _SilentAutoImportProbe({required this.onResult});

  final ValueChanged<AcademicImportResult> onResult;

  @override
  State<_SilentAutoImportProbe> createState() => _SilentAutoImportProbeState();
}

class _SilentAutoImportProbeState extends State<_SilentAutoImportProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onResult(
        const AcademicImportResult(
          kind: AcademicImportKind.timetable,
          importedCount: 3,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Text('daily auto import probe');
  }
}

class _SilentAutoImportFailureProbe extends StatefulWidget {
  const _SilentAutoImportFailureProbe({required this.onError});

  final ValueChanged<String> onError;

  @override
  State<_SilentAutoImportFailureProbe> createState() =>
      _SilentAutoImportFailureProbeState();
}

class _SilentAutoImportFailureProbeState
    extends State<_SilentAutoImportFailureProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onError('failed');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Text('daily auto import failure probe');
  }
}
