import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/semester.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/timetable_view_provider.dart';
import '../services/app_services.dart';
import '../services/native_alarm_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/long_screenshot_scroll_capture.dart';
import '../widgets/semester_start_date_dialog.dart';
import 'period_start_time_settings_page.dart';

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

  Future<void> _pickTotalWeeks(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final selected = await showAppOptionPicker<int>(
      context,
      title: '上课周数',
      selectedValue: provider.totalWeeks,
      grid: true,
      gridCrossAxisCount: 3,
      options: [
        for (int week = 12; week <= 30; week++)
          AppPickerOption(value: week, label: '$week 周'),
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
    final selected = await showAppOptionPicker<int>(
      context,
      title: title,
      selectedValue: value.clamp(0, max).toInt(),
      grid: true,
      gridCrossAxisCount: 3,
      options: [
        for (int count = 0; count <= max; count++)
          AppPickerOption(value: count, label: '$count 节'),
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
    final courseProvider = context.read<CourseProvider>();
    final selectedDate = await _promptSemesterStartDate(
      context,
      provider.semesterStartDate,
    );
    if (selectedDate == null || !context.mounted) {
      return;
    }

    await NativeAlarmService.instance.cancelAllClasses();
    final semester = await provider.createSemesterWithInitialData(
      startDate: selectedDate,
    );
    await courseProvider.reloadForCurrentSemester(refreshReminders: false);
    if (!context.mounted) {
      return;
    }

    _syncTimetableToToday(context, provider);
    await _refreshSchedules(context, provider);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已创建并切换到${semester.name}')));
  }

  Future<void> _switchSemester(
    BuildContext context,
    SettingsProvider provider,
    Semester semester,
  ) async {
    if (semester.id == provider.currentSemesterId) {
      return;
    }

    final courseProvider = context.read<CourseProvider>();
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

    await NativeAlarmService.instance.cancelAllClasses();
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
    await courseProvider.reloadForCurrentSemester(refreshReminders: false);
    if (!context.mounted) {
      return;
    }

    _syncTimetableToToday(context, provider);
    await _refreshSchedules(context, provider);
    if (!context.mounted) {
      return;
    }

    final semesterName = provider.currentSemester?.name ?? '当前学期';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切换到$semesterName')));
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
                foregroundColor: AppColors.onPrimary,
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

    final isDeletingCurrent = semester.id == provider.currentSemesterId;
    final remainingCount = provider.semesters.length - 1;
    DateTime? replacementStartDate;
    if (remainingCount == 0) {
      replacementStartDate = await _promptSemesterStartDate(
        context,
        provider.semesterStartDate,
        title: '创建第一学期',
      );
      if (replacementStartDate == null || !context.mounted) {
        return;
      }
    }

    final courseProvider = context.read<CourseProvider>();
    if (isDeletingCurrent) {
      await NativeAlarmService.instance.cancelAllClasses();
    }
    await provider.deleteSemester(semester.id);

    if (replacementStartDate != null) {
      await provider.createSemesterWithInitialData(
        startDate: replacementStartDate,
        customName: '第 1 学期',
      );
    }

    await courseProvider.reloadForCurrentSemester(refreshReminders: false);
    if (!context.mounted) {
      return;
    }

    if (provider.currentSemester?.isInitialized == true) {
      _syncTimetableToToday(context, provider);
      await _refreshSchedules(context, provider);
    } else {
      await NativeAlarmService.instance.cancelAllClasses();
    }
  }

  Future<DateTime?> _promptSemesterStartDate(
    BuildContext context,
    DateTime initialDate, {
    String title = '选择学期开始日期',
  }) {
    return showSemesterStartDateDialog(
      context: context,
      initialDate: initialDate,
      title: title,
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
    await update();
    if (!context.mounted) {
      return;
    }
    await _refreshSchedules(context, provider);
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
