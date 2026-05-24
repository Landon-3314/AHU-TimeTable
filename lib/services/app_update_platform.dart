import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUpdatePlatform {
  const AppUpdatePlatform({MethodChannel channel = _defaultChannel})
    : _channel = channel;

  static const MethodChannel _defaultChannel = MethodChannel('app.updater');

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<int> currentVersionCode() async {
    try {
      final result = await _channel.invokeMethod<int>('getVersionCode');
      return result ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }

  Future<List<String>> supportedAbis() async {
    try {
      final result = await _channel.invokeListMethod<String>(
        'getSupportedAbis',
      );
      if (result != null && result.isNotEmpty) {
        return result;
      }
    } on MissingPluginException {
      return const [];
    }
    return const [];
  }

  Future<Directory?> downloadDirectory() async {
    try {
      final path = await _channel.invokeMethod<String>('getDownloadDirectory');
      if (path == null || path.isEmpty) {
        return null;
      }
      return Directory(path);
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> installApk(File apkFile) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        <String, Object?>{'path': apkFile.path},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> cleanupDownloadedApks() async {
    try {
      await _channel.invokeMethod<void>('cleanupDownloadedApks');
    } on MissingPluginException {
      return;
    }
  }
}
