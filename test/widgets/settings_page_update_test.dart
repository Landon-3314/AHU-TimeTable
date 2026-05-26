import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/update_manifest.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/settings_page.dart';
import 'package:timetable/services/app_update_platform.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/services/update_check_service.dart';

void main() {
  testWidgets('settings page shows manual update check entry', (tester) async {
    final bundle = await _createProviderBundle();

    await tester.pumpWidget(
      _SettingsHost(
        settings: bundle.settings,
        courses: bundle.courses,
        child: const SettingsPage(),
      ),
    );

    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('手动检测新版本'), findsOneWidget);
  });

  testWidgets('manual update check shows progress and ignores repeat taps', (
    tester,
  ) async {
    final bundle = await _createProviderBundle();
    final manifestCompleter = Completer<UpdateManifest>();
    var manifestLoadCount = 0;
    final updateService = UpdateCheckService(
      manifestLoader: () {
        manifestLoadCount += 1;
        return manifestCompleter.future;
      },
      currentVersionCodeLoader: () async => 2,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );

    await tester.pumpWidget(
      _SettingsHost(
        settings: bundle.settings,
        courses: bundle.courses,
        child: SettingsPage(
          updatePlatform: const _SupportedUpdatePlatform(),
          updateCheckService: updateService,
        ),
      ),
    );

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(find.text('正在检测更新...'), findsOneWidget);

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    expect(manifestLoadCount, 1);

    manifestCompleter.complete(_manifest(versionCode: 2));
    await tester.pumpAndSettle();
    expect(find.text('当前已是最新版本'), findsOneWidget);
  });
}

class _SupportedUpdatePlatform extends AppUpdatePlatform {
  const _SupportedUpdatePlatform();

  @override
  bool get isSupported => true;

  @override
  Future<void> cleanupDownloadedApks() async {}
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

Future<_ProviderBundle> _createProviderBundle() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return _ProviderBundle(
    settings: SettingsProvider(storageService: storage),
    courses: CourseProvider(storageService: storage),
  );
}

UpdateManifest _manifest({required int versionCode}) {
  return UpdateManifest(
    versionName: '0.3.4',
    versionCode: versionCode,
    releaseNotes: '修复提醒',
    assets: [
      UpdateAsset(
        abi: 'arm64-v8a',
        url: Uri.parse('https://example.com/app.apk'),
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        size: 2048,
      ),
    ],
  );
}

class _ProviderBundle {
  const _ProviderBundle({required this.settings, required this.courses});

  final SettingsProvider settings;
  final CourseProvider courses;
}
