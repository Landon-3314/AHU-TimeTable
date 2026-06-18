import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../core/app_theme_tokens.dart';
import '../models/semester.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/timetable_view_provider.dart';
import '../services/app_services.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/app_wheel_pickers.dart';
import '../widgets/common/capsule_multi_select.dart';
import '../widgets/long_screenshot_scroll_capture.dart';
import '../widgets/semester_start_date_dialog.dart';
import 'period_start_time_settings_page.dart';
import 'settings_update_error_handler.dart';

class SemesterTimeSettingsPage extends StatefulWidget {
  const SemesterTimeSettingsPage({super.key});

  @override
  State<SemesterTimeSettingsPage> createState() =>
      _SemesterTimeSettingsPageState();
}

class _SemesterTimeSettingsPageState extends State<SemesterTimeSettingsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('学期与时间配置')),
      body: LongScreenshotScrollCapture(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: AppSpacing.pagePadding,
          children: [
            const AppSectionTitle(title: '学期', subtitle: '切换、创建或初始化当前学期'),
            _buildSemesterManagementSection(context, provider),
            const SizedBox(height: AppSpacing.xl),
            const AppSectionTitle(title: '日历范围', subtitle: '决定课表从哪一天开始、显示多少周'),
            _buildCalendarSection(context, provider),
            const SizedBox(height: AppSpacing.xl),
            const AppSectionTitle(title: '节次', subtitle: '调整单节课、课间和每天各时段节数'),
            _buildPeriodSection(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(
    BuildContext context,
    SettingsProvider provider,
  ) {
    return AppSurface(
      child: Column(
        children: [
          AppActionTile(
            icon: Icons.date_range_outlined,
            title: '学期起始日期',
            subtitle: _formatDate(provider.semesterStartDate),
            onTap: () => _pickSemesterStartDate(context, provider),
          ),
          const Divider(height: 1),
          AppActionTile(
            icon: Icons.calendar_view_week_outlined,
            title: '上课周数',
            subtitle: '${provider.totalWeeks} 周',
            trailing: AppPickerPill(
              label: '${provider.totalWeeks} 周',
              onTap: () => _pickTotalWeeks(context, provider),
            ),
            onTap: () => _pickTotalWeeks(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSection(BuildContext context, SettingsProvider provider) {
    return AppSurface(
      child: Column(
        children: [
          _durationTile(
            context: context,
            icon: Icons.timelapse_outlined,
            title: '每节课时长',
            value: provider.classDuration,
            min: 30,
            max: 60,
            onChanged: (v) => _updateAndRefresh(
              context,
              provider,
              () => provider.updateClassDuration(v),
            ),
          ),
          const Divider(height: 1),
          _durationTile(
            context: context,
            icon: Icons.coffee_outlined,
            title: '课间时长',
            value: provider.shortBreak,
            min: 0,
            max: 30,
            onChanged: (v) => _updateAndRefresh(
              context,
              provider,
              () => provider.updateShortBreak(v),
            ),
          ),
          const Divider(height: 1),
          AppActionTile(
            icon: Icons.more_time_outlined,
            title: '大课间',
            subtitle: _bigBreakSubtitle(provider),
            trailing: AppPickerPill(
              label: provider.bigBreakEnabled
                  ? '${provider.bigBreak} 分钟'
                  : '关闭',
              onTap: () => _pickBigBreakSettings(context, provider),
            ),
            onTap: () => _pickBigBreakSettings(context, provider),
          ),
          const Divider(height: 1),
          _sessionCountTile(
            context: context,
            icon: Icons.wb_sunny_outlined,
            title: '上午几节课',
            value: provider.morningClasses,
            max: 8,
            onChanged: (v) => _updateAndRefresh(
              context,
              provider,
              () => provider.updateMorningClasses(v),
            ),
          ),
          const Divider(height: 1),
          _sessionCountTile(
            context: context,
            icon: Icons.wb_twilight_outlined,
            title: '下午几节课',
            value: provider.afternoonClasses,
            max: 8,
            onChanged: (v) => _updateAndRefresh(
              context,
              provider,
              () => provider.updateAfternoonClasses(v),
            ),
          ),
          const Divider(height: 1),
          _sessionCountTile(
            context: context,
            icon: Icons.nightlight_outlined,
            title: '晚上几节课',
            value: provider.eveningClasses,
            max: 6,
            onChanged: (v) => _updateAndRefresh(
              context,
              provider,
              () => provider.updateEveningClasses(v),
            ),
          ),
          const Divider(height: 1),
          AppActionTile(
            icon: Icons.edit_calendar_outlined,
            title: '详细调整每节课起始时间',
            subtitle: '当前共 ${provider.totalClassPeriods} 节课',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PeriodStartTimeSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _bigBreakSubtitle(SettingsProvider provider) {
    if (!provider.bigBreakEnabled) {
      return '未启用';
    }
    final positions = provider.bigBreakAfterPeriods;
    if (positions.isEmpty) {
      return '已启用 · ${provider.bigBreak} 分钟 · 未选择位置';
    }
    final positionText = positions.map((period) => '第$period节后').join('、');
    return '已启用 · ${provider.bigBreak} 分钟 · $positionText';
  }

  Future<void> _pickBigBreakSettings(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final draft = await showModalBottomSheet<_BigBreakSettingsDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _BigBreakSettingsSheet(
          enabled: provider.bigBreakEnabled,
          durationMinutes: provider.bigBreak,
          afterPeriods: provider.bigBreakAfterPeriods,
          totalClassPeriods: provider.totalClassPeriods,
        );
      },
    );
    if (draft == null || !context.mounted) {
      return;
    }

    await _updateAndRefresh(
      context,
      provider,
      () => provider.updateBigBreakSettings(
        enabled: draft.enabled,
        durationMinutes: draft.durationMinutes,
        afterPeriods: draft.afterPeriods,
      ),
    );
  }

  Future<void> _pickTotalWeeks(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selected = await showAppWheelValuePicker<int>(
      context,
      title: '上课周数',
      selectedValue: provider.totalWeeks,
      options: [
        for (int week = 12; week <= 30; week++)
          AppWheelPickerOption(value: week, label: '$week 周'),
      ],
    );
    if (selected != null && context.mounted) {
      await _updateAndRefresh(
        context,
        provider,
        () => provider.updateTotalWeeks(selected),
      );
    }
  }

  Widget _durationTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int value,
    required int min,
    required int max,
    required Future<void> Function(int value) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('$value 分钟'),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value 分钟',
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ],
      ),
    );
  }

  Widget _sessionCountTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int value,
    required int max,
    required Future<void> Function(int value) onChanged,
  }) {
    return AppActionTile(
      icon: icon,
      title: title,
      subtitle: '$value 节',
      trailing: AppPickerPill(
        label: '$value 节',
        onTap: () => _pickSessionCount(
          context: context,
          title: title,
          value: value,
          max: max,
          onChanged: onChanged,
        ),
      ),
      onTap: () => _pickSessionCount(
        context: context,
        title: title,
        value: value,
        max: max,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _pickSessionCount({
    required BuildContext context,
    required String title,
    required int value,
    required int max,
    required Future<void> Function(int value) onChanged,
  }) async {
    final selected = await showAppWheelValuePicker<int>(
      context,
      title: title,
      selectedValue: value.clamp(0, max).toInt(),
      options: [
        for (int count = 0; count <= max; count++)
          AppWheelPickerOption(value: count, label: '$count 节'),
      ],
    );
    if (selected != null) {
      await onChanged(selected);
    }
  }

  Widget _buildSemesterManagementSection(
    BuildContext context,
    SettingsProvider provider,
  ) {
    final currentSemester = provider.currentSemester;
    return AppSurface(
      child: Column(
        children: [
          AppActionTile(
            icon: Icons.school_outlined,
            title: '当前学期',
            subtitle: currentSemester?.name ?? '未设置',
          ),
          const Divider(height: 1),
          AppActionTile(
            icon: Icons.swap_horiz_outlined,
            title: '管理学期',
            onTap: () => _showSemesterSwitcher(context, provider),
          ),
          const Divider(height: 1),
          AppActionTile(
            icon: Icons.add_circle_outline,
            title: '新建学期',
            subtitle: '创建后会立即选择学期开始日期',
            onTap: () => _createSemester(context, provider),
          ),
        ],
      ),
    );
  }

  Future<void> _showSemesterSwitcher(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final action = await showDialog<_SemesterManagementAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('学期管理'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final semester in provider.semesters)
                  ListTile(
                    leading: Icon(
                      semester.id == provider.currentSemesterId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(semester.name),
                    subtitle: Text(semester.isInitialized ? '已初始化' : '未初始化'),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_SemesterManagementAction.switchTo(semester)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: '重命名',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_SemesterManagementAction.rename(semester)),
                        ),
                        IconButton(
                          tooltip: '删除',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => Navigator.of(
                            dialogContext,
                          ).pop(_SemesterManagementAction.delete(semester)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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

    if (action == null || !context.mounted) {
      return;
    }

    switch (action.type) {
      case _SemesterManagementActionType.switchTo:
        await _switchSemester(context, provider, action.semester);
      case _SemesterManagementActionType.rename:
        await _renameSemester(context, provider, action.semester);
      case _SemesterManagementActionType.delete:
        await _deleteSemester(context, provider, action.semester);
    }
  }

  Future<void> _createSemester(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selectedDate = await _promptSemesterStartDate(
      context,
      provider.semesterStartDate,
    );
    if (selectedDate == null || !context.mounted) {
      return;
    }

    final semester = await provider.createSemesterWithInitialData(
      startDate: selectedDate,
    );
    if (!context.mounted) {
      return;
    }

    _syncTimetableToToday(context, provider);
    showAppSnackBar(
      context,
      SnackBar(content: Text('已创建并切换到${semester.name}')),
    );
  }

  Future<void> _switchSemester(
    BuildContext context,
    SettingsProvider provider,
    Semester semester,
  ) async {
    if (semester.id == provider.currentSemesterId) {
      return;
    }

    DateTime? selectedDate;
    if (!semester.isInitialized) {
      selectedDate = await _promptSemesterStartDate(
        context,
        provider.semesterStartDate,
        title: '初始化${semester.name}',
      );
      if (selectedDate == null || !context.mounted) {
        return;
      }
    }

    if (selectedDate != null) {
      await provider.initializeExistingSemesterAndSwitch(
        semester.id,
        startDate: selectedDate,
      );
    } else {
      final switched = await provider.switchSemester(semester.id);
      if (!switched) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }

    _syncTimetableToToday(context, provider);
    final semesterName = provider.currentSemester?.name ?? '当前学期';
    showAppSnackBar(context, SnackBar(content: Text('已切换到$semesterName')));
  }

  Future<void> _renameSemester(
    BuildContext context,
    SettingsProvider provider,
    Semester semester,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameSemesterDialog(initialName: semester.name),
    );

    if (newName == null || !context.mounted) {
      return;
    }

    await provider.renameSemester(semester.id, newName);
  }

  Future<void> _deleteSemester(
    BuildContext context,
    SettingsProvider provider,
    Semester semester,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('删除${semester.name}？'),
          content: const Text('将删除该学期的课程、日程和时间配置，操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final remainingCount = provider.semesters.length - 1;
    DateTime? replacementStartDate;
    if (remainingCount == 0) {
      replacementStartDate = await _promptSemesterStartDate(
        context,
        provider.semesterStartDate,
        title: '创建第一学期',
        canCancel: false,
      );
      if (replacementStartDate == null || !context.mounted) {
        return;
      }
    }

    await provider.deleteSemester(semester.id);

    if (replacementStartDate != null) {
      await provider.createSemesterWithInitialData(
        startDate: replacementStartDate,
        customName: '第 1 学期',
      );
    }

    if (!context.mounted) {
      return;
    }

    if (provider.currentSemester?.isInitialized == true) {
      _syncTimetableToToday(context, provider);
    }
  }

  Future<DateTime?> _promptSemesterStartDate(
    BuildContext context,
    DateTime initialDate, {
    String title = '选择学期开始日期',
    bool canCancel = true,
  }) {
    return showSemesterStartDateDialog(
      context: context,
      initialDate: initialDate,
      title: title,
      canCancel: canCancel,
    );
  }

  Future<void> _pickSemesterStartDate(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.semesterStartDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !context.mounted) {
      return;
    }

    await _updateAndRefresh(
      context,
      provider,
      () => provider.updateSemesterStartDate(picked),
    );
  }

  Future<void> _updateAndRefresh(
    BuildContext context,
    SettingsProvider provider,
    Future<void> Function() update,
  ) async {
    await runSettingsUpdateWithFeedback(
      context: context,
      update: update,
      afterPersisted: () => _refreshSchedules(context, provider),
      debugLabel: 'SemesterTimeSettingsPage',
    );
  }

  Future<void> _refreshSchedules(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final courseProvider = context.read<CourseProvider>();
    await AppServices.refreshSchedules(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      settings: provider,
    );
  }

  void _syncTimetableToToday(BuildContext context, SettingsProvider provider) {
    context.read<TimetableViewProvider>().setCurrentWeekAndWeekday(
      week: provider.currentRealWeek,
      weekday: provider.currentRealWeekday,
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _BigBreakSettingsDraft {
  const _BigBreakSettingsDraft({
    required this.enabled,
    required this.durationMinutes,
    required this.afterPeriods,
  });

  final bool enabled;
  final int durationMinutes;
  final List<int> afterPeriods;
}

class _BigBreakSettingsSheet extends StatefulWidget {
  const _BigBreakSettingsSheet({
    required this.enabled,
    required this.durationMinutes,
    required this.afterPeriods,
    required this.totalClassPeriods,
  });

  final bool enabled;
  final int durationMinutes;
  final List<int> afterPeriods;
  final int totalClassPeriods;

  @override
  State<_BigBreakSettingsSheet> createState() => _BigBreakSettingsSheetState();
}

class _BigBreakSettingsSheetState extends State<_BigBreakSettingsSheet> {
  late bool _enabled;
  late int _durationMinutes;
  late Set<int> _afterPeriods;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _durationMinutes = widget.durationMinutes.clamp(5, 60).toInt();
    _afterPeriods = widget.afterPeriods.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = appThemeTokensOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '大课间设置',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '大课间发生在两节课之间，会影响后续节次的默认起始时间。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用大课间'),
                value: _enabled,
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '大课间时长',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('$_durationMinutes 分钟'),
                ],
              ),
              Slider(
                value: _durationMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 55,
                label: '$_durationMinutes 分钟',
                onChanged: _enabled
                    ? (value) {
                        setState(() {
                          _durationMinutes = value.round();
                        });
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '大课间位置',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '选择“第几节后”，最后一节后不可设置。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.totalClassPeriods <= 1)
                Text(
                  '当前节次数不足，暂无可选位置',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
                )
              else
                IgnorePointer(
                  ignoring: !_enabled,
                  child: Opacity(
                    opacity: _enabled ? 1 : 0.45,
                    child: CapsuleMultiSelect<int>(
                      key: const ValueKey('big-break-position-selector'),
                      options: [
                        for (
                          int period = 1;
                          period < widget.totalClassPeriods;
                          period += 1
                        )
                          CapsuleMultiSelectOption<int>(
                            value: period,
                            label: '第$period节后',
                            semanticLabel: '第$period节和第${period + 1}节之间',
                          ),
                      ],
                      selectedValues: _afterPeriods,
                      onChanged: (values) {
                        setState(() {
                          _afterPeriods = values;
                        });
                      },
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final sortedPeriods = _afterPeriods.toList()..sort();
    Navigator.of(context).pop(
      _BigBreakSettingsDraft(
        enabled: _enabled,
        durationMinutes: _durationMinutes,
        afterPeriods: sortedPeriods,
      ),
    );
  }
}

enum _SemesterManagementActionType { switchTo, rename, delete }

class _SemesterManagementAction {
  const _SemesterManagementAction._({
    required this.type,
    required this.semester,
  });

  final _SemesterManagementActionType type;
  final Semester semester;

  factory _SemesterManagementAction.switchTo(Semester semester) {
    return _SemesterManagementAction._(
      type: _SemesterManagementActionType.switchTo,
      semester: semester,
    );
  }

  factory _SemesterManagementAction.rename(Semester semester) {
    return _SemesterManagementAction._(
      type: _SemesterManagementActionType.rename,
      semester: semester,
    );
  }

  factory _SemesterManagementAction.delete(Semester semester) {
    return _SemesterManagementAction._(
      type: _SemesterManagementActionType.delete,
      semester: semester,
    );
  }
}

class _RenameSemesterDialog extends StatefulWidget {
  const _RenameSemesterDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameSemesterDialog> createState() => _RenameSemesterDialogState();
}

class _RenameSemesterDialogState extends State<_RenameSemesterDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名学期'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 20,
        decoration: InputDecoration(labelText: '学期名称', errorText: _errorText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorText = '名称不能为空';
      });
      return;
    }
    Navigator.of(context).pop(name);
  }
}
