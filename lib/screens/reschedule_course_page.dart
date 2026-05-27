import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/timetable_view_data_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class RescheduleCoursePage extends StatefulWidget {
  const RescheduleCoursePage({
    super.key,
    required this.course,
    required this.sourceWeek,
  });

  final Course course;
  final int sourceWeek;

  @override
  State<RescheduleCoursePage> createState() => _RescheduleCoursePageState();
}

class _RescheduleCoursePageState extends State<RescheduleCoursePage> {
  final ScrollController _scrollController = ScrollController();

  int? _targetWeek;
  int? _targetWeekday;
  int? _targetStartPeriod;
  bool _isSaving = false;

  int get _periodSpan => widget.course.endPeriod - widget.course.startPeriod;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _targetWeek = widget.sourceWeek;
    _targetWeekday = widget.course.weekday;
    _targetStartPeriod = widget.course.startPeriod;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final periodCount = settingsProvider.timeSlots.length;
    final maxStartPeriod = periodCount - _periodSpan;
    final canFitPeriodRange = periodCount > 0 && maxStartPeriod >= 1;
    final effectiveTargetWeek = _targetWeek ?? widget.sourceWeek;
    final effectiveTargetWeekday = _targetWeekday ?? widget.course.weekday;
    final effectiveTargetStartPeriod =
        _boundedStartPeriod(
          _targetStartPeriod ?? widget.course.startPeriod,
          maxStartPeriod,
        ) ??
        widget.course.startPeriod;
    final effectiveTargetEndPeriod = effectiveTargetStartPeriod + _periodSpan;

    return Scaffold(
      appBar: AppBar(title: Text(settingsProvider.t('reschedule_course'))),
      body: SafeArea(
        child: LongScreenshotScrollCapture(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            padding: AppSpacing.pagePadding,
            children: [
              AppSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SummaryRow(
                      label: settingsProvider.t('original_schedule'),
                      value:
                          '${_weekLabel(settingsProvider, widget.sourceWeek)} / '
                          '${_weekdayLabel(settingsProvider, widget.course.weekday)} / '
                          '${_periodRangeLabel(settingsProvider, widget.course.startPeriod, widget.course.endPeriod)}',
                    ),
                    if (widget.course.location.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SummaryRow(
                        label: settingsProvider.t('location'),
                        value: widget.course.location,
                      ),
                    ],
                    if (widget.course.teacher.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SummaryRow(
                        label: settingsProvider.t('teacher'),
                        value: widget.course.teacher,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppPickerField(
                label: settingsProvider.t('target_week'),
                valueLabel: _weekLabel(settingsProvider, effectiveTargetWeek),
                onTap: () => _pickTargetWeek(
                  settingsProvider,
                  selectedValue: effectiveTargetWeek,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPickerField(
                label: settingsProvider.t('target_weekday'),
                valueLabel: _weekdayLabel(
                  settingsProvider,
                  effectiveTargetWeekday,
                ),
                onTap: () => _pickTargetWeekday(
                  settingsProvider,
                  selectedValue: effectiveTargetWeekday,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppPickerField(
                label: settingsProvider.t('target_start_period'),
                enabled: canFitPeriodRange,
                valueLabel: canFitPeriodRange
                    ? _periodLabel(settingsProvider, effectiveTargetStartPeriod)
                    : settingsProvider.t('invalid_reschedule_period_range'),
                onTap: () => _pickTargetStartPeriod(
                  settingsProvider,
                  selectedValue: effectiveTargetStartPeriod,
                  maxStartPeriod: maxStartPeriod,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: settingsProvider.t('target_end_period'),
                ),
                child: Text(
                  canFitPeriodRange
                      ? _periodLabel(settingsProvider, effectiveTargetEndPeriod)
                      : settingsProvider.t('invalid_reschedule_period_range'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!canFitPeriodRange) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  settingsProvider.t('invalid_reschedule_period_range'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.formBottomSafeArea),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.actionBarPadding,
        child: FilledButton(
          onPressed: _isSaving
              ? null
              : () => _submit(
                  periodCount: periodCount,
                  maxStartPeriod: maxStartPeriod,
                  targetWeek: effectiveTargetWeek,
                  targetWeekday: effectiveTargetWeekday,
                  targetStartPeriod: effectiveTargetStartPeriod,
                ),
          child: LoadingButtonLabel(
            isLoading: _isSaving,
            label: settingsProvider.t('save'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickTargetWeek(
    SettingsProvider provider, {
    required int selectedValue,
  }) async {
    final selected = await showAppOptionPicker<int>(
      context,
      title: provider.t('target_week'),
      selectedValue: selectedValue,
      grid: true,
      gridCrossAxisCount: 3,
      options: [
        for (int week = 1; week <= provider.totalWeeks; week++)
          AppPickerOption(value: week, label: _weekLabel(provider, week)),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _targetWeek = selected;
    });
  }

  Future<void> _pickTargetWeekday(
    SettingsProvider provider, {
    required int selectedValue,
  }) async {
    final selected = await showAppOptionPicker<int>(
      context,
      title: provider.t('target_weekday'),
      selectedValue: selectedValue,
      grid: true,
      gridCrossAxisCount: 2,
      options: [
        for (int day = 1; day <= 7; day++)
          AppPickerOption(value: day, label: _weekdayLabel(provider, day)),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _targetWeekday = selected;
    });
  }

  Future<void> _pickTargetStartPeriod(
    SettingsProvider provider, {
    required int selectedValue,
    required int maxStartPeriod,
  }) async {
    final selected = await showAppOptionPicker<int>(
      context,
      title: provider.t('target_start_period'),
      selectedValue: selectedValue,
      grid: true,
      gridCrossAxisCount: 3,
      options: [
        for (int period = 1; period <= maxStartPeriod; period++)
          AppPickerOption(value: period, label: _periodLabel(provider, period)),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _targetStartPeriod = selected;
    });
  }

  Future<void> _submit({
    required int periodCount,
    required int maxStartPeriod,
    required int targetWeek,
    required int targetWeekday,
    required int targetStartPeriod,
  }) async {
    final settingsProvider = context.read<SettingsProvider>();
    if (periodCount == 0 || maxStartPeriod < 1) {
      _showMessage(settingsProvider.t('invalid_reschedule_period_range'));
      return;
    }

    if (targetStartPeriod < 1 || targetStartPeriod > maxStartPeriod) {
      _showMessage(settingsProvider.t('invalid_reschedule_period_range'));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final didReschedule = await context
        .read<CourseProvider>()
        .rescheduleCourseOccurrence(
          originalCourse: widget.course,
          sourceWeek: widget.sourceWeek,
          targetWeek: targetWeek,
          targetWeekday: targetWeekday,
          targetStartPeriod: targetStartPeriod,
        );

    if (!mounted) {
      return;
    }

    if (!didReschedule) {
      setState(() {
        _isSaving = false;
      });
      _showMessage(settingsProvider.t('reschedule_unavailable'));
      return;
    }

    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) {
    showAppSnackBar(context, SnackBar(content: Text(message)));
  }

  int? _boundedStartPeriod(int value, int maxStartPeriod) {
    if (maxStartPeriod < 1) {
      return null;
    }
    if (value < 1) {
      return 1;
    }
    if (value > maxStartPeriod) {
      return maxStartPeriod;
    }
    return value;
  }

  String _weekLabel(SettingsProvider provider, int week) {
    return provider
        .t('week_label_format')
        .replaceAll('{week}', week.toString());
  }

  String _weekdayLabel(SettingsProvider provider, int weekday) {
    return provider.t(TimetableViewDataService.weekdayKeys[weekday - 1]);
  }

  String _periodLabel(SettingsProvider provider, int period) {
    if (provider.languageCode == 'zh') {
      return '\u7b2c $period \u8282';
    }
    return 'Period $period';
  }

  String _periodRangeLabel(SettingsProvider provider, int start, int end) {
    return provider
        .t('period_range_format')
        .replaceAll('{start}', start.toString())
        .replaceAll('{end}', end.toString());
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
