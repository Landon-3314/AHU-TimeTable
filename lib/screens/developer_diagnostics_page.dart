import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/local_notification_service.dart';
import '../services/native_alarm_service.dart';
import '../services/permission_service.dart';
import '../services/schedule_plan.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class DeveloperDiagnosticsPage extends StatefulWidget {
  const DeveloperDiagnosticsPage({super.key});

  @override
  State<DeveloperDiagnosticsPage> createState() =>
      _DeveloperDiagnosticsPageState();
}

class _DeveloperDiagnosticsPageState extends State<DeveloperDiagnosticsPage> {
  static const String _logTag = '[NotificationDiag]';
  static const String _muteLogTag = '[MuteDiag]';

  final ScrollController _scrollController = ScrollController();
  final PermissionService _permissionService = PermissionService();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者诊断')),
      body: LongScreenshotScrollCapture(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            _DiagnosticSection(
              title: '权限与当前计划',
              children: [
                _DiagnosticButton(
                  icon: Icons.fact_check_outlined,
                  label: '检查通知 / 精确闹钟 / 勿扰权限',
                  onPressed: () => _checkPermissions(context),
                ),
                _DiagnosticButton(
                  icon: Icons.sync_outlined,
                  label: '刷新当前真实提醒与静音计划',
                  onPressed: () => _refreshRealSchedules(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DiagnosticSection(
              title: '本地通知调度测试',
              children: [
                _DiagnosticButton(
                  icon: Icons.notifications_active_outlined,
                  label: '5 秒后发送课前提醒通知',
                  onPressed: () => _scheduleDebugNotification(
                    context,
                    kind: ManagedNotificationKind.courseReminder,
                    title: '测试课前提醒',
                    body: '这是本地通知调度测试，模拟课前提醒。',
                  ),
                ),
                _DiagnosticButton(
                  icon: Icons.event_note_outlined,
                  label: '5 秒后发送日程提醒通知',
                  onPressed: () => _scheduleDebugNotification(
                    context,
                    kind: ManagedNotificationKind.eventReminder,
                    title: '测试日程提醒',
                    body: '这是本地通知调度测试，模拟日程提醒。',
                  ),
                ),
                _DiagnosticButton(
                  icon: Icons.volume_mute_outlined,
                  label: '5 秒后发送手动静音降级提醒',
                  onPressed: () => _scheduleDebugNotification(
                    context,
                    kind: ManagedNotificationKind.manualMute,
                    title: '测试手动静音提醒',
                    body: '模拟缺少权限时的降级提醒：请手动静音。',
                  ),
                ),
                _DiagnosticButton(
                  icon: Icons.cleaning_services_outlined,
                  label: '取消所有诊断通知',
                  onPressed: () => _cancelDebugNotifications(context),
                ),
                _DiagnosticButton(
                  icon: Icons.receipt_long_outlined,
                  label: '打印当前 pending 通知到控制台',
                  onPressed: () => _dumpPendingNotifications(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DiagnosticSection(
              title: 'Android 静音执行测试',
              children: [
                _DiagnosticButton(
                  icon: Icons.settings_applications_outlined,
                  label: '打开勿扰/静音权限设置',
                  onPressed: () => _openDndSettings(context),
                  enabled: _isAndroid,
                ),
                _DiagnosticButton(
                  icon: Icons.fact_check_outlined,
                  label: '检查静音权限并打印日志',
                  onPressed: () => _checkMutePermissions(context),
                  enabled: _isAndroid,
                ),
                _DiagnosticButton(
                  icon: Icons.volume_off_outlined,
                  label: '立即调用 sound_mode 静音',
                  onPressed: () => _simulateMute(context),
                  enabled: _isAndroid,
                ),
                _DiagnosticButton(
                  icon: Icons.volume_up_outlined,
                  label: '立即调用 sound_mode 恢复响铃',
                  onPressed: () => _simulateUnmute(context),
                  enabled: _isAndroid,
                ),
                _DiagnosticButton(
                  icon: Icons.alarm_on_outlined,
                  label: '30 秒后原生静音，60 秒后自动恢复',
                  onPressed: () => _runTimedMuteTest(
                    context,
                    muteAfterSeconds: 30,
                    restoreAfterSeconds: 60,
                  ),
                  enabled: _isAndroid,
                ),
                _DiagnosticButton(
                  icon: Icons.schedule_outlined,
                  label: '1 分钟后原生静音，2 分钟后自动恢复',
                  onPressed: () => _runTimedMuteTest(
                    context,
                    muteAfterSeconds: 60,
                    restoreAfterSeconds: 120,
                  ),
                  enabled: _isAndroid,
                ),
                _DiagnosticButton(
                  icon: Icons.alarm_off_outlined,
                  label: '取消诊断静音闹钟',
                  onPressed: () => _cancelTimedMuteTest(context),
                  enabled: _isAndroid,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateMute(BuildContext context) async {
    _muteLog('simulateMute pressed');
    if (!await _ensureMutePermission(context, 'simulateMute')) {
      return;
    }
    try {
      await SoundMode.setSoundMode(RingerModeStatus.silent);
      _muteLog('simulateMute success');
    } on PlatformException catch (e) {
      _muteLog(
        'simulateMute platform failure code=${e.code} '
        'message=${e.message} details=${e.details}',
      );
      if (context.mounted) {
        _showMutePermissionSnackBar(context);
      }
      return;
    } catch (e) {
      _muteLog('simulateMute unexpected failure error=$e');
      if (context.mounted) {
        _showSnackBar(context, '静音调用失败：$e');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(
      context,
      const SnackBar(content: Text('已调用 sound_mode 静音')),
    );
  }

  Future<void> _simulateUnmute(BuildContext context) async {
    _muteLog('simulateUnmute pressed');
    if (!await _ensureMutePermission(context, 'simulateUnmute')) {
      return;
    }
    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
      _muteLog('simulateUnmute success');
    } on PlatformException catch (e) {
      _muteLog(
        'simulateUnmute platform failure code=${e.code} '
        'message=${e.message} details=${e.details}',
      );
      if (context.mounted) {
        _showMutePermissionSnackBar(context);
      }
      return;
    } catch (e) {
      _muteLog('simulateUnmute unexpected failure error=$e');
      if (context.mounted) {
        _showSnackBar(context, '恢复响铃调用失败：$e');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(
      context,
      const SnackBar(content: Text('已调用 sound_mode 恢复响铃')),
    );
  }

  Future<void> _runTimedMuteTest(
    BuildContext context, {
    required int muteAfterSeconds,
    required int restoreAfterSeconds,
  }) async {
    _muteLog(
      'runTimedMuteTest pressed muteAfterSeconds=$muteAfterSeconds '
      'restoreAfterSeconds=$restoreAfterSeconds',
    );
    if (!_isAndroid) {
      _showSnackBar(context, '原生静音测试仅支持 Android');
      return;
    }
    if (!await _ensureMutePermission(context, 'runTimedMuteTest')) {
      return;
    }
    final hasExactAlarmPermission = await NativeAlarmService.instance
        .hasExactAlarmPermission();
    _muteLog('runTimedMuteTest exactAlarmPermission=$hasExactAlarmPermission');
    final result = await NativeAlarmService.instance.runTimedMuteTest(
      muteAfterSeconds: muteAfterSeconds,
      restoreAfterSeconds: restoreAfterSeconds,
    );
    _muteLog(
      'runTimedMuteTest native schedule success=${result.success} '
      'reason=${result.reason}',
    );
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar(context, result.failureMessage);
      return;
    }
    _showSnackBar(
      context,
      '已写入测试闹钟：$muteAfterSeconds 秒后静音，$restoreAfterSeconds 秒后恢复',
    );
  }

  Future<void> _cancelTimedMuteTest(BuildContext context) async {
    _muteLog('cancelTimedMuteTest pressed');
    if (!_isAndroid) {
      _showSnackBar(context, '原生静音测试仅支持 Android');
      return;
    }
    final cancelled = await NativeAlarmService.instance.cancelTimedMuteTest();
    _muteLog('cancelTimedMuteTest native result=$cancelled');
    if (!context.mounted) {
      return;
    }
    _showSnackBar(context, '已取消诊断静音闹钟');
  }

  Future<void> _openDndSettings(BuildContext context) async {
    _muteLog('openDndSettings pressed');
    await _permissionService.openSystemDndSettings();
    if (!context.mounted) {
      return;
    }
    _showSnackBar(context, '已打开勿扰/静音权限设置，授权后返回再点检查');
  }

  Future<void> _checkMutePermissions(BuildContext context) async {
    _muteLog('checkMutePermissions pressed');
    final dndGranted = await _permissionService.hasDndPermission();
    final exactAlarmGranted = await NativeAlarmService.instance
        .hasExactAlarmPermission();
    _muteLog(
      'checkMutePermissions result dnd=$dndGranted '
      'exactAlarm=$exactAlarmGranted',
    );
    if (!context.mounted) {
      return;
    }
    _showSnackBar(
      context,
      '静音权限：${_yesNo(dndGranted)}；精确闹钟：${_yesNo(exactAlarmGranted)}',
    );
  }

  Future<bool> _ensureMutePermission(
    BuildContext context,
    String reason,
  ) async {
    if (!_isAndroid) {
      _muteLog('$reason mute permission skipped: non-Android');
      return true;
    }
    final dndGranted = await _permissionService.hasDndPermission();
    _muteLog('$reason dndPermission=$dndGranted');
    if (dndGranted) {
      return true;
    }
    if (context.mounted) {
      _showMutePermissionSnackBar(context);
    }
    return false;
  }

  Future<void> _scheduleDebugNotification(
    BuildContext context, {
    required ManagedNotificationKind kind,
    required String title,
    required String body,
  }) async {
    _log('debug button schedule notification pressed kind=${kind.name}');
    final diagnosticsBefore = await _permissionService
        .notificationDiagnostics();
    _log('diagnostics before permission request: $diagnosticsBefore');
    final notificationGranted = await _permissionService
        .ensureNotificationPermission();
    _log('notification permission after ensure=$notificationGranted');
    if (!context.mounted) {
      _log('schedule notification aborted: context unmounted after permission');
      return;
    }
    if (!notificationGranted) {
      _log('schedule notification aborted: notification permission denied');
      _showSnackBar(context, '请先授予通知权限');
      return;
    }
    final useExactAlarms = await NativeAlarmService.instance
        .hasExactAlarmPermission();
    _log('exact alarm permission for debug notification=$useExactAlarms');
    final ok = await LocalNotificationService.instance
        .scheduleDebugNotification(
          kind: kind,
          delay: const Duration(seconds: 5),
          title: title,
          body: body,
          useExactAlarms: useExactAlarms,
        );
    _log('debug notification schedule result kind=${kind.name} ok=$ok');
    if (!context.mounted) {
      _log('schedule notification completed but context unmounted');
      return;
    }
    _showSnackBar(context, ok ? '诊断通知已安排，5 秒后触发' : '诊断通知安排失败');
  }

  Future<void> _cancelDebugNotifications(BuildContext context) async {
    _log('debug button cancel debug notifications pressed');
    await LocalNotificationService.instance.cancelDebugNotifications();
    if (!context.mounted) {
      _log('cancel debug notifications completed but context unmounted');
      return;
    }
    _showSnackBar(context, '已取消诊断通知，不影响真实课表提醒');
  }

  Future<void> _dumpPendingNotifications(BuildContext context) async {
    _log('debug button dump pending notifications pressed');
    final diagnostics = await _permissionService.notificationDiagnostics();
    _log('diagnostics before pending dump: $diagnostics');
    await LocalNotificationService.instance.logPendingNotificationRequests(
      reason: 'developerDiagnosticsButton',
    );
    if (!context.mounted) {
      _log('dump pending notifications completed but context unmounted');
      return;
    }
    _showSnackBar(context, '已将 pending 通知信息打印到控制台');
  }

  Future<void> _refreshRealSchedules(BuildContext context) async {
    _log('debug button refresh real schedules pressed');
    final settings = context.read<SettingsProvider>();
    final courses = context.read<CourseProvider>();
    _log(
      'refresh real schedules input courses=${courses.courses.length} '
      'events=${courses.events.length}',
    );
    await AppServices.refreshSchedules(
      courses: courses.courses.toList(),
      events: courses.events.toList(),
      settings: settings,
    );
    _log('refresh real schedules completed');
    if (!context.mounted) {
      return;
    }
    _showSnackBar(context, '已刷新当前真实提醒与静音计划');
  }

  Future<void> _checkPermissions(BuildContext context) async {
    _log('debug button check notification permissions pressed');
    final diagnostics = await _permissionService.notificationDiagnostics();
    _log('diagnostics from permission check: $diagnostics');
    final notificationGranted = await _permissionService
        .hasNotificationPermission();
    final exactAlarmGranted = await NativeAlarmService.instance
        .hasExactAlarmPermission();
    final dndGranted = await _permissionService.hasDndPermission();
    _log(
      'permission check summary notification=$notificationGranted '
      'exact=$exactAlarmGranted dnd=$dndGranted',
    );
    if (!context.mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('权限检查'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('通知权限：${_yesNo(notificationGranted)}'),
              const SizedBox(height: 8),
              Text('精确闹钟权限：${_yesNo(exactAlarmGranted)}'),
              const SizedBox(height: 8),
              Text('勿扰/静音权限：${_yesNo(dndGranted)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _yesNo(bool value) => value ? '已允许' : '未允许';

  void _showMutePermissionSnackBar(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(
      context,
      SnackBar(
        content: const Text('缺少勿扰/静音权限，系统会拒绝自动静音'),
        action: SnackBarAction(
          label: '去开启',
          onPressed: () {
            _permissionService.openSystemDndSettings();
          },
        ),
      ),
    );
  }

  static void _log(String message) {
    debugPrint('$_logTag ${DateTime.now().toIso8601String()} $message');
  }

  static void _muteLog(String message) {
    debugPrint('$_muteLogTag ${DateTime.now().toIso8601String()} $message');
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(context, SnackBar(content: Text(message)));
  }
}

class _DiagnosticSection extends StatelessWidget {
  const _DiagnosticSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DiagnosticButton extends StatelessWidget {
  const _DiagnosticButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
