import 'package:flutter/material.dart';

import '../../providers/settings_provider.dart';
import 'settings_section.dart';

class ReminderSettingsSection extends StatelessWidget {
  const ReminderSettingsSection({
    super.key,
    required this.provider,
    required this.reminderLabelBuilder,
    required this.onPickCourseReminder,
    required this.onPickEventReminder,
  });

  final SettingsProvider provider;
  final String Function(int minutes, {bool isEventReminder}) reminderLabelBuilder;
  final Future<void> Function() onPickCourseReminder;
  final Future<void> Function() onPickEventReminder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionTitle(title: provider.t('notifications')),
        const SizedBox(height: 12),
        SettingsSectionCard(
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(provider.t('course_reminder_time')),
              subtitle: Text(
                reminderLabelBuilder(provider.reminderAdvanceMinutes),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onPickCourseReminder,
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

