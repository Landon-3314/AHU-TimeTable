import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/models/update_manifest.dart';
import 'package:timetable/services/update_check_service.dart';

void main() {
  const manifestJson = '''
{
  "versionName": "0.3.4",
  "versionCode": 2,
  "releaseNotes": "修复提醒并优化课表导入",
  "assets": [
    {
      "abi": "armeabi-v7a",
      "url": "https://example.com/timetable-0.3.4-armeabi-v7a.apk",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "size": 111
    },
    {
      "abi": "arm64-v8a",
      "url": "https://example.com/timetable-0.3.4-arm64-v8a.apk",
      "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "size": 222
    }
  ]
}
''';

  test('parses update manifest and selects the best supported ABI asset', () {
    final manifest = UpdateManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );

    expect(manifest.versionName, '0.3.4');
    expect(manifest.versionCode, 2);
    expect(manifest.releaseNotes, '修复提醒并优化课表导入');

    final asset = manifest.selectAssetForAbis([
      'x86_64',
      'arm64-v8a',
      'armeabi-v7a',
    ]);

    expect(asset, isNotNull);
    expect(asset!.abi, 'arm64-v8a');
    expect(asset.url.toString(), contains('arm64-v8a.apk'));
  });

  test('rejects invalid manifests without usable assets', () {
    expect(
      () => UpdateManifest.fromJson(const {
        'versionName': '0.3.4',
        'versionCode': 2,
        'assets': <Object?>[],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('returns available update only when remote version is newer', () {
    final manifest = UpdateManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );
    final service = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['arm64-v8a', 'armeabi-v7a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );

    expect(service.checkForUpdate(), completion(isA<AvailableUpdate>()));
  });

  test(
    'skips update when version is current, ignored, or ABI is unsupported',
    () async {
      final manifest = UpdateManifest.fromJson(
        jsonDecode(manifestJson) as Map<String, Object?>,
      );

      final currentVersionService = UpdateCheckService(
        manifestLoader: () async => manifest,
        currentVersionCodeLoader: () async => 2,
        supportedAbisLoader: () async => const ['arm64-v8a'],
        ignoredVersionCodeLoader: () async => null,
        ignoredVersionCodeWriter: (_) async {},
      );
      expect(await currentVersionService.checkForUpdate(), isNull);

      final ignoredService = UpdateCheckService(
        manifestLoader: () async => manifest,
        currentVersionCodeLoader: () async => 1,
        supportedAbisLoader: () async => const ['arm64-v8a'],
        ignoredVersionCodeLoader: () async => 2,
        ignoredVersionCodeWriter: (_) async {},
      );
      expect(await ignoredService.checkForUpdate(), isNull);

      final unsupportedAbiService = UpdateCheckService(
        manifestLoader: () async => manifest,
        currentVersionCodeLoader: () async => 1,
        supportedAbisLoader: () async => const ['x86_64'],
        ignoredVersionCodeLoader: () async => null,
        ignoredVersionCodeWriter: (_) async {},
      );
      expect(await unsupportedAbiService.checkForUpdate(), isNull);
    },
  );

  test('writes ignored version code for the selected update', () async {
    int? ignoredVersionCode;
    final manifest = UpdateManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );
    final service = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => ignoredVersionCode,
      ignoredVersionCodeWriter: (value) async {
        ignoredVersionCode = value;
      },
    );

    final update = await service.checkForUpdate();
    await service.ignoreUpdate(update!);

    expect(ignoredVersionCode, 2);
    expect(await service.checkForUpdate(), isNull);
  });

  test(
    'checkForUpdate swallows errors but checkForUpdateOrThrow reports them',
    () async {
      final service = UpdateCheckService(
        manifestLoader: () async => throw const FormatException('bad manifest'),
        currentVersionCodeLoader: () async => 1,
        supportedAbisLoader: () async => const ['arm64-v8a'],
        ignoredVersionCodeLoader: () async => null,
        ignoredVersionCodeWriter: (_) async {},
      );

      expect(await service.checkForUpdate(), isNull);
      expect(service.checkForUpdateOrThrow(), throwsA(isA<FormatException>()));
    },
  );
}
