import 'dart:io';

import 'package:flutter/services.dart';

class AutoMuteService {
  AutoMuteService._();

  static final AutoMuteService instance = AutoMuteService._();
  static const MethodChannel _channel = MethodChannel('app.auto_mute');

  Future<bool> isSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final value = await _channel.invokeMethod<bool>('isSupported');
    return value ?? false;
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final value = await _channel.invokeMethod<bool>('hasPermission');
    return value ?? false;
  }

  Future<void> openPermissionSettings() async {
    if (!Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod<void>('openPermissionSettings');
  }
}
