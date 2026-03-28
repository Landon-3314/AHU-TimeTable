import 'package:flutter/material.dart';

import '../../providers/settings_provider.dart';
import 'settings_section.dart';

class BackgroundServiceSettingsSection extends StatelessWidget {
  const BackgroundServiceSettingsSection({
    super.key,
    required this.provider,
    required this.onForegroundServiceChanged,
    required this.onOpenBatteryOptimization,
  });

  final SettingsProvider provider;
  final Future<void> Function(bool value) onForegroundServiceChanged;
  final VoidCallback onOpenBatteryOptimization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionTitle(title: '基础模块'),
        const SizedBox(height: 12),
        SettingsSectionCard(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.run_circle_outlined),
              title: const Text('常驻前台服务'),
              subtitle: const Text('仅用于维持通知权限与系统可见性'),
              value: provider.backgroundServiceEnabled,
              onChanged: onForegroundServiceChanged,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.battery_saver_outlined),
              title: const Text('电池优化设置'),
              subtitle: const Text('建议关闭该应用电池优化以减少系统拦截'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenBatteryOptimization,
            ),
          ],
        ),
      ],
    );
  }
}
