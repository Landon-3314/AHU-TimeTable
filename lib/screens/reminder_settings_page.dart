import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/native_alarm_service.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    final courseOffsetOptions = <int>[5, 10, 15];
    final eventOffsetOptions = <int>[5, 10, 15, 30];
    final courseOffsetValue =
        courseOffsetOptions.contains(provider.reminderAdvanceMinutes)
        ? provider.reminderAdvanceMinutes
        : 10;
    final eventOffsetValue =
        eventOffsetOptions.contains(provider.eventReminderAdvanceMinutes)
        ? provider.eventReminderAdvanceMinutes
        : 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u4e0a\u8bfe\u9759\u97f3\u4e0e\u63d0\u9192'),
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.shield_outlined),
              title: const Text('\u524d\u53f0\u4fdd\u6d3b\u670d\u52a1'),
              subtitle: const Text(
                '\u7528\u4e8e\u964d\u4f4e\u606f\u5c4f\u6216\u7cfb\u7edf\u9650\u5236\u5bf9\u63d0\u9192\u4e0e\u9759\u97f3\u89e6\u53d1\u7684\u5f71\u54cd',
              ),
              value: provider.backgroundServiceEnabled,
              onChanged: (value) =>
                  _onForegroundServiceToggled(provider, value),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.volume_off_outlined),
              title: const Text('\u4e0a\u8bfe\u81ea\u52a8\u9759\u97f3'),
              subtitle: const Text(
                '\u4ec5\u5728\u9700\u8981\u7684\u8bfe\u7a0b\u65f6\u95f4\u5185\u6267\u884c\u81ea\u52a8\u9759\u97f3\u4e0e\u6062\u590d',
              ),
              value: provider.autoMuteEnabled,
              onChanged: (value) => _onAutoMuteToggled(provider, value),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('\u5f00\u542f\u8bfe\u524d\u63d0\u9192'),
                  subtitle: Text(
                    provider.courseReminderEnabled
                        ? '\u5df2\u5f00\u542f\uff0c\u63d0\u524d ${provider.reminderAdvanceMinutes} \u5206\u949f\u63d0\u9192'
                        : '\u5173\u95ed',
                  ),
                  value: provider.courseReminderEnabled,
                  onChanged: (value) =>
                      _onCourseReminderChanged(context, provider, value),
                ),
                if (provider.courseReminderEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('\u63d0\u524d\u63d0\u9192\u65f6\u95f4'),
                    subtitle: Text(
                      '\u5f53\u524d\uff1a\u63d0\u524d ${provider.reminderAdvanceMinutes} \u5206\u949f',
                    ),
                    trailing: DropdownButton<int>(
                      value: courseOffsetValue,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 5,
                          child: Text('\u63d0\u524d 5 \u5206\u949f'),
                        ),
                        DropdownMenuItem(
                          value: 10,
                          child: Text('\u63d0\u524d 10 \u5206\u949f'),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text('\u63d0\u524d 15 \u5206\u949f'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _onCourseReminderOffsetChanged(
                            context,
                            provider,
                            value,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.event_note_outlined),
                  title: const Text('\u65e5\u7a0b\u63d0\u9192\u5f00\u5173'),
                  subtitle: Text(
                    provider.eventReminderAdvanceMinutes > 0
                        ? '\u5df2\u5f00\u542f\uff0c\u63d0\u524d ${provider.eventReminderAdvanceMinutes} \u5206\u949f\u63d0\u9192'
                        : '\u5173\u95ed',
                  ),
                  value: provider.eventReminderAdvanceMinutes > 0,
                  onChanged: (value) =>
                      _onEventReminderChanged(context, provider, value),
                ),
                if (provider.eventReminderAdvanceMinutes > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_send_outlined),
                    title: const Text(
                      '\u65e5\u7a0b\u63d0\u524d\u63d0\u9192\u65f6\u95f4',
                    ),
                    subtitle: Text(
                      '\u5f53\u524d\uff1a\u63d0\u524d ${provider.eventReminderAdvanceMinutes} \u5206\u949f',
                    ),
                    trailing: DropdownButton<int>(
                      value: eventOffsetValue,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 5,
                          child: Text('\u63d0\u524d 5 \u5206\u949f'),
                        ),
                        DropdownMenuItem(
                          value: 10,
                          child: Text('\u63d0\u524d 10 \u5206\u949f'),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text('\u63d0\u524d 15 \u5206\u949f'),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text('\u63d0\u524d 30 \u5206\u949f'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _onEventReminderOffsetChanged(
                            context,
                            provider,
                            value,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensureNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }

  Future<bool> _ensureDndPermission() async {
    var status = await Permission.accessNotificationPolicy.status;
    if (!status.isGranted) {
      status = await Permission.accessNotificationPolicy.request();
    }
    return status.isGranted;
  }

  Future<bool> _ensureExactAlarmPermission() async {
    return NativeAlarmService.instance.ensureExactAlarmPermission();
  }

  Future<void> _onForegroundServiceToggled(
    SettingsProvider provider,
    bool value,
  ) async {
    if (value) {
      final notifOk = await _ensureNotificationPermission();
      if (!notifOk) {
        _showSnackBar(
          '\u8bf7\u5148\u6388\u4e88\u901a\u77e5\u6743\u9650\u518d\u5f00\u542f\u4fdd\u6d3b\u670d\u52a1',
        );
        return;
      }

      await NativeAlarmService.instance.requestIgnoreBatteryOptimization();

      try {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          await service.startService();
        }

        final result = await provider.toggleBackgroundServiceWithCheck(true);
        if (!result.success) {
          _showSnackBar(
            '\u5f00\u542f\u4fdd\u6d3b\u670d\u52a1\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u901a\u77e5\u6743\u9650',
          );
          return;
        }
        await _refreshSchedules(provider);
      } catch (e) {
        _showSnackBar(
          '\u542f\u52a8\u524d\u53f0\u4fdd\u6d3b\u670d\u52a1\u5931\u8d25\uff1a$e',
        );
      }
      return;
    }

    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (isRunning) {
        service.invoke('stop_service');
      }

      await provider.toggleBackgroundServiceWithCheck(false);
      await _refreshSchedules(provider);
    } catch (e) {
      _showSnackBar(
        '\u5173\u95ed\u524d\u53f0\u4fdd\u6d3b\u670d\u52a1\u5931\u8d25\uff1a$e',
      );
    }
  }

  Future<void> _onAutoMuteToggled(SettingsProvider provider, bool value) async {
    if (!value) {
      await provider.toggleAutoMuteWithCheck(false);
      await _refreshSchedules(provider);
      return;
    }

    final notifOk = await _ensureNotificationPermission();
    if (!notifOk) {
      _showSnackBar(
        '\u8bf7\u5148\u6388\u4e88\u901a\u77e5\u6743\u9650\u518d\u5f00\u542f\u81ea\u52a8\u9759\u97f3',
      );
      return;
    }

    final alarmOk = await _ensureExactAlarmPermission();
    if (!alarmOk) {
      _showSnackBar(
        '\u8bf7\u5148\u6388\u4e88\u7cbe\u786e\u95f9\u949f\u6743\u9650',
      );
      return;
    }

    final dndOk = await _ensureDndPermission();
    if (!dndOk) {
      _showSnackBar(
        '\u8bf7\u5148\u6388\u4e88\u52ff\u6270\u6743\u9650\u518d\u5f00\u542f\u81ea\u52a8\u9759\u97f3',
      );
      return;
    }

    await _offerForegroundServiceEnableIfNeeded(provider);

    final result = await provider.toggleAutoMuteWithCheck(true);
    if (!result.success) {
      _showSnackBar(
        '\u5f00\u542f\u4e0a\u8bfe\u81ea\u52a8\u9759\u97f3\u5931\u8d25',
      );
      return;
    }

    await _refreshSchedules(provider);
  }

  Future<void> _onCourseReminderChanged(
    BuildContext context,
    SettingsProvider provider,
    bool value,
  ) async {
    if (value) {
      final notifOk = await _ensureNotificationPermission();
      if (!notifOk) {
        _showSnackBar(
          '\u8bf7\u5148\u6388\u4e88\u901a\u77e5\u6743\u9650\u518d\u5f00\u542f\u8bfe\u524d\u63d0\u9192',
        );
        return;
      }
      final alarmOk = await _ensureExactAlarmPermission();
      if (!alarmOk) {
        _showSnackBar(
          '\u8bf7\u5148\u6388\u4e88\u7cbe\u786e\u95f9\u949f\u6743\u9650',
        );
        return;
      }
      await _offerForegroundServiceEnableIfNeeded(provider);
    }

    final result = await provider.toggleCourseReminder(value);
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar(
        '\u5f00\u542f\u8bfe\u524d\u63d0\u9192\u5931\u8d25\uff0c\u8bf7\u5148\u5b8c\u6210\u6743\u9650\u6388\u6743',
      );
      return;
    }
    await _refreshSchedules(provider);
  }

  Future<void> _onCourseReminderOffsetChanged(
    BuildContext context,
    SettingsProvider provider,
    int minutes,
  ) async {
    final result = await provider.updateReminderAdvanceMinutes(minutes);
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar(
        '\u66f4\u65b0\u8bfe\u524d\u63d0\u9192\u65f6\u95f4\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u6743\u9650',
      );
      return;
    }
    await _refreshSchedules(provider);
  }

  Future<void> _onEventReminderChanged(
    BuildContext context,
    SettingsProvider provider,
    bool value,
  ) async {
    if (value) {
      final notifOk = await _ensureNotificationPermission();
      if (!notifOk) {
        _showSnackBar(
          '\u8bf7\u5148\u6388\u4e88\u901a\u77e5\u6743\u9650\u518d\u5f00\u542f\u65e5\u7a0b\u63d0\u9192',
        );
        return;
      }
      final alarmOk = await _ensureExactAlarmPermission();
      if (!alarmOk) {
        _showSnackBar(
          '\u8bf7\u5148\u6388\u4e88\u7cbe\u786e\u95f9\u949f\u6743\u9650',
        );
        return;
      }
      await _offerForegroundServiceEnableIfNeeded(provider);
    }

    final result = await provider.updateEventReminderAdvanceMinutes(
      value ? 10 : 0,
    );
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar(
        '\u5f00\u542f\u65e5\u7a0b\u63d0\u9192\u5931\u8d25\uff0c\u8bf7\u5148\u5b8c\u6210\u6743\u9650\u6388\u6743',
      );
      return;
    }
    await _refreshSchedules(provider);
  }

  Future<void> _onEventReminderOffsetChanged(
    BuildContext context,
    SettingsProvider provider,
    int minutes,
  ) async {
    final result = await provider.updateEventReminderAdvanceMinutes(minutes);
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar(
        '\u66f4\u65b0\u65e5\u7a0b\u63d0\u9192\u65f6\u95f4\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u6743\u9650',
      );
      return;
    }
    await _refreshSchedules(provider);
  }

  Future<void> _offerForegroundServiceEnableIfNeeded(
    SettingsProvider provider,
  ) async {
    if (provider.backgroundServiceEnabled || !mounted) {
      return;
    }

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('\u5efa\u8bae\u5f00\u542f\u4fdd\u6d3b\u670d\u52a1'),
          content: const Text(
            '\u4e3a\u4e86\u786e\u4fdd\u606f\u5c4f\u72b6\u6001\u4e0b\u63d0\u9192\u548c\u9759\u97f3\u80fd\u51c6\u65f6\u89e6\u53d1\uff0c\u5efa\u8bae\u5f00\u542f\u524d\u53f0\u4fdd\u6d3b\u670d\u52a1\u4ee5\u9632\u6b62\u7cfb\u7edf\u6740\u540e\u53f0\u3002',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\u6682\u4e0d\u5f00\u542f'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('\u53bb\u5f00\u542f'),
            ),
          ],
        );
      },
    );

    if (shouldEnable == true) {
      await _onForegroundServiceToggled(provider, true);
    }
  }

  Future<void> _refreshSchedules(SettingsProvider provider) async {
    final courseProvider = context.read<CourseProvider>();
    await AppServices.refreshSchedules(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      settings: provider,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
