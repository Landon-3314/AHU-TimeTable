import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings/settings_section.dart';
import 'schedule_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final dateFormat = DateFormat('yyyy/MM/dd');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            provider.t('settings'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          SettingsSectionTitle(title: provider.t('basic_settings')),
          const SizedBox(height: 10),
          SettingsSectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(provider.t('language')),
                trailing: DropdownButton<String>(
                  value: provider.languageCode,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(
                      value: 'zh',
                      child: Text(provider.t('chinese')),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(provider.t('english')),
                    ),
                  ],
                  onChanged: (newValue) {
                    if (newValue != null) {
                      provider.changeLanguage(newValue);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(provider.t('semester_start_date')),
                subtitle: Text(dateFormat.format(provider.semesterStartDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickSemesterStartDate(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.view_week_outlined),
                title: Text(provider.t('semester_total_weeks')),
                subtitle: Text(
                  '${provider.totalWeeks} ${provider.t('weeks_suffix')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickTotalWeeks(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(provider.t('schedule_time_settings')),
                subtitle: Text(provider.t('schedule_time_settings_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScheduleSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSectionTitle(title: provider.t('notifications')),
          const SizedBox(height: 10),
          SettingsSectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(provider.t('course_reminder_time')),
                subtitle: Text(
                  _reminderLabel(
                    provider,
                    minutes: provider.reminderAdvanceMinutes,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickReminderAdvance(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(provider.t('event_reminder_time')),
                subtitle: Text(
                  _reminderLabel(
                    provider,
                    minutes: provider.eventReminderAdvanceMinutes,
                    isEventReminder: true,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickEventReminderAdvance(context, provider),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.phone_android_outlined),
                title: Text(provider.t('auto_mute')),
                subtitle: Text(provider.t('auto_mute_subtitle')),
                value: provider.autoMuteEnabled,
                onChanged: (value) async {
                  final success = await provider.toggleAutoMuteWithCheck(value);
                  if (!context.mounted) {
                    return;
                  }
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.languageCode == 'en'
                              ? 'Failed to enable. Please grant DND permission.'
                              : 'Failed to enable. Please grant DND permission.',
                        ),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.battery_alert_outlined),
                title: Text(
                  provider.languageCode == 'en'
                      ? 'Battery Optimization'
                      : '\u7535\u6c60\u4f18\u5316\u8bbe\u7f6e',
                ),
                subtitle: Text(
                  provider.languageCode == 'en'
                      ? 'Allow foreground service to stay alive in background'
                      : '\u5f15\u5bfc\u7cfb\u7edf\u5141\u8bb8\u8bfe\u8868\u524d\u53f0\u670d\u52a1\u540e\u53f0\u5e38\u9a7b',
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () async {
                  await AppSettings.openAppSettings(
                    type: AppSettingsType.batteryOptimization,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsSectionTitle(title: provider.t('data_storage')),
          const SizedBox(height: 10),
          SettingsSectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.cookie_outlined),
                title: Text(provider.t('clear_browser_cache')),
                subtitle: Text(provider.t('clear_browser_cache_subtitle')),
                onTap: () async {
                  await WebViewCookieManager().clearCookies();
                  if (!context.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.t('cache_cleared'))),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: Text(provider.t('clear_all_local_data')),
                subtitle: Text(provider.t('clear_all_local_data_subtitle')),
                onTap: () => _confirmClearAllData(context, provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickSemesterStartDate(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.semesterStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      selectableDayPredicate: (date) => date.weekday == DateTime.monday,
    );

    if (picked != null) {
      await provider.updateSemesterStartDate(picked);
    }
  }

  Future<void> _pickTotalWeeks(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selectedValue = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (int week = 15; week <= 30; week++)
                ListTile(
                  title: Text('$week ${provider.t('weeks_suffix')}'),
                  trailing: provider.totalWeeks == week
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(week);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (selectedValue != null) {
      await provider.updateTotalWeeks(selectedValue);
    }
  }

  Future<void> _pickReminderAdvance(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selectedValue = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final options = <int>[0, 5, 10, 15, 30];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final minutes in options)
                ListTile(
                  title: Text(_reminderLabel(provider, minutes: minutes)),
                  trailing: provider.reminderAdvanceMinutes == minutes
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(minutes);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (selectedValue != null) {
      await provider.updateReminderAdvanceMinutes(selectedValue);
    }
  }

  Future<void> _pickEventReminderAdvance(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selectedValue = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final options = <int>[0, 15, 30, 60, 120, 1440];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final minutes in options)
                ListTile(
                  title: Text(
                    _reminderLabel(
                      provider,
                      minutes: minutes,
                      isEventReminder: true,
                    ),
                  ),
                  trailing: provider.eventReminderAdvanceMinutes == minutes
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(minutes);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (selectedValue != null) {
      await provider.updateEventReminderAdvanceMinutes(selectedValue);
    }
  }

  Future<void> _confirmClearAllData(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(provider.t('confirm_clear')),
          content: Text(provider.t('confirm_clear_message')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(provider.t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(provider.t('confirm')),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !context.mounted) {
      return;
    }

    await context.read<CourseProvider>().clearAllData();

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(provider.t('all_local_data_cleared'))),
    );
  }

  String _reminderLabel(
    SettingsProvider provider, {
    int? minutes,
    bool isEventReminder = false,
  }) {
    final value =
        minutes ??
        (isEventReminder
            ? provider.eventReminderAdvanceMinutes
            : provider.reminderAdvanceMinutes);
    if (value == 0) {
      return provider.t('no_reminder');
    }
    if (value == 60) {
      return provider.t('one_hour');
    }
    if (value == 120) {
      return provider.t('two_hours');
    }
    if (value == 1440) {
      return provider.t('one_day');
    }
    return '${provider.t('advance_prefix')} $value ${provider.t('minutes_suffix')}';
  }
}
