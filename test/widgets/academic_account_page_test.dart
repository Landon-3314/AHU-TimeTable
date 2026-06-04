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
}

Future<SettingsProvider> _createSettingsProvider() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return SettingsProvider(storageService: storage);
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
