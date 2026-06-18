import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'app_update_platform.dart';
import 'update_check_service.dart';
import 'update_http_client.dart';
import 'update_mirror_urls.dart';

typedef UpdateDownloadProgress = void Function(int received, int? total);

class UpdateDownloadService {
  const UpdateDownloadService({
    AppUpdatePlatform platform = const AppUpdatePlatform(),
    UpdateHttpClientFactory httpClientFactory = createDefaultUpdateHttpClient,
    List<String> githubMirrorPrefixes =
        UpdateMirrorUrls.defaultGithubMirrorPrefixes,
  }) : _platform = platform,
       _httpClientFactory = httpClientFactory,
       _githubMirrorPrefixes = githubMirrorPrefixes;

  final AppUpdatePlatform _platform;
  final UpdateHttpClientFactory _httpClientFactory;
  final List<String> _githubMirrorPrefixes;

  static const String _downloadMarkerFileName =
      'timetable-update-download.json';

  Future<File> downloadApk(
    AvailableUpdate update, {
    UpdateDownloadProgress? onProgress,
  }) async {
    final directory = await _platform.downloadDirectory();
    if (directory == null) {
      throw const FileSystemException('Download directory is unavailable');
    }
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final targetFile = buildApkFile(directory, update);
    final reusableFile = await _findReusableDownloadedApk(
      directory,
      targetFile,
      update,
    );
    if (reusableFile != null) {
      return reusableFile;
    }

    Object? lastError;
    StackTrace? lastStackTrace;
    for (final uri in candidateDownloadUris(
      update,
      githubMirrorPrefixes: _githubMirrorPrefixes,
    )) {
      try {
        return await _downloadApkFromUri(
          uri,
          targetFile,
          update,
          onProgress: onProgress,
        );
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (await targetFile.exists()) {
          try {
            await targetFile.delete();
          } catch (deleteError) {
            debugPrint(
              '[UpdateDownloadService] Failed to delete partial APK: '
              '$deleteError',
            );
          }
        }
        await _deleteDownloadedApkMarker(directory);
      }
    }
    if (lastError == null || lastStackTrace == null) {
      throw StateError('No download URIs available for update APK');
    }
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  Future<File> _downloadApkFromUri(
    Uri uri,
    File file,
    AvailableUpdate update, {
    UpdateDownloadProgress? onProgress,
  }) async {
    final client = _httpClientFactory();
    try {
      final response = await client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('APK download failed', uri: uri);
      }
      await _writeResponseToFile(response, file, onProgress);

      final verified = await verifySha256(file, update.asset.sha256);
      if (!verified) {
        try {
          await file.delete();
        } catch (deleteError) {
          debugPrint(
            '[UpdateDownloadService] Failed to delete APK after sha256 '
            'mismatch: $deleteError',
          );
        }
        await _deleteDownloadedApkMarker(file.parent);
        throw const FormatException('APK sha256 mismatch');
      }
      await writeDownloadedApkMarker(file.parent, update, file);
      return file;
    } finally {
      client.close();
    }
  }

  Future<AppUpdateInstallResult> install(
    File apkFile, {
    AvailableUpdate? update,
  }) {
    return _platform.installApk(
      apkFile,
      versionCode: update?.effectiveVersionCode,
    );
  }

  static File buildApkFile(Directory directory, AvailableUpdate update) {
    return File(
      '${directory.path}${Platform.pathSeparator}'
      'timetable-${_sanitizeFilePart(update.manifest.versionName)}-'
      '${_sanitizeFilePart(update.asset.abi)}.apk',
    );
  }

  static Future<void> writeDownloadedApkMarker(
    Directory directory,
    AvailableUpdate update,
    File apkFile,
  ) async {
    final markerFile = _downloadMarkerFile(directory);
    final marker = <String, Object?>{
      'versionName': update.manifest.versionName,
      'versionCode': update.effectiveVersionCode,
      'abi': update.asset.abi,
      'sha256': update.asset.sha256.trim().toLowerCase(),
      'fileName': _fileName(apkFile),
    };
    await markerFile.writeAsString(jsonEncode(marker), flush: true);
  }

  static List<Uri> candidateDownloadUris(
    AvailableUpdate update, {
    List<String> githubMirrorPrefixes =
        UpdateMirrorUrls.defaultGithubMirrorPrefixes,
  }) {
    return UpdateMirrorUrls.withGithubMirrors(
      update.asset.url,
      extraMirrors: update.asset.mirrorUrls,
      githubMirrorPrefixes: githubMirrorPrefixes,
    );
  }

  static Future<void> _writeResponseToFile(
    UpdateHttpResponse response,
    File file,
    UpdateDownloadProgress? onProgress,
  ) async {
    final total = response.contentLength != null && response.contentLength! > 0
        ? response.contentLength
        : null;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.bytes) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
  }

  static Future<bool> verifySha256(File file, String expectedSha256) async {
    final normalized = expectedSha256.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return const HexEncoder().convert(digest.bytes) == normalized;
  }

  static Future<File?> _findReusableDownloadedApk(
    Directory directory,
    File targetFile,
    AvailableUpdate update,
  ) async {
    final markerFile = _downloadMarkerFile(directory);
    if (!await markerFile.exists() || !await targetFile.exists()) {
      return null;
    }

    final marker = await _readDownloadedApkMarker(markerFile);
    if (!_markerMatchesUpdate(marker, update, targetFile)) {
      return null;
    }

    final verified = await verifySha256(targetFile, update.asset.sha256);
    return verified ? targetFile : null;
  }

  static Future<Map<String, Object?>?> _readDownloadedApkMarker(
    File markerFile,
  ) async {
    try {
      final decoded = jsonDecode(await markerFile.readAsString());
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (error) {
      debugPrint(
        '[UpdateDownloadService] Failed to read downloaded APK marker: $error',
      );
    }
    return null;
  }

  static bool _markerMatchesUpdate(
    Map<String, Object?>? marker,
    AvailableUpdate update,
    File targetFile,
  ) {
    if (marker == null) {
      return false;
    }
    return marker['versionName'] == update.manifest.versionName &&
        marker['versionCode'] == update.effectiveVersionCode &&
        marker['abi'] == update.asset.abi &&
        marker['sha256'] == update.asset.sha256.trim().toLowerCase() &&
        marker['fileName'] == _fileName(targetFile);
  }

  static File _downloadMarkerFile(Directory directory) {
    return File(
      '${directory.path}${Platform.pathSeparator}$_downloadMarkerFileName',
    );
  }

  static Future<void> _deleteDownloadedApkMarker(Directory directory) async {
    final markerFile = _downloadMarkerFile(directory);
    if (!await markerFile.exists()) {
      return;
    }
    try {
      await markerFile.delete();
    } catch (error) {
      debugPrint(
        '[UpdateDownloadService] Failed to delete downloaded APK marker: '
        '$error',
      );
    }
  }

  static String _fileName(File file) {
    return file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
  }

  static String _sanitizeFilePart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9._+-]+'), '_');
  }
}

class HexEncoder extends Converter<List<int>, String> {
  const HexEncoder();

  static const List<String> _digits = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
  ];

  @override
  String convert(List<int> input) {
    final buffer = StringBuffer();
    for (final byte in input) {
      buffer
        ..write(_digits[(byte >> 4) & 0x0f])
        ..write(_digits[byte & 0x0f]);
    }
    return buffer.toString();
  }
}
