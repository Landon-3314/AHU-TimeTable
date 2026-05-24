import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'app_update_platform.dart';
import 'update_check_service.dart';

typedef UpdateDownloadProgress = void Function(int received, int? total);

class UpdateDownloadService {
  const UpdateDownloadService({
    AppUpdatePlatform platform = const AppUpdatePlatform(),
  }) : _platform = platform;

  final AppUpdatePlatform _platform;

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

    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'timetable-${_sanitizeFilePart(update.manifest.versionName)}-'
      '${_sanitizeFilePart(update.asset.abi)}.apk',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(update.asset.url);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('APK download failed', uri: update.asset.url);
      }
      final total = response.contentLength > 0 ? response.contentLength : null;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }

      final verified = await verifySha256(file, update.asset.sha256);
      if (!verified) {
        try {
          await file.delete();
        } catch (_) {}
        throw const FormatException('APK sha256 mismatch');
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> install(File apkFile) {
    return _platform.installApk(apkFile);
  }

  static Future<bool> verifySha256(File file, String expectedSha256) async {
    final normalized = expectedSha256.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      return false;
    }
    final digest = await sha256.bind(file.openRead()).first;
    return const HexEncoder().convert(digest.bytes) == normalized;
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
