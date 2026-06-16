import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/update_manifest.dart';
import 'package:AnKe/services/app_update_platform.dart';
import 'package:AnKe/services/update_check_service.dart';
import 'package:AnKe/services/update_download_service.dart';
import 'package:AnKe/services/update_http_client.dart';

void main() {
  test('validates downloaded APK sha256', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/timetable.apk');
    await file.writeAsString('apk-bytes');

    const expectedHash =
        '1e10ba560383b17472b4cf72fef8f9e76c66815a3e6ae8c5a9b0c5e696b0bdf8';

    expect(
      UpdateDownloadService.verifySha256(file, expectedHash),
      completion(isTrue),
    );
    expect(
      UpdateDownloadService.verifySha256(file, '0' * 64),
      completion(isFalse),
    );
  });

  test('treats blank sha256 as not verifiable instead of valid', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/timetable.apk');
    await file.writeAsString('apk-bytes');

    expect(UpdateDownloadService.verifySha256(file, ''), completion(isFalse));
  });

  test('builds APK file path inside the provided temporary update directory', () {
    final directory = Directory(
      '/storage/emulated/0/Android/data/app/files/updates',
    );
    final update = AvailableUpdate(
      manifest: UpdateManifest(
        versionName: '0.3.5+2',
        versionCode: 2,
        releaseNotes: '',
        assets: [
          UpdateAsset(
            abi: 'arm64-v8a',
            url: Uri.parse('https://example.com/app.apk'),
            sha256:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            size: 2048,
          ),
        ],
      ),
      asset: UpdateAsset(
        abi: 'arm64-v8a',
        url: Uri.parse('https://example.com/app.apk'),
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        size: 2048,
      ),
    );

    final file = UpdateDownloadService.buildApkFile(directory, update);

    expect(file.parent.path, directory.path);
    expect(file.path, contains('timetable-0.3.5+2-arm64-v8a.apk'));
  });

  test(
    'retries APK download through a GitHub mirror after direct failure',
    () async {
      final directory = await Directory.systemTemp.createTemp('update-test-');
      addTearDown(() => directory.delete(recursive: true));

      final apkBytes = utf8.encode('apk-bytes');
      final expectedHash = sha256.convert(apkBytes).toString();
      final primaryUri = Uri.parse(
        'https://github.com/owner/repo/releases/download/v1/app-arm64-v8a.apk',
      );
      final mirrorUri = Uri.parse('https://gh-proxy.example/$primaryUri');
      final client = _FakeUpdateHttpClient([
        _FakeHttpFailure(const SocketException('blocked')),
        _FakeHttpSuccess(apkBytes),
      ]);
      final update = AvailableUpdate(
        manifest: UpdateManifest(
          versionName: '0.3.5+2',
          versionCode: 2,
          releaseNotes: '',
          assets: [
            UpdateAsset(
              abi: 'arm64-v8a',
              url: primaryUri,
              sha256: expectedHash,
              size: apkBytes.length,
            ),
          ],
        ),
        asset: UpdateAsset(
          abi: 'arm64-v8a',
          url: primaryUri,
          sha256: expectedHash,
          size: apkBytes.length,
        ),
      );
      final service = UpdateDownloadService(
        platform: _FakeAppUpdatePlatform(directory),
        httpClientFactory: () => client,
        githubMirrorPrefixes: const ['https://gh-proxy.example/'],
      );

      final file = await service.downloadApk(update);

      expect(client.requestedUris, [primaryUri, mirrorUri]);
      expect(await file.readAsBytes(), apkBytes);
    },
  );

  test('retries GitHub Release mirror when the R2 URL fails', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));

    final apkBytes = utf8.encode('apk-bytes');
    final expectedHash = sha256.convert(apkBytes).toString();
    final r2Uri = Uri.parse(
      'https://download.277620035.xyz/releases/0.3.10+2/timetable-0.3.10+2-arm64-v8a.apk',
    );
    final githubUri = Uri.parse(
      'https://github.com/owner/repo/releases/download/v0.3.10%2B2/timetable-0.3.10%2B2-arm64-v8a.apk',
    );
    final githubMirrorUri = Uri.parse('https://gh-proxy.example/$githubUri');
    final client = _FakeUpdateHttpClient([
      _FakeHttpFailure(const SocketException('r2 unavailable')),
      _FakeHttpSuccess(apkBytes),
    ]);
    final update = AvailableUpdate(
      manifest: UpdateManifest(
        versionName: '0.3.10',
        versionCode: 2002,
        releaseNotes: '',
        assets: [
          UpdateAsset(
            abi: 'arm64-v8a',
            url: r2Uri,
            mirrorUrls: [githubUri],
            sha256: expectedHash,
            size: apkBytes.length,
          ),
        ],
      ),
      asset: UpdateAsset(
        abi: 'arm64-v8a',
        url: r2Uri,
        mirrorUrls: [githubUri],
        sha256: expectedHash,
        size: apkBytes.length,
      ),
    );
    final service = UpdateDownloadService(
      platform: _FakeAppUpdatePlatform(directory),
      httpClientFactory: () => client,
      githubMirrorPrefixes: const ['https://gh-proxy.example/'],
    );

    final file = await service.downloadApk(update);

    expect(client.requestedUris, [r2Uri, githubUri]);
    expect(client.requestedUris, isNot(contains(githubMirrorUri)));
    expect(await file.readAsBytes(), apkBytes);
  });

  test('reuses a verified downloaded APK for the same update', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));

    final apkBytes = utf8.encode('apk-bytes');
    final expectedHash = sha256.convert(apkBytes).toString();
    final update = _availableUpdate(expectedHash: expectedHash);
    final existingFile = UpdateDownloadService.buildApkFile(directory, update);
    await directory.create(recursive: true);
    await existingFile.writeAsBytes(apkBytes);
    await UpdateDownloadService.writeDownloadedApkMarker(
      directory,
      update,
      existingFile,
    );
    final client = _FakeUpdateHttpClient([
      _FakeHttpFailure(StateError('network should not be used')),
    ]);
    final service = UpdateDownloadService(
      platform: _FakeAppUpdatePlatform(directory),
      httpClientFactory: () => client,
    );

    final file = await service.downloadApk(update);

    expect(file.path, existingFile.path);
    expect(client.requestedUris, isEmpty);
  });

  test('ignores a downloaded APK marker for an older update version', () async {
    final directory = await Directory.systemTemp.createTemp('update-test-');
    addTearDown(() => directory.delete(recursive: true));

    final oldBytes = utf8.encode('old-apk-bytes');
    final newBytes = utf8.encode('new-apk-bytes');
    final oldUpdate = _availableUpdate(
      versionCode: 3,
      expectedHash: sha256.convert(oldBytes).toString(),
    );
    final newUpdate = _availableUpdate(
      versionCode: 4,
      expectedHash: sha256.convert(newBytes).toString(),
    );
    final oldFile = UpdateDownloadService.buildApkFile(directory, oldUpdate);
    await directory.create(recursive: true);
    await oldFile.writeAsBytes(oldBytes);
    await UpdateDownloadService.writeDownloadedApkMarker(
      directory,
      oldUpdate,
      oldFile,
    );
    final client = _FakeUpdateHttpClient([_FakeHttpSuccess(newBytes)]);
    final service = UpdateDownloadService(
      platform: _FakeAppUpdatePlatform(directory),
      httpClientFactory: () => client,
    );

    final file = await service.downloadApk(newUpdate);

    expect(client.requestedUris, [newUpdate.asset.url]);
    expect(await file.readAsBytes(), newBytes);
  });
}

AvailableUpdate _availableUpdate({
  int versionCode = 3,
  required String expectedHash,
}) {
  final uri = Uri.parse('https://example.com/app.apk');
  final asset = UpdateAsset(
    abi: 'arm64-v8a',
    url: uri,
    sha256: expectedHash,
    size: 2048,
    versionCode: versionCode,
  );
  return AvailableUpdate(
    manifest: UpdateManifest(
      versionName: '0.3.5',
      versionCode: versionCode,
      releaseNotes: '',
      assets: [asset],
    ),
    asset: asset,
  );
}

class _FakeAppUpdatePlatform extends AppUpdatePlatform {
  const _FakeAppUpdatePlatform(this.directory);

  final Directory directory;

  @override
  Future<Directory?> downloadDirectory() async => directory;
}

class _FakeUpdateHttpClient implements UpdateHttpClient {
  _FakeUpdateHttpClient(this._responses);

  final List<_FakeHttpResult> _responses;
  final List<Uri> requestedUris = [];

  @override
  Future<UpdateHttpResponse> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    requestedUris.add(uri);
    final response = _responses.removeAt(0);
    return response.resolve(uri);
  }

  @override
  void close() {}
}

abstract class _FakeHttpResult {
  Future<UpdateHttpResponse> resolve(Uri uri);
}

class _FakeHttpSuccess implements _FakeHttpResult {
  const _FakeHttpSuccess(this.bytes);

  final List<int> bytes;

  @override
  Future<UpdateHttpResponse> resolve(Uri uri) async {
    return UpdateHttpResponse(
      statusCode: 200,
      contentLength: bytes.length,
      bytes: Stream.value(bytes),
      uri: uri,
    );
  }
}

class _FakeHttpFailure implements _FakeHttpResult {
  const _FakeHttpFailure(this.error);

  final Object error;

  @override
  Future<UpdateHttpResponse> resolve(Uri uri) async {
    throw error;
  }
}
