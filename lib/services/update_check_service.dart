import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/update_manifest.dart';
import 'app_update_platform.dart';
import 'update_http_client.dart';
import 'update_mirror_urls.dart';

typedef UpdateManifestLoader = Future<UpdateManifest> Function();
typedef UpdateManifestUriLoader = Future<UpdateManifest> Function(Uri uri);
typedef IntLoader = Future<int?> Function();
typedef IntWriter = Future<void> Function(int value);
typedef AbiLoader = Future<List<String>> Function();

class AvailableUpdate {
  const AvailableUpdate({required this.manifest, required this.asset});

  final UpdateManifest manifest;
  final UpdateAsset asset;

  int get effectiveVersionCode => asset.versionCode ?? manifest.versionCode;
}

enum UpdateCheckStatus {
  updateAvailable,
  noUpdate,
  checkFailed,
  unsupportedAbi,
}

class UpdateCheckResult {
  const UpdateCheckResult._({required this.status, this.update, this.error});

  const UpdateCheckResult.updateAvailable(AvailableUpdate update)
    : this._(status: UpdateCheckStatus.updateAvailable, update: update);

  const UpdateCheckResult.noUpdate()
    : this._(status: UpdateCheckStatus.noUpdate);

  const UpdateCheckResult.checkFailed(Object error)
    : this._(status: UpdateCheckStatus.checkFailed, error: error);

  const UpdateCheckResult.unsupportedAbi()
    : this._(status: UpdateCheckStatus.unsupportedAbi);

  final UpdateCheckStatus status;
  final AvailableUpdate? update;
  final Object? error;
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
    List<Uri>? manifestUris,
    UpdateManifestUriLoader? manifestUriLoader,
    List<String> githubMirrorPrefixes =
        UpdateMirrorUrls.defaultGithubMirrorPrefixes,
  }) {
    final effectiveManifestUris =
        manifestUris ??
        (manifestUri == null
            ? defaultManifestUris
            : UpdateMirrorUrls.withGithubMirrors(
                manifestUri,
                githubMirrorPrefixes: githubMirrorPrefixes,
              ));
    return UpdateCheckService(
      manifestLoader: () => loadManifestFromUris(
        effectiveManifestUris,
        loader: manifestUriLoader ?? _loadManifestFromUri,
      ),
      currentVersionCodeLoader: platform.currentVersionCode,
      supportedAbisLoader: platform.supportedAbis,
      ignoredVersionCodeLoader: _loadIgnoredVersionCode,
      ignoredVersionCodeWriter: _writeIgnoredVersionCode,
    );
  }

  static final Uri defaultManifestUri = Uri.parse(
    'https://update.277620035.xyz/latest',
  );
  static final List<Uri> defaultManifestUris = [defaultManifestUri];
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
    final result = await _checkForUpdateDetailedOrThrow(
      respectIgnoredVersion: respectIgnoredVersion,
    );
    return result.update;
  }

  Future<UpdateCheckResult> checkForUpdateDetailed({
    bool respectIgnoredVersion = true,
  }) async {
    try {
      return await _checkForUpdateDetailedOrThrow(
        respectIgnoredVersion: respectIgnoredVersion,
      );
    } catch (error) {
      return UpdateCheckResult.checkFailed(error);
    }
  }

  Future<UpdateCheckResult> _checkForUpdateDetailedOrThrow({
    required bool respectIgnoredVersion,
  }) async {
    final currentVersionCode = await _currentVersionCodeLoader();
    final ignoredVersionCode = respectIgnoredVersion
        ? await _ignoredVersionCodeLoader()
        : null;
    final supportedAbis = await _supportedAbisLoader();
    if (supportedAbis.isEmpty) {
      return const UpdateCheckResult.unsupportedAbi();
    }

    final manifest = await _manifestLoader();
    final asset = manifest.selectAssetForAbis(supportedAbis);
    if (asset == null) {
      return const UpdateCheckResult.unsupportedAbi();
    }
    final update = AvailableUpdate(manifest: manifest, asset: asset);
    if (update.effectiveVersionCode <= currentVersionCode ||
        update.effectiveVersionCode == ignoredVersionCode) {
      return const UpdateCheckResult.noUpdate();
    }
    return UpdateCheckResult.updateAvailable(update);
  }

  Future<void> ignoreUpdate(AvailableUpdate update) {
    return _ignoredVersionCodeWriter(update.effectiveVersionCode);
  }

  static Future<UpdateManifest> loadManifestFromUris(
    List<Uri> uris, {
    UpdateManifestUriLoader? loader,
  }) async {
    if (uris.isEmpty) {
      throw ArgumentError.value(uris, 'uris', 'Must not be empty');
    }
    final effectiveLoader = loader ?? _loadManifestFromUri;
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final uri in uris) {
      try {
        return await effectiveLoader(uri);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  static Future<UpdateManifest> _loadManifestFromUri(Uri uri) async {
    final client = createDefaultUpdateHttpClient();
    try {
      final response = await client.get(
        uri,
        headers: const {
          'accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Update manifest request failed: $uri');
      }
      final body = await utf8.decodeStream(response.bytes);
      return UpdateManifest.fromJson(jsonDecode(body) as Map<String, Object?>);
    } finally {
      client.close();
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
