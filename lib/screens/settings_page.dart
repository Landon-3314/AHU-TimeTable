import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/auto_mute_service.dart';
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: provider.t('basic_settings')),
          const SizedBox(height: 10),
          _SettingsCard(
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
          _SectionTitle(title: provider.t('notifications')),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(provider.t('reminder_time')),
                subtitle: Text(_reminderLabel(provider)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickReminderAdvance(context, provider),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.phone_android_outlined),
                title: Text(provider.t('auto_mute')),
                subtitle: Text(provider.t('auto_mute_subtitle')),
                value: provider.autoMuteEnabled,
                onChanged: (value) => _toggleAutoMute(
                  context,
                  provider,
                  value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: provider.t('data_storage')),
          const SizedBox(height: 10),
          _SettingsCard(
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
                    SnackBar(
                      content: Text(provider.t('cache_cleared')),
                    ),
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
                  trailing:
                      provider.totalWeeks == week ? const Icon(Icons.check) : null,
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

  Future<void> _toggleAutoMute(
    BuildContext context,
    SettingsProvider provider,
    bool value,
  ) async {
    if (!value) {
      await provider.updateAutoMuteEnabled(false);
      return;
    }

    if (!Platform.isAndroid) {
      await provider.updateAutoMuteEnabled(true);
      return;
    }

    var hasPermission = await AutoMuteService.instance.hasPermission();
    if (!hasPermission) {
      await AutoMuteService.instance.openPermissionSettings();
      hasPermission = await AutoMuteService.instance.hasPermission();
    }

    if (!hasPermission) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.t('auto_mute_permission_required')),
        ),
      );
      return;
    }

    await provider.updateAutoMuteEnabled(true);
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
      SnackBar(
        content: Text(provider.t('all_local_data_cleared')),
      ),
    );
  }

  String _reminderLabel(
    SettingsProvider provider, {
    int? minutes,
  }) {
    final value = minutes ?? provider.reminderAdvanceMinutes;
    if (value == 0) {
      return provider.t('no_reminder');
    }
    return '${provider.t('advance_prefix')} $value ${provider.t('minutes_suffix')}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}
