import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppStoragePlatform {
  const AppStoragePlatform({MethodChannel channel = _defaultChannel})
    : _channel = channel;

  static const MethodChannel _defaultChannel = MethodChannel('app.storage');

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<Directory?> externalFilesDirectory() async {
    if (!isSupported) {
      return null;
    }

    try {
      final path = await _channel.invokeMethod<String>('getExternalFilesDir');
      if (path == null || path.isEmpty) {
        return null;
      }
      return Directory(path);
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
