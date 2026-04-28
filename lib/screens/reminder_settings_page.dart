import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/native_alarm_service.dart';
import '../widgets/long_screenshot_scroll_capture.dart';
import '../widgets/common/app_ui.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  static const List<int> _reminderOffsetOptions = <int>[
    5,
    10,
    15,
    30,
    60,
    120,
    1440,
  ];

  final ScrollController _scrollController = ScrollController();

  bool get _supportsAndroidAutomation =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    final courseOffsetValue =
        _reminderOffsetOptions.contains(provider.reminderAdvanceMinutes)
        ? provider.reminderAdvanceMinutes
        : 10;
    final eventOffsetValue =
        _reminderOffsetOptions.contains(provider.eventReminderAdvanceMinutes)
        ? provider.eventReminderAdvanceMinutes
        : 10;

    return Scaffold(
      appBar: AppBar(title: const Text('上课静音与提醒')),
      body: LongScreenshotScrollCapture(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: AppSpacing.pagePadding,
          children: [
            if (_supportsAndroidAutomation) ...[
              const AppSectionTitle(
                title: 'Android 自动化',
                subtitle: '这些能力依赖系统权限与后台保活策略',
              ),
              AppSurface(
                child: SwitchListTile(
                  secondary: const Icon(Icons.shield_outlined),
                  title: const Text('前台保活服务'),
                  subtitle: const Text('用于降低息屏或系统限制对提醒与静音触发的影响'),
                  value: provider.backgroundServiceEnabled,
                  onChanged: (value) =>
                      _onForegroundServiceToggled(provider, value),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppSurface(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_off_outlined),
                      title: const Text('上课自动静音'),
                      subtitle: const Text('仅在需要的课程时间内执行自动静音与恢复'),
                      value: provider.autoMuteEnabled,
                      onChanged: (value) => _onAutoMuteToggled(provider, value),
                    ),
                    const Divider(height: 1),
                    AppActionTile(
                      icon: Icons.security_update_warning_outlined,
                      title: '如果静音失效，点此开启后台权限',
                      subtitle: '将尝试打开自启动管理或后台高耗电允许页面',
                      onTap: _openRomPermissionHelp,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            const AppSectionTitle(title: '提醒', subtitle: '管理课程和单次日程的提前提醒'),
            AppSurface(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('开启课前提醒'),
                    subtitle: Text(
                      provider.courseReminderEnabled
                          ? '已开启，提前 ${_formatReminderAdvance(provider.reminderAdvanceMinutes)} 提醒'
                          : '关闭',
                    ),
                    value: provider.courseReminderEnabled,
                    onChanged: (value) =>
                        _onCourseReminderChanged(context, provider, value),
                  ),
                  if (provider.courseReminderEnabled) ...[
                    const Divider(height: 1),
                    AppActionTile(
                      icon: Icons.timer_outlined,
                      title: '提前提醒时间',
                      subtitle:
                          '当前：提前 ${_formatReminderAdvance(provider.reminderAdvanceMinutes)}',
                      trailing: DropdownButton<int>(
                        value: courseOffsetValue,
                        underline: const SizedBox.shrink(),
                        items: _buildReminderOffsetMenuItems(),
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
            const SizedBox(height: AppSpacing.xl),
            AppSurface(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.event_note_outlined),
                    title: const Text('日程提醒开关'),
                    subtitle: Text(
                      provider.eventReminderAdvanceMinutes > 0
                          ? '已开启，提前 ${_formatReminderAdvance(provider.eventReminderAdvanceMinutes)} 提醒'
                          : '关闭',
                    ),
                    value: provider.eventReminderAdvanceMinutes > 0,
                    onChanged: (value) =>
                        _onEventReminderChanged(context, provider, value),
                  ),
                  if (provider.eventReminderAdvanceMinutes > 0) ...[
                    const Divider(height: 1),
                    AppActionTile(
                      icon: Icons.schedule_send_outlined,
                      title: '日程提前提醒时间',
                      subtitle:
                          '当前：提前 ${_formatReminderAdvance(provider.eventReminderAdvanceMinutes)}',
                      trailing: DropdownButton<int>(
                        value: eventOffsetValue,
                        underline: const SizedBox.shrink(),
                        items: _buildReminderOffsetMenuItems(),
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
      ),
    );
  }

  List<DropdownMenuItem<int>> _buildReminderOffsetMenuItems() {
    return [
      for (final minutes in _reminderOffsetOptions)
        DropdownMenuItem(
          value: minutes,
          child: Text('提前 ${_formatReminderAdvance(minutes)}'),
        ),
    ];
  }

  String _formatReminderAdvance(int minutes) {
    if (minutes == 1440) {
      return '1 天';
    }
    if (minutes == 120) {
      return '2 小时';
    }
    if (minutes == 60) {
      return '1 小时';
    }
    return '$minutes 分钟';
  }

  Future<bool> _ensureNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }

  Future<bool> _ensureDndPermission() async {
    if (!_supportsAndroidAutomation) {
      return true;
    }
    var status = await Permission.accessNotificationPolicy.status;
    if (!status.isGranted) {
      status = await Permission.accessNotificationPolicy.request();
    }
    return status.isGranted;
  }

  Future<bool> _ensureExactAlarmPermission() async {
    if (!_supportsAndroidAutomation) {
      return true;
    }
    return NativeAlarmService.instance.ensureExactAlarmPermission();
  }

  Future<void> _openRomPermissionHelp() async {
    if (!_supportsAndroidAutomation) {
      _showSnackBar('当前平台不需要配置 Android 后台权限');
      return;
    }
    await NativeAlarmService.instance.openRomPermissionSettings();
    _showSnackBar('已尝试打开后台权限页面，请在系统页面中允许自启动或后台运行');
  }

  Future<void> _onForegroundServiceToggled(
    SettingsProvider provider,
    bool value,
  ) async {
    if (!_supportsAndroidAutomation) {
      _showSnackBar('当前平台不需要前台保活服务');
      return;
    }

    if (value) {
      final notifOk = await _ensureNotificationPermission();
      if (!notifOk) {
        _showSnackBar('请先授予通知权限再开启保活服务');
        return;
      }

      await NativeAlarmService.instance.requestIgnoreBatteryOptimization();

      final result = await provider.toggleBackgroundServiceWithCheck(true);
      if (!result.success) {
        _showSnackBar('开启保活服务失败，请检查通知权限');
        return;
      }
      await _refreshSchedules(provider);
      return;
    }

    final result = await provider.toggleBackgroundServiceWithCheck(false);
    if (!result.success) {
      _showSnackBar('关闭保活服务失败');
      return;
    }
    await _refreshSchedules(provider);
  }

  Future<void> _onAutoMuteToggled(SettingsProvider provider, bool value) async {
    if (!_supportsAndroidAutomation) {
      _showSnackBar('自动静音仅支持 Android');
      return;
    }

    if (!value) {
      await provider.toggleAutoMuteWithCheck(false);
      await _refreshSchedules(provider);
      return;
    }

    final notifOk = await _ensureNotificationPermission();
    if (!notifOk) {
      _showSnackBar('请先授予通知权限再开启自动静音');
      return;
    }

    final alarmOk = await _ensureExactAlarmPermission();
    if (!alarmOk) {
      _showSnackBar('请先授予精确闹钟权限');
      return;
    }

    final dndOk = await _ensureDndPermission();
    if (!dndOk) {
      _showSnackBar('请先授予勿扰权限再开启自动静音');
      return;
    }

    await _offerForegroundServiceEnableIfNeeded(provider);

    final result = await provider.toggleAutoMuteWithCheck(true);
    if (!result.success) {
      _showSnackBar('开启上课自动静音失败');
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
        _showSnackBar('请先授予通知权限再开启课前提醒');
        return;
      }
      final alarmOk = await _ensureExactAlarmPermission();
      if (!alarmOk) {
        _showSnackBar('请先授予精确闹钟权限');
        return;
      }
      await _offerForegroundServiceEnableIfNeeded(provider);
    }

    final result = await provider.toggleCourseReminder(value);
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar('开启课前提醒失败，请先完成权限授权');
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
      _showSnackBar('更新课前提醒时间失败，请检查权限');
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
        _showSnackBar('请先授予通知权限再开启日程提醒');
        return;
      }
      final alarmOk = await _ensureExactAlarmPermission();
      if (!alarmOk) {
        _showSnackBar('请先授予精确闹钟权限');
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
      _showSnackBar('开启日程提醒失败，请先完成权限授权');
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
      _showSnackBar('更新日程提醒时间失败，请检查权限');
      return;
    }
    await _refreshSchedules(provider);
  }

  Future<void> _offerForegroundServiceEnableIfNeeded(
    SettingsProvider provider,
  ) async {
    if (!_supportsAndroidAutomation ||
        provider.backgroundServiceEnabled ||
        !mounted) {
      return;
    }

    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('建议开启保活服务'),
          content: const Text('为了确保息屏状态下提醒和静音能准时触发，建议开启前台保活服务以防止系统杀后台。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('暂不开启'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('去开启'),
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
