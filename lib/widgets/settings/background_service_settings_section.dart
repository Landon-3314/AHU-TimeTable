import 'package:flutter/material.dart';

import '../../providers/settings_provider.dart';
import 'settings_section.dart';

class BackgroundServiceSettingsSection extends StatelessWidget {
  const BackgroundServiceSettingsSection({
    super.key,
    required this.provider,
    required this.onServiceToggle,
    required this.onOpenBatteryOptimization,
  });

  final SettingsProvider provider;
  final Future<void> Function(bool value) onServiceToggle;
  final Future<void> Function() onOpenBatteryOptimization;

  @override
  Widget build(BuildContext context) {
    final isEnglish = provider.languageCode == 'en';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(
          title: isEnglish ? 'Background Service' : '后台自动服务',
        ),
        const SizedBox(height: 12),
        SettingsSectionCard(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.memory_outlined),
              title: Text(isEnglish ? 'Foreground Service' : '常驻前台服务'),
              subtitle: Text(
                isEnglish
                    ? 'Keep timetable runtime active in background'
                    : '保持课表后台运行环境可用',
              ),
              value: provider.backgroundServiceEnabled,
              onChanged: onServiceToggle,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: Text(
                isEnglish ? 'Battery Optimization' : '电池优化设置',
              ),
              subtitle: Text(
                isEnglish
                    ? 'Allow service to stay alive under system restrictions'
                    : '引导系统允许课表服务后台常驻',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: onOpenBatteryOptimization,
            ),
          ],
        ),
      ],
    );
  }
}

