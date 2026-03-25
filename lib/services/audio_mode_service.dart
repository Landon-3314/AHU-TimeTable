import 'package:sound_mode/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

enum DeviceAudioMode { normal, vibrate }

class AudioModeService {
  Future<bool> canControlAudioMode() async {
    return await PermissionHandler.permissionsGranted ?? false;
  }

  Future<void> muteDevice() async {
    await _apply(DeviceAudioMode.vibrate);
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
}
