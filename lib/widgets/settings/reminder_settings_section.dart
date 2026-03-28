import 'package:flutter/material.dart';

import '../../providers/settings_provider.dart';
import 'settings_section.dart';

class ReminderSettingsSection extends StatelessWidget {
  const ReminderSettingsSection({
    super.key,
    required this.provider,
    required this.reminderLabelBuilder,
    required this.onToggleCourseReminder,
    required this.onPickCourseReminder,
    required this.onPickEventReminder,
  });

  final SettingsProvider provider;
  final String Function(int minutes, {bool isEventReminder}) reminderLabelBuilder;
  final Future<void> Function(bool value) onToggleCourseReminder;
  final Future<void> Function() onPickCourseReminder;
  final Future<void> Function() onPickEventReminder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionTitle(title: '业务模块'),
        const SizedBox(height: 12),
        SettingsSectionCard(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('课前提醒'),
              subtitle: Text(
                provider.courseReminderEnabled
                    ? reminderLabelBuilder(provider.reminderAdvanceMinutes)
                    : '未开启',
              ),
              value: provider.courseReminderEnabled,
              onChanged: onToggleCourseReminder,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('课前提醒提前时间'),
              subtitle: Text(reminderLabelBuilder(provider.reminderAdvanceMinutes)),
              trailing: const Icon(Icons.chevron_right),
              enabled: provider.courseReminderEnabled,
              onTap: provider.courseReminderEnabled ? onPickCourseReminder : null,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.event_note_outlined),
              title: Text(provider.t('event_reminder_time')),
              subtitle: Text(
                reminderLabelBuilder(
                  provider.eventReminderAdvanceMinutes,
                  isEventReminder: true,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPickEventReminder,
            ),
          ],
        ),
      ],
    );
  }
}
