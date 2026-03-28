import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/native_alarm_service.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  bool _isAutoMuteEnabled = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SettingsProvider>();
    _isAutoMuteEnabled =
        provider.backgroundServiceEnabled && provider.autoMuteEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    final courseOffsetOptions = <int>[5, 10, 15];
    final eventOffsetOptions = <int>[5, 10, 15, 30];
    final courseOffsetValue = courseOffsetOptions.contains(
      provider.reminderAdvanceMinutes,
    )
        ? provider.reminderAdvanceMinutes
        : 10;
    final eventOffsetValue = eventOffsetOptions.contains(
      provider.eventReminderAdvanceMinutes,
    )
        ? provider.eventReminderAdvanceMinutes
        : 10;

    return Scaffold(
      appBar: AppBar(title: const Text('上课静音与提醒')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.volume_off_outlined),
              title: const Text('上课自动静音（常驻服务）'),
              subtitle: const Text('开启后将由后台服务持续判断上课状态并自动静音'),
              value: _isAutoMuteEnabled,
              onChanged: _toggleAutoMute,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: const Text('开启课前提醒'),
                  subtitle: Text(
                    provider.courseReminderEnabled
                        ? '已开启，提前 ${provider.reminderAdvanceMinutes} 分钟提醒'
                        : '关闭',
                  ),
                  value: provider.courseReminderEnabled,
                  onChanged: (value) =>
                      _onCourseReminderChanged(context, provider, value),
                ),
                if (provider.courseReminderEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('提前提醒时间'),
                    subtitle: Text('当前：提前 ${provider.reminderAdvanceMinutes} 分钟'),
                    trailing: DropdownButton<int>(
                      value: courseOffsetValue,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('提前 5 分钟')),
                        DropdownMenuItem(value: 10, child: Text('提前 10 分钟')),
                        DropdownMenuItem(value: 15, child: Text('提前 15 分钟')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _onCourseReminderOffsetChanged(context, provider, value);
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
                  title: const Text('日程提醒开关'),
                  subtitle: Text(
                    provider.eventReminderAdvanceMinutes > 0
                        ? '已开启，提前 ${provider.eventReminderAdvanceMinutes} 分钟提醒'
                        : '关闭',
                  ),
                  value: provider.eventReminderAdvanceMinutes > 0,
                  onChanged: (value) => _onEventReminderChanged(context, provider, value),
                ),
                if (provider.eventReminderAdvanceMinutes > 0) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.schedule_send_outlined),
                    title: const Text('日程提前提醒时间'),
                    subtitle: Text('当前：提前 ${provider.eventReminderAdvanceMinutes} 分钟'),
                    trailing: DropdownButton<int>(
                      value: eventOffsetValue,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('提前 5 分钟')),
                        DropdownMenuItem(value: 10, child: Text('提前 10 分钟')),
                        DropdownMenuItem(value: 15, child: Text('提前 15 分钟')),
                        DropdownMenuItem(value: 30, child: Text('提前 30 分钟')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _onEventReminderOffsetChanged(context, provider, value);
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

  Future<void> _toggleAutoMute(bool value) async {
    final provider = context.read<SettingsProvider>();
    if (!value) {
      try {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (isRunning) {
          service.invoke('stopService');
        }
        await provider.setAutoMuteServiceEnabled(false);
        if (mounted) {
          setState(() {
            _isAutoMuteEnabled = false;
          });
        }
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('关闭后台服务失败：$e')),
        );
      }
      return;
    }

    final notificationStatus = await Permission.notification.request();
    final dndStatus = await Permission.accessNotificationPolicy.request();

    if (!notificationStatus.isGranted || !dndStatus.isGranted) {
      if (mounted) {
        setState(() {
          _isAutoMuteEnabled = false;
        });
      }
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('需要系统权限'),
            content: const Text('请授予通知权限与勿扰权限后再开启自动静音。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await openAppSettings();
                },
                child: const Text('去设置'),
              ),
            ],
          );
        },
      );
      return;
    }

    try {
      final exactAlarmOk = await NativeAlarmService.instance.ensureExactAlarmPermission();
      final batteryOk = await NativeAlarmService.instance.ensureIgnoreBatteryOptimizations();
      if (!exactAlarmOk || !batteryOk) {
        if (mounted) {
          setState(() {
            _isAutoMuteEnabled = false;
          });
        }
        return;
      }

      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      if (!isRunning) {
        await service.startService();
      }
      await provider.setAutoMuteServiceEnabled(true);
      if (mounted) {
        setState(() {
          _isAutoMuteEnabled = true;
        });
      }
      await _refreshNativeAlarms(context, provider);
    } catch (e) {
      await provider.setAutoMuteServiceEnabled(false);
      if (mounted) {
        setState(() {
          _isAutoMuteEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动后台服务失败：$e')),
        );
      }
    }
  }

  Future<void> _onCourseReminderChanged(
    BuildContext context,
    SettingsProvider provider,
    bool value,
  ) async {
    final result = await provider.toggleCourseReminder(value);
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开启课前提醒失败，请先完成权限授权')),
      );
      return;
    }
    await _refreshNativeAlarms(context, provider);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新课前提醒时间失败，请检查权限')),
      );
      return;
    }
    await _refreshNativeAlarms(context, provider);
  }

  Future<void> _onEventReminderChanged(
    BuildContext context,
    SettingsProvider provider,
    bool value,
  ) async {
    final result = await provider.updateEventReminderAdvanceMinutes(
      value ? 10 : 0,
    );
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开启日程提醒失败，请先完成权限授权')),
      );
      return;
    }
    await _refreshNativeAlarms(context, provider);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新日程提醒时间失败，请检查权限')),
      );
      return;
    }
    await _refreshNativeAlarms(context, provider);
  }

  Future<void> _refreshNativeAlarms(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final courseProvider = context.read<CourseProvider>();
    await NativeAlarmService.instance.scheduleClasses(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      settings: provider,
    );
  }
}
