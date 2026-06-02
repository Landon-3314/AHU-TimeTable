import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/models/update_manifest.dart';
import 'package:timetable/providers/course_provider.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/screens/settings_page.dart';
import 'package:timetable/services/app_update_platform.dart';
import 'package:timetable/services/external_data_backup_store.dart';
import 'package:timetable/services/storage_service.dart';
import 'package:timetable/services/update_check_service.dart';
import 'package:timetable/services/update_download_service.dart';

void main() {
  testWidgets(
    'settings page shows update entry separately from data management',
    (tester) async {
      final bundle = await _createProviderBundle();

      await tester.pumpWidget(
        _SettingsHost(
          settings: bundle.settings,
          courses: bundle.courses,
          child: const SettingsPage(),
        ),
      );

      expect(find.text('应用更新'), findsOneWidget);
      expect(find.text('检查更新'), findsOneWidget);
      expect(find.text('手动检测新版本'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('数据管理'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('数据管理'), findsOneWidget);
      expect(find.text('高级与数据管理'), findsNothing);
    },
  );

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

    await _scrollToUpdateEntry(tester);
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

  testWidgets('manual update creates external backup before installing', (
    tester,
  ) async {
    final backupStore = _RecordingBackupStore();
    final bundle = await _createProviderBundle(
      externalDataBackupStore: backupStore,
    );
    final downloadService = _RecordingUpdateDownloadService(
      backupReadyAtInstall: () => backupStore.writeCount > 0,
    );
    final updateService = _availableUpdateService(versionCode: 3);

    await tester.pumpWidget(
      _SettingsHost(
        settings: bundle.settings,
        courses: bundle.courses,
        child: SettingsPage(
          updatePlatform: const _SupportedUpdatePlatform(),
          updateCheckService: updateService,
          updateDownloadService: downloadService,
        ),
      ),
    );

    await _scrollToUpdateEntry(tester);
    await tester.tap(find.text('检查更新'));
    await _pumpUntilFound(tester, find.text('立即更新'));
    await tester.tap(find.text('立即更新'));
    await _pumpUntilFound(tester, find.text('已打开系统安装器，请确认安装'));

    expect(downloadService.installCallCount, 1);
    expect(downloadService.backupExistedAtInstall, isTrue);
    expect(find.text('已打开系统安装器，请确认安装'), findsOneWidget);
  });

  testWidgets('manual update cancels install when backup fails', (
    tester,
  ) async {
    final bundle = await _createProviderBundle(
      externalDataBackupStore: const _FailingBackupStore(),
    );
    final downloadService = _RecordingUpdateDownloadService();
    final updateService = _availableUpdateService(versionCode: 3);

    await tester.pumpWidget(
      _SettingsHost(
        settings: bundle.settings,
        courses: bundle.courses,
        child: SettingsPage(
          updatePlatform: const _SupportedUpdatePlatform(),
          updateCheckService: updateService,
          updateDownloadService: downloadService,
        ),
      ),
    );

    await _scrollToUpdateEntry(tester);
    await tester.tap(find.text('检查更新'));
    await _pumpUntilFound(tester, find.text('立即更新'));
    await tester.tap(find.text('立即更新'));
    await _pumpUntilFound(tester, find.text('本地数据备份失败，已取消更新'));

    expect(downloadService.downloadCallCount, 0);
    expect(downloadService.installCallCount, 0);
    expect(find.text('本地数据备份失败，已取消更新'), findsOneWidget);
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

Future<_ProviderBundle> _createProviderBundle({
  ExternalDataBackupStore? externalDataBackupStore,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(
    sharedPreferences: preferences,
    externalDataBackupStore: externalDataBackupStore,
  );
  await storage.ensureSemesterMigration();
  return _ProviderBundle(
    settings: SettingsProvider(storageService: storage),
    courses: CourseProvider(storageService: storage),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<void> _scrollToUpdateEntry(WidgetTester tester) async {
  await tester.ensureVisible(find.text('检查更新'));
  await tester.pumpAndSettle();
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

UpdateCheckService _availableUpdateService({required int versionCode}) {
  final manifest = _manifest(versionCode: versionCode);
  return UpdateCheckService(
    manifestLoader: () async => manifest,
    currentVersionCodeLoader: () async => versionCode - 1,
    supportedAbisLoader: () async => const ['arm64-v8a'],
    ignoredVersionCodeLoader: () async => null,
    ignoredVersionCodeWriter: (_) async {},
  );
}

class _ProviderBundle {
  const _ProviderBundle({required this.settings, required this.courses});

  final SettingsProvider settings;
  final CourseProvider courses;
}

class _RecordingUpdateDownloadService extends UpdateDownloadService {
  _RecordingUpdateDownloadService({this.backupReadyAtInstall});

  final bool Function()? backupReadyAtInstall;
  int downloadCallCount = 0;
  int installCallCount = 0;
  bool backupExistedAtInstall = false;

  @override
  Future<File> downloadApk(
    AvailableUpdate update, {
    UpdateDownloadProgress? onProgress,
  }) async {
    downloadCallCount += 1;
    return File('fake-update.apk');
  }

  @override
  Future<bool> install(File apkFile) async {
    installCallCount += 1;
    backupExistedAtInstall = backupReadyAtInstall?.call() ?? true;
    return true;
  }
}

class _RecordingBackupStore extends ExternalDataBackupStore {
  int writeCount = 0;

  @override
  Future<bool> writeFromSharedPreferences(SharedPreferences preferences) async {
    writeCount += 1;
    return true;
  }

  @override
  Future<ExternalDataRecoveryStatus> restoreToSharedPreferences(
    SharedPreferences preferences,
  ) async {
    return ExternalDataRecoveryStatus.unavailable;
  }
}

class _FailingBackupStore extends ExternalDataBackupStore {
  const _FailingBackupStore();

  @override
  Future<bool> writeFromSharedPreferences(SharedPreferences preferences) async {
    return false;
  }

  @override
  Future<ExternalDataRecoveryStatus> restoreToSharedPreferences(
    SharedPreferences preferences,
  ) async {
    return ExternalDataRecoveryStatus.unavailable;
  }
}
