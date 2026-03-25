import 'dart:io';

import 'auto_mute_service.dart';

class AutoMuteToggleService {
  AutoMuteToggleService({AutoMuteService? autoMuteService})
    : _autoMuteService = autoMuteService ?? AutoMuteService.instance;

  final AutoMuteService _autoMuteService;

  Future<bool> ensureCanEnableAutoMute() async {
    if (!Platform.isAndroid) {
      return true;
    }

    var hasPermission = await _autoMuteService.hasPermission();
    if (!hasPermission) {
      await _autoMuteService.openPermissionSettings();
      hasPermission = await _autoMuteService.hasPermission();
    }

    return hasPermission;
  }
}
