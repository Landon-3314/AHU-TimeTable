import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../core/app_routes.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings/background_service_settings_section.dart';
import '../widgets/settings/class_auto_mute_switch.dart';
import '../widgets/settings/reminder_settings_section.dart';
import '../widgets/settings/settings_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final dateFormat = DateFormat('yyyy/MM/dd');

    return SafeArea(
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(
            provider.t('settings'),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SettingsSectionTitle(title: provider.t('basic_settings')),
          const SizedBox(height: AppSpacing.md),
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
                  await Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.scheduleSettings);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          BackgroundServiceSettingsSection(
            provider: provider,
            onServiceToggle: (value) async {
              final result = await provider.toggleBackgroundService(value);
              if (!context.mounted || result.success) {
                return;
              }
              _showError(context, result.message ?? '操作失败');
            },
            onOpenBatteryOptimization: () =>
                provider.openBatteryOptimizationSettings(),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          ReminderSettingsSection(
            provider: provider,
            reminderLabelBuilder: (minutes, {isEventReminder = false}) =>
                _reminderLabel(
                  provider,
                  minutes: minutes,
                  isEventReminder: isEventReminder,
                ),
            onPickCourseReminder: () => _pickReminderAdvance(context, provider),
            onPickEventReminder: () =>
                _pickEventReminderAdvance(context, provider),
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsSectionCard(
            children: [
              ClassAutoMuteSwitch(
                provider: provider,
                onChanged: (value) async {
                  final result = await provider.toggleAutoMuteWithCheck(value);
                  if (!context.mounted || result.success) {
                    return;
                  }
                  _showError(context, result.message ?? '操作失败');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          SettingsSectionTitle(title: provider.t('data_storage')),
          const SizedBox(height: AppSpacing.md),
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
      final result = await provider.updateReminderAdvanceMinutes(selectedValue);
      if (!context.mounted || result.success) {
        return;
      }
      _showError(context, result.message ?? '操作失败');
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
      final result = await provider.updateEventReminderAdvanceMinutes(
        selectedValue,
      );
      if (!context.mounted || result.success) {
        return;
      }
      _showError(context, result.message ?? '操作失败');
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

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
  }
}
