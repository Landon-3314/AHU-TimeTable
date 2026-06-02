import 'package:flutter/material.dart';

import '../../providers/settings_provider.dart';

class ClassAutoMuteSwitch extends StatelessWidget {
  const ClassAutoMuteSwitch({
    super.key,
    required this.provider,
    required this.onChanged,
  });

  final SettingsProvider provider;
  final Future<void> Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.phone_android_outlined),
      title: Text(provider.t('auto_mute')),
      subtitle: Text(provider.t('auto_mute_subtitle')),
      value: provider.autoMuteEnabled,
      onChanged: onChanged,
    );
  }
}
