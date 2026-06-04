import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/academic_credential.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/academic_account_page.dart';
import 'package:timetable/screens/import_course_page.dart';
import 'package:timetable/services/academic_credential_service.dart';
import 'package:timetable/services/storage_service.dart';

void main() {
  testWidgets(
    'academic account page saves credentials and exposes import actions',
    (tester) async {
      final settings = await _createSettingsProvider();
      final store = _MemoryCredentialStore();
      final launchedActions = <AcademicAutoAction?>[];

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: AcademicAccountPage(
              credentialService: AcademicCredentialService(store: store),
              autoImportLauncher: (context, action) async {
                launchedActions.add(action);
                return null;
              },
              manualImportLauncher: (context) async {
                launchedActions.add(null);
                return null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('学号'), 'G12345678');
      await tester.enterText(_textFieldWithLabel('密码'), 'secret');
      await tester.tap(find.text('保存账密'));
      await tester.pumpAndSettle();

      expect(
        await AcademicCredentialService(store: store).load(),
        const AcademicCredential(
          studentId: 'G12345678',
          password: 'secret',
          autoLoginEnabled: true,
        ),
      );

      await tester.ensureVisible(find.text('自动提取课程'));
      await tester.tap(find.text('自动提取课程'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('自动提取考试'));
      await tester.tap(find.text('自动提取考试'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('手动打开教务页面'));
      await tester.tap(find.text('手动打开教务页面'));
      await tester.pumpAndSettle();

      expect(launchedActions, [
        AcademicAutoAction.timetable,
        AcademicAutoAction.exam,
        null,
      ]);
    },
  );

  testWidgets(
    'academic account page runs default auto import silently in place',
    (tester) async {
      final settings = await _createSettingsProvider();
      final store = _MemoryCredentialStore();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            home: AcademicAccountPage(
              credentialService: AcademicCredentialService(store: store),
              silentAutoImportBuilder: (context, action, onResult, onError) {
                return _SilentAutoImportProbe(
                  action: action,
                  onResult: onResult,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_textFieldWithLabel('学号'), 'G12345678');
      await tester.enterText(_textFieldWithLabel('密码'), 'secret');
      await tester.ensureVisible(find.text('自动提取考试'));
      await tester.tap(find.text('自动提取考试'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AcademicAccountPage), findsOneWidget);
      expect(find.text('教务账号'), findsOneWidget);
      expect(find.text('当前页面没有未结束考试安排'), findsOneWidget);
    },
  );
}

Future<SettingsProvider> _createSettingsProvider() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  final settings = SettingsProvider(storageService: storage);
  await settings.completeInitialSemesterStartDate(DateTime(2026, 2, 23));
  return settings;
}

Finder _textFieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

class _MemoryCredentialStore implements AcademicCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _SilentAutoImportProbe extends StatefulWidget {
  const _SilentAutoImportProbe({required this.action, required this.onResult});

  final AcademicAutoAction action;
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
          kind: AcademicImportKind.exam,
          importedCount: 0,
          skippedReasons: ['当前页面没有未结束考试安排'],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text('silent auto import ${widget.action.name}');
  }
}
