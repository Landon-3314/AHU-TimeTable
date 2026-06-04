import 'dart:convert';
import 'dart:io';

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

  test('parses split APK version codes from the update manifest', () {
    final manifest = UpdateManifest.fromJson(const {
      'versionName': '0.3.8',
      'versionCode': 4003,
      'baseVersionCode': 3,
      'assets': [
        {
          'abi': 'arm64-v8a',
          'url': 'https://example.com/timetable-0.3.8-arm64-v8a.apk',
          'sha256':
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 2048,
          'versionCode': 2003,
        },
      ],
    });

    expect(manifest.versionCode, 4003);
    expect(manifest.baseVersionCode, 3);
    expect(manifest.assets.single.versionCode, 2003);
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

  test('rejects update manifests with unsafe or unverifiable APK assets', () {
    for (final invalidAsset in <Map<String, Object?>>[
      {
        'abi': 'arm64-v8a',
        'url': 'http://example.com/app.apk',
        'sha256': 'b' * 64,
        'size': 2048,
      },
      {
        'abi': 'arm64-v8a',
        'url': 'https://example.com/app.apk',
        'sha256': 'not-a-sha',
        'size': 2048,
      },
    ]) {
      expect(
        () => UpdateManifest.fromJson({
          'versionName': '0.3.4',
          'versionCode': 2,
          'assets': [invalidAsset],
        }),
        throwsA(isA<FormatException>()),
      );
    }

    expect(
      () => UpdateManifest.fromJson(const {
        'versionName': '0.3.4',
        'versionCode': 0,
        'assets': [
          {
            'abi': 'arm64-v8a',
            'url': 'https://example.com/app.apk',
            'sha256':
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'size': 2048,
          },
        ],
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

  test('uses the Cloudflare Worker manifest endpoint by default', () {
    expect(UpdateCheckService.defaultManifestUris, hasLength(1));
    expect(
      UpdateCheckService.defaultManifestUris.single.toString(),
      'https://update.277620035.xyz/latest',
    );
  });

  test('reports detailed update check status for each outcome', () async {
    final manifest = UpdateManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );

    final availableService = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    final available = await availableService.checkForUpdateDetailed();
    expect(available.status, UpdateCheckStatus.updateAvailable);
    expect(available.update, isA<AvailableUpdate>());
    expect(available.error, isNull);

    final currentVersionService = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 2,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    final currentVersion = await currentVersionService.checkForUpdateDetailed();
    expect(currentVersion.status, UpdateCheckStatus.noUpdate);
    expect(currentVersion.update, isNull);

    final unsupportedAbiService = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['x86_64'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    final unsupportedAbi = await unsupportedAbiService.checkForUpdateDetailed();
    expect(unsupportedAbi.status, UpdateCheckStatus.unsupportedAbi);
    expect(unsupportedAbi.update, isNull);

    final failedService = UpdateCheckService(
      manifestLoader: () async => throw const FormatException('bad manifest'),
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    final failed = await failedService.checkForUpdateDetailed();
    expect(failed.status, UpdateCheckStatus.checkFailed);
    expect(failed.update, isNull);
    expect(failed.error, isA<FormatException>());
  });

  test('detailed update check treats ignored versions as no update', () async {
    final manifest = UpdateManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );
    final service = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => 2,
      ignoredVersionCodeWriter: (_) async {},
    );

    final result = await service.checkForUpdateDetailed();

    expect(result.status, UpdateCheckStatus.noUpdate);
    expect(result.update, isNull);
  });

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

  test('compares the selected split APK asset version code', () async {
    final manifest = UpdateManifest.fromJson(const {
      'versionName': '0.3.8',
      'versionCode': 4003,
      'baseVersionCode': 3,
      'assets': [
        {
          'abi': 'armeabi-v7a',
          'url': 'https://example.com/timetable-0.3.8-armeabi-v7a.apk',
          'sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          'size': 2048,
          'versionCode': 1003,
        },
        {
          'abi': 'arm64-v8a',
          'url': 'https://example.com/timetable-0.3.8-arm64-v8a.apk',
          'sha256':
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 2048,
          'versionCode': 2003,
        },
        {
          'abi': 'x86_64',
          'url': 'https://example.com/timetable-0.3.8-x86_64.apk',
          'sha256':
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          'size': 2048,
          'versionCode': 4003,
        },
      ],
    });

    final arm64AvailableService = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 2001,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    final arm64Available = await arm64AvailableService.checkForUpdateDetailed();
    expect(arm64Available.status, UpdateCheckStatus.updateAvailable);
    expect(arm64Available.update!.effectiveVersionCode, 2003);

    final arm64CurrentService = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 2003,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    expect(
      (await arm64CurrentService.checkForUpdateDetailed()).status,
      UpdateCheckStatus.noUpdate,
    );

    final x64AvailableService = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 4002,
      supportedAbisLoader: () async => const ['x86_64'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );
    final x64Available = await x64AvailableService.checkForUpdateDetailed();
    expect(x64Available.status, UpdateCheckStatus.updateAvailable);
    expect(x64Available.update!.effectiveVersionCode, 4003);
  });

  test('falls back to manifest version code for legacy assets', () async {
    final manifest = UpdateManifest.fromJson(
      jsonDecode(manifestJson) as Map<String, Object?>,
    );
    final service = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 1,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => null,
      ignoredVersionCodeWriter: (_) async {},
    );

    final result = await service.checkForUpdateDetailed();

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.update!.effectiveVersionCode, 2);
  });

  test('writes ignored version code for the selected split APK asset', () async {
    int? ignoredVersionCode;
    final manifest = UpdateManifest.fromJson(const {
      'versionName': '0.3.8',
      'versionCode': 4003,
      'baseVersionCode': 3,
      'assets': [
        {
          'abi': 'arm64-v8a',
          'url': 'https://example.com/timetable-0.3.8-arm64-v8a.apk',
          'sha256':
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          'size': 2048,
          'versionCode': 2003,
        },
      ],
    });
    final service = UpdateCheckService(
      manifestLoader: () async => manifest,
      currentVersionCodeLoader: () async => 2001,
      supportedAbisLoader: () async => const ['arm64-v8a'],
      ignoredVersionCodeLoader: () async => ignoredVersionCode,
      ignoredVersionCodeWriter: (value) async {
        ignoredVersionCode = value;
      },
    );

    final update = await service.checkForUpdate();
    await service.ignoreUpdate(update!);

    expect(ignoredVersionCode, 2003);
    expect(await service.checkForUpdate(), isNull);
  });

  test(
    'loads update manifest from fallback URI when the primary fails',
    () async {
      final requestedUris = <Uri>[];
      final primaryUri = Uri.parse(
        'https://raw.githubusercontent.com/app/update.json',
      );
      final fallbackUri = Uri.parse(
        'https://cdn.jsdelivr.net/gh/app/repo@main/update.json',
      );

      final manifest = await UpdateCheckService.loadManifestFromUris(
        [primaryUri, fallbackUri],
        loader: (uri) async {
          requestedUris.add(uri);
          if (uri == primaryUri) {
            throw const SocketException('blocked');
          }
          return UpdateManifest.fromJson(
            jsonDecode(manifestJson) as Map<String, Object?>,
          );
        },
      );

      expect(manifest.versionCode, 2);
      expect(requestedUris, [primaryUri, fallbackUri]);
    },
  );
}
