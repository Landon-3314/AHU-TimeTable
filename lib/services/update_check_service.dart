import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_manifest.dart';
import 'app_update_platform.dart';

typedef UpdateManifestLoader = Future<UpdateManifest> Function();
typedef IntLoader = Future<int?> Function();
typedef IntWriter = Future<void> Function(int value);
typedef AbiLoader = Future<List<String>> Function();

class AvailableUpdate {
  const AvailableUpdate({required this.manifest, required this.asset});

  final UpdateManifest manifest;
  final UpdateAsset asset;
}

class UpdateCheckService {
  UpdateCheckService({
    required UpdateManifestLoader manifestLoader,
    required Future<int> Function() currentVersionCodeLoader,
    required AbiLoader supportedAbisLoader,
    required IntLoader ignoredVersionCodeLoader,
    required IntWriter ignoredVersionCodeWriter,
  }) : _manifestLoader = manifestLoader,
       _currentVersionCodeLoader = currentVersionCodeLoader,
       _supportedAbisLoader = supportedAbisLoader,
       _ignoredVersionCodeLoader = ignoredVersionCodeLoader,
       _ignoredVersionCodeWriter = ignoredVersionCodeWriter;

  factory UpdateCheckService.githubManifest({
    AppUpdatePlatform platform = const AppUpdatePlatform(),
    Uri? manifestUri,
  }) {
    final effectiveManifestUri = manifestUri ?? defaultManifestUri;
    return UpdateCheckService(
      manifestLoader: () => _loadManifestFromUri(effectiveManifestUri),
      currentVersionCodeLoader: platform.currentVersionCode,
      supportedAbisLoader: platform.supportedAbis,
      ignoredVersionCodeLoader: _loadIgnoredVersionCode,
      ignoredVersionCodeWriter: _writeIgnoredVersionCode,
    );
  }

  static final Uri defaultManifestUri = Uri.parse(
    'https://raw.githubusercontent.com/Landon-3314/AHU-TimeTable/main/update.json',
  );
  static const String _ignoredVersionCodeKey = 'updates.ignoredVersionCode.v1';

  final UpdateManifestLoader _manifestLoader;
  final Future<int> Function() _currentVersionCodeLoader;
  final AbiLoader _supportedAbisLoader;
  final IntLoader _ignoredVersionCodeLoader;
  final IntWriter _ignoredVersionCodeWriter;

  Future<AvailableUpdate?> checkForUpdate() async {
    try {
      return await checkForUpdateOrThrow();
    } catch (_) {
      return null;
    }
  }

  Future<AvailableUpdate?> checkForUpdateOrThrow({
    bool respectIgnoredVersion = true,
  }) async {
    final currentVersionCode = await _currentVersionCodeLoader();
    final ignoredVersionCode = respectIgnoredVersion
        ? await _ignoredVersionCodeLoader()
        : null;
    final supportedAbis = await _supportedAbisLoader();
    if (supportedAbis.isEmpty) {
      return null;
    }

    final manifest = await _manifestLoader();
    if (manifest.versionCode <= currentVersionCode ||
        manifest.versionCode == ignoredVersionCode) {
      return null;
    }

    final asset = manifest.selectAssetForAbis(supportedAbis);
    if (asset == null) {
      return null;
    }
    return AvailableUpdate(manifest: manifest, asset: asset);
  }

  Future<void> ignoreUpdate(AvailableUpdate update) {
    return _ignoredVersionCodeWriter(update.manifest.versionCode);
  }

  static Future<UpdateManifest> _loadManifestFromUri(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Update manifest request failed', uri: uri);
      }
      final body = await utf8.decodeStream(response);
      return UpdateManifest.fromJson(jsonDecode(body) as Map<String, Object?>);
    } finally {
      client.close(force: true);
    }
  }

  static Future<int?> _loadIgnoredVersionCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ignoredVersionCodeKey);
  }

  static Future<void> _writeIgnoredVersionCode(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ignoredVersionCodeKey, value);
  }
}
