import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/native_alarm_service.dart';
import '../services/permission_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/app_wheel_pickers.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const int _maxCourseReminderAdvanceMinutes = 23 * 60 + 59;
  static const int _maxEventReminderAdvanceMinutes = 7 * 24 * 60 + 23 * 60 + 59;

  final ScrollController _scrollController = ScrollController();
  final PermissionService _permissionService = PermissionService();
  late final AnimationController _mutePermissionBlinkController;
  late final Animation<double> _mutePermissionBlink;
  _PermissionSnapshot? _permissionSnapshot;
  bool _mutePermissionsExpanded = false;

  bool get _supportsAndroidAutomation =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mutePermissionBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _mutePermissionBlink = CurvedAnimation(
      parent: _mutePermissionBlinkController,
      curve: Curves.easeInOut,
    );
    _refreshPermissionSnapshot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mutePermissionBlinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    final courseOffsetValue = _normalizeReminderAdvance(
      provider.reminderAdvanceMinutes,
      _maxCourseReminderAdvanceMinutes,
    );
    final eventOffsetValue = _normalizeReminderAdvance(
      provider.eventReminderAdvanceMinutes,
      _maxEventReminderAdvanceMinutes,
    );

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
                subtitle: '自动静音需要系统权限；课前提醒的持久显示样式在提醒设置中选择',
              ),
              AppSurface(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_off_outlined),
                      title: const Text('上课自动静音'),
                      subtitle: Text(_autoMuteSubtitle(provider)),
                      value: provider.autoMuteEnabled,
                      onChanged: (value) => _onAutoMuteToggled(provider, value),
                    ),
                    _buildMutePermissionSummaryTile(),
                    if (_mutePermissionsExpanded) ...[
                      const Divider(height: 1),
                      _buildMutePermissionBlinkWrapper(
                        child: AppActionTile(
                          icon: Icons.notifications_active_outlined,
                          title: '通知权限',
                          subtitle: _permissionLabel(
                            _permissionSnapshot?.notificationGranted,
                          ),
                          onTap: _openNotificationPermission,
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMutePermissionBlinkWrapper(
                        child: AppActionTile(
                          icon: Icons.alarm_on_outlined,
                          title: '精确闹钟权限',
                          subtitle: _permissionLabel(
                            _permissionSnapshot?.exactAlarmGranted,
                            grantedText: '已允许，课程和日程核心提醒将使用精确闹钟',
                            deniedText: '未允许，提醒会降级为非精确，自动静音会改为手动提醒',
                          ),
                          onTap: _openExactAlarmSettings,
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMutePermissionBlinkWrapper(
                        child: AppActionTile(
                          icon: Icons.do_not_disturb_on_outlined,
                          title: '勿扰/静音权限',
                          subtitle: _permissionLabel(
                            _permissionSnapshot?.dndGranted,
                            grantedText: '已允许，应用可在课程时间切换静音并恢复',
                            deniedText: '未允许，自动静音会降级为通知提醒',
                          ),
                          onTap: _openDndSettings,
                        ),
                      ),
                      const Divider(height: 1),
                      _buildMutePermissionBlinkWrapper(
                        child: AppActionTile(
                          icon: Icons.security_update_warning_outlined,
                          title: '如果静音失效，点此开启后台权限',
                          subtitle: '将尝试打开自启动管理或后台高耗电允许页面',
                          onTap: _openRomPermissionHelp,
                        ),
                      ),
                    ],
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
                    subtitle: Text(_courseReminderSubtitle(provider)),
                    value: provider.courseReminderEnabled,
                    onChanged: (value) =>
                        _onCourseReminderChanged(context, provider, value),
                  ),
                  if (provider.courseReminderEnabled) ...[
                    const Divider(height: 1),
                    AppActionTile(
                      icon: Icons.style_outlined,
                      title: '提醒样式',
                      subtitle: _courseReminderStyleLabel(
                        provider.courseReminderStyle,
                      ),
                      trailing: AppPickerPill(
                        label: _courseReminderStyleShortLabel(
                          provider.courseReminderStyle,
                        ),
                        onTap: () => _pickCourseReminderStyle(
                          context: context,
                          selectedValue: provider.courseReminderStyle,
                          onSelected: (style) => _onCourseReminderStyleChanged(
                            context,
                            provider,
                            style,
                          ),
                        ),
                      ),
                      onTap: () => _pickCourseReminderStyle(
                        context: context,
                        selectedValue: provider.courseReminderStyle,
                        onSelected: (style) => _onCourseReminderStyleChanged(
                          context,
                          provider,
                          style,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    AppActionTile(
                      icon: Icons.timer_outlined,
                      title: '提前提醒时间',
                      subtitle: provider.courseReminderUsesPersistentDisplay
                          ? '持久显示样式下由系统自动显示课程状态，不使用提前时间'
                          : '当前：提前 ${_formatReminderAdvance(provider.reminderAdvanceMinutes)}',
                      enabled: provider.courseReminderUsesSingleNotification,
                      trailing: AppPickerPill(
                        label:
                            '提前 ${_formatReminderAdvance(courseOffsetValue)}',
                        enabled: provider.courseReminderUsesSingleNotification,
                        onTap: () => _pickReminderOffset(
                          context: context,
                          title: '提前提醒时间',
                          selectedValue: courseOffsetValue,
                          isEventReminder: false,
                          onSelected: (value) => _onCourseReminderOffsetChanged(
                            context,
                            provider,
                            value,
                          ),
                        ),
                      ),
                      onTap: () => _pickReminderOffset(
                        context: context,
                        title: '提前提醒时间',
                        selectedValue: courseOffsetValue,
                        isEventReminder: false,
                        onSelected: (value) => _onCourseReminderOffsetChanged(
                          context,
                          provider,
                          value,
                        ),
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
                      trailing: AppPickerPill(
                        label: '提前 ${_formatReminderAdvance(eventOffsetValue)}',
                        onTap: () => _pickReminderOffset(
                          context: context,
                          title: '日程提前提醒时间',
                          selectedValue: eventOffsetValue,
                          isEventReminder: true,
                          onSelected: (value) => _onEventReminderOffsetChanged(
                            context,
                            provider,
                            value,
                          ),
                        ),
                      ),
                      onTap: () => _pickReminderOffset(
                        context: context,
                        title: '日程提前提醒时间',
                        selectedValue: eventOffsetValue,
                        isEventReminder: true,
                        onSelected: (value) => _onEventReminderOffsetChanged(
                          context,
                          provider,
                          value,
                        ),
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

  Widget _buildMutePermissionSummaryTile() {
    final colorScheme = Theme.of(context).colorScheme;
    final requiredGranted = _requiredAutoMutePermissionsGranted;
    final missingCount = _missingRequiredAutoMutePermissionCount;
    final statusLabel = requiredGranted ? '已就绪' : '缺少 $missingCount 项';

    return AnimatedBuilder(
      animation: _mutePermissionBlink,
      builder: (context, child) {
        final highlightColor = colorScheme.errorContainer.withValues(
          alpha: 0.62 * _mutePermissionBlink.value,
        );
        return AnimatedContainer(
          duration: AppDurations.fast,
          decoration: BoxDecoration(color: highlightColor),
          child: child,
        );
      },
      child: AppActionTile(
        icon: requiredGranted
            ? Icons.verified_outlined
            : Icons.rule_folder_outlined,
        title: '静音权限与系统设置',
        subtitle: _mutePermissionSummarySubtitle(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: requiredGranted
                    ? colorScheme.primaryContainer
                    : colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: requiredGranted
                        ? colorScheme.secondary
                        : colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AnimatedRotation(
              duration: AppDurations.fast,
              turns: _mutePermissionsExpanded ? 0.5 : 0,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ),
        onTap: () {
          setState(() {
            _mutePermissionsExpanded = !_mutePermissionsExpanded;
          });
        },
      ),
    );
  }

  Widget _buildMutePermissionBlinkWrapper({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _mutePermissionBlink,
      builder: (context, child) {
        return ColoredBox(
          color: colorScheme.errorContainer.withValues(
            alpha: 0.52 * _mutePermissionBlink.value,
          ),
          child: child,
        );
      },
      child: child,
    );
  }

  Future<void> _pickReminderOffset({
    required BuildContext context,
    required String title,
    required int selectedValue,
    required bool isEventReminder,
    required Future<void> Function(int value) onSelected,
  }) async {
    final int? selected;
    if (isEventReminder) {
      selected = await showEventReminderAdvancePicker(
        context,
        title: title,
        initialMinutes: selectedValue,
      );
    } else {
      selected = await showCourseReminderAdvancePicker(
        context,
        title: title,
        initialMinutes: selectedValue,
      );
    }
    if (!context.mounted) {
      return;
    }
    if (selected != null) {
      await onSelected(selected);
    }
  }

  Future<void> _pickCourseReminderStyle({
    required BuildContext context,
    required CourseReminderStyle selectedValue,
    required Future<void> Function(CourseReminderStyle value) onSelected,
  }) async {
    final selected = await showAppOptionPicker<CourseReminderStyle>(
      context,
      title: '课前提醒样式',
      selectedValue: selectedValue,
      options: const [
        AppPickerOption(
          value: CourseReminderStyle.singleNotification,
          label: '单次通知',
          subtitle: '按提前时间发送一次系统通知',
        ),
        AppPickerOption(
          value: CourseReminderStyle.persistentDisplay,
          label: '持久显示',
          subtitle: '上课前自动显示当前/下一节课状态',
        ),
      ],
    );
    if (selected != null) {
      await onSelected(selected);
    }
  }

  String _formatReminderAdvance(int minutes) {
    final safeMinutes = minutes.clamp(0, _maxEventReminderAdvanceMinutes);
    if (safeMinutes <= 0) {
      return '0 分钟';
    }
    final days = safeMinutes ~/ (24 * 60);
    final remainingAfterDays = safeMinutes % (24 * 60);
    final hours = remainingAfterDays ~/ 60;
    final mins = remainingAfterDays % 60;
    final parts = <String>[
      if (days > 0) '$days 天',
      if (hours > 0) '$hours 小时',
      if (mins > 0) '$mins 分钟',
    ];
    return parts.join(' ');
  }

  int _normalizeReminderAdvance(int minutes, int maxMinutes) {
    if (minutes <= 0) {
      return 10;
    }
    return minutes.clamp(1, maxMinutes).toInt();
  }

  String _courseReminderSubtitle(SettingsProvider provider) {
    if (!provider.courseReminderEnabled) {
      return '关闭';
    }
    switch (provider.courseReminderStyle) {
      case CourseReminderStyle.singleNotification:
        return '单次通知，提前 ${_formatReminderAdvance(provider.reminderAdvanceMinutes)} 提醒';
      case CourseReminderStyle.persistentDisplay:
        return '持久显示，课前自动展示当前/下一节课状态';
    }
  }

  String _courseReminderStyleLabel(CourseReminderStyle style) {
    switch (style) {
      case CourseReminderStyle.singleNotification:
        return '单次通知：按提前时间发送一次系统通知';
      case CourseReminderStyle.persistentDisplay:
        return '持久显示：课程状态会在通知栏持续显示';
    }
  }

  String _courseReminderStyleShortLabel(CourseReminderStyle style) {
    switch (style) {
      case CourseReminderStyle.singleNotification:
        return '单次通知';
      case CourseReminderStyle.persistentDisplay:
        return '持久显示';
    }
  }

  String _autoMuteSubtitle(SettingsProvider provider) {
    if (!provider.autoMuteEnabled) {
      return '关闭；开启后将优先自动静音，缺少权限时改为通知提醒';
    }
    final snapshot = _permissionSnapshot;
    if (snapshot == null) {
      return '正在检查系统权限...';
    }
    if (snapshot.exactAlarmGranted && snapshot.dndGranted) {
      return '权限完整，将使用系统精确闹钟自动静音并恢复';
    }
    return '已开启，但缺少系统权限时会在上课时通知你手动静音';
  }

  String _permissionLabel(
    bool? granted, {
    String grantedText = '已允许',
    String deniedText = '未允许，点此打开系统授权',
  }) {
    if (granted == null) {
      return '正在检查...';
    }
    return granted ? grantedText : deniedText;
  }

  bool get _requiredAutoMutePermissionsGranted {
    final snapshot = _permissionSnapshot;
    return snapshot != null &&
        snapshot.notificationGranted &&
        snapshot.exactAlarmGranted &&
        snapshot.dndGranted;
  }

  int get _missingRequiredAutoMutePermissionCount {
    final snapshot = _permissionSnapshot;
    if (snapshot == null) {
      return 3;
    }
    return <bool>[
      snapshot.notificationGranted,
      snapshot.exactAlarmGranted,
      snapshot.dndGranted,
    ].where((granted) => !granted).length;
  }

  String _mutePermissionSummarySubtitle() {
    final snapshot = _permissionSnapshot;
    if (snapshot == null) {
      return '正在检查通知、精确闹钟和勿扰/静音权限';
    }
    if (_requiredAutoMutePermissionsGranted) {
      return '通知、精确闹钟、勿扰/静音权限已完成；后台权限仅作为排障入口';
    }
    return '开启自动静音前需要先完成通知、精确闹钟、勿扰/静音权限';
  }

  Future<void> _refreshPermissionSnapshot() async {
    if (!_supportsAndroidAutomation) {
      return;
    }
    final notificationGranted = await _permissionService
        .hasNotificationPermission();
    final exactAlarmGranted = await NativeAlarmService.instance
        .hasExactAlarmPermission();
    final dndGranted = await _permissionService.hasDndPermission();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionSnapshot = _PermissionSnapshot(
        notificationGranted: notificationGranted,
        exactAlarmGranted: exactAlarmGranted,
        dndGranted: dndGranted,
      );
    });
  }

  Future<void> _flashMutePermissionPanel() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _mutePermissionsExpanded = true;
    });
    if (_mutePermissionBlinkController.isAnimating) {
      return;
    }
    _mutePermissionBlinkController.value = 0;
    for (var i = 0; i < 3; i += 1) {
      if (!mounted) {
        return;
      }
      await _mutePermissionBlinkController.forward(from: 0);
      if (!mounted) {
        return;
      }
      await _mutePermissionBlinkController.reverse();
    }
    _mutePermissionBlinkController.value = 0;
  }

  Future<bool> _ensureNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }
    return status.isGranted;
  }

  Future<bool> _ensureExactAlarmPermission() async {
    if (!_supportsAndroidAutomation) {
      return true;
    }
    return NativeAlarmService.instance.ensureExactAlarmPermission();
  }

  Future<void> _openNotificationPermission() async {
    final granted = await _ensureNotificationPermission();
    await _refreshPermissionSnapshot();
    _showSnackBar(granted ? '通知权限已允许' : '请在系统设置中允许通知权限');
  }

  Future<void> _openExactAlarmSettings() async {
    final granted = await _ensureExactAlarmPermission();
    await _refreshPermissionSnapshot();
    _showSnackBar(granted ? '精确闹钟权限已允许' : '请在系统设置中允许精确闹钟权限');
  }

  Future<void> _openDndSettings() async {
    await context.read<SettingsProvider>().openSystemDndSettings();
    _showSnackBar('请在系统页面中允许安大课表访问勿扰/静音权限');
  }

  Future<void> _openRomPermissionHelp() async {
    if (!_supportsAndroidAutomation) {
      _showSnackBar('当前平台不需要配置 Android 后台权限');
      return;
    }
    await NativeAlarmService.instance.openRomPermissionSettings();
    _showSnackBar('已尝试打开后台权限页面，请在系统页面中允许自启动或后台运行');
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

    await _refreshPermissionSnapshot();
    if (!_requiredAutoMutePermissionsGranted) {
      await _flashMutePermissionPanel();
      _showSnackBar('请先完成通知、精确闹钟、勿扰/静音权限，再开启上课自动静音');
      return;
    }

    final result = await provider.toggleAutoMuteWithCheck(true);
    if (!result.success) {
      _showSnackBar('开启上课自动静音失败');
      return;
    }

    await _refreshPermissionSnapshot();
    await _refreshSchedules(provider);
    final snapshot = _permissionSnapshot;
    if (snapshot != null &&
        (!snapshot.exactAlarmGranted || !snapshot.dndGranted)) {
      _showSnackBar('已开启；缺少精确闹钟或勿扰权限时，将改为上课手动静音提醒');
    }
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

  Future<void> _onCourseReminderStyleChanged(
    BuildContext context,
    SettingsProvider provider,
    CourseReminderStyle style,
  ) async {
    final result = await provider.updateCourseReminderStyle(style);
    if (!context.mounted) {
      return;
    }
    if (!result.success) {
      _showSnackBar('请先授予通知权限再切换课前提醒样式');
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
    showAppSnackBar(context, SnackBar(content: Text(message)));
  }
}

class _PermissionSnapshot {
  const _PermissionSnapshot({
    required this.notificationGranted,
    required this.exactAlarmGranted,
    required this.dndGranted,
  });

  final bool notificationGranted;
  final bool exactAlarmGranted;
  final bool dndGranted;
}
