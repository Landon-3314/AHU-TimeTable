import 'package:sound_mode/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

enum DeviceAudioMode { normal, vibrate }

class AudioModeService {
  Future<bool> canControlAudioMode() async {
    return await PermissionHandler.permissionsGranted ?? false;
  }

  Future<void> muteDevice() async {
    await executeMute();
  }

  Future<void> muteDeviceSafely() async {
    await executeMute();
  }

  Future<void> executeMute() async {
    try {
      final isGranted = await _isPermissionGranted();
      if (!isGranted) {
        return;
      }

      final currentMode = await SoundMode.ringerModeStatus;
      if (currentMode != RingerModeStatus.vibrate &&
          currentMode != RingerModeStatus.silent) {
        await SoundMode.setSoundMode(RingerModeStatus.vibrate);
      }
    } catch (error) {
      debugPrint('Mute execution failed: $error');
    }
  }

  Future<void> restoreDeviceAudio() async {
    await _apply(DeviceAudioMode.normal);
  }

  Future<void> applyMode(DeviceAudioMode mode) async {
    await _apply(mode);
  }

  Future<void> _apply(DeviceAudioMode mode) async {
    final target = mode == DeviceAudioMode.vibrate
        ? RingerModeStatus.vibrate
        : RingerModeStatus.normal;
    await SoundMode.setSoundMode(target);
  }

  Future<bool> _isPermissionGranted() async {
    try {
      final dynamic soundModeDynamic = SoundMode;
      final granted = await soundModeDynamic.isPermissionGranted;
      if (granted is bool) {
        return granted;
      }
    } catch (_) {}
    return await canControlAudioMode();
  }
}
