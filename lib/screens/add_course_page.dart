import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../core/app_theme_tokens.dart';
import '../models/course.dart';
import '../models/event.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/app_wheel_pickers.dart';
import '../widgets/common/capsule_multi_select.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class AddCoursePage extends StatefulWidget {
  const AddCoursePage({super.key, this.existingCourse});

  final Course? existingCourse;

  @override
  State<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  bool _isWeekDragSelectionActive = false;

  void _setWeekDragSelectionActive(bool value) {
    if (_isWeekDragSelectionActive == value) {
      return;
    }
    setState(() {
      _isWeekDragSelectionActive = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: provider.t('add_course')),
              Tab(text: provider.t('add_event')),
            ],
          ),
        ),
        body: TabBarView(
          physics: _isWeekDragSelectionActive
              ? const NeverScrollableScrollPhysics()
              : null,
          children: [
            _CourseForm(
              existingCourse: widget.existingCourse,
              weekDragSelectionActive: _isWeekDragSelectionActive,
              onWeekDragSelectionActiveChanged: _setWeekDragSelectionActive,
            ),
            const _EventForm(),
          ],
        ),
      ),
    );
  }
}

class _CourseForm extends StatefulWidget {
  const _CourseForm({
    this.existingCourse,
    required this.weekDragSelectionActive,
    required this.onWeekDragSelectionActiveChanged,
  });

  final Course? existingCourse;
  final bool weekDragSelectionActive;
  final ValueChanged<bool> onWeekDragSelectionActiveChanged;

  @override
  State<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<_CourseForm>
    with AutomaticKeepAliveClientMixin<_CourseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _teacherController = TextEditingController();

  static const List<int> _presetColors = AppColors.coursePaletteValues;

  int _selectedColorValue = _presetColors.first;
  int _selectedStartPeriod = 1;
  int _selectedEndPeriod = 2;
  bool _isSaving = false;
  late final Set<int> _selectedWeekdays;
  late final Set<int> _selectedWeeks;

  bool get _isEditMode => widget.existingCourse != null;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final course = widget.existingCourse;
    _selectedWeekdays = course == null ? <int>{1} : <int>{course.weekday};
    _selectedWeeks = course == null ? <int>{1} : course.weeks.toSet();

    if (course != null) {
      _nameController.text = course.name;
      _locationController.text = course.location;
      _teacherController.text = course.teacher;
      _selectedColorValue = course.colorValue;
      _selectedStartPeriod = course.startPeriod;
      _selectedEndPeriod = course.endPeriod;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<SettingsProvider>();
    final tokens = appThemeTokensOf(context);
    final periodCount = provider.timeSlots.length;
    final effectivePeriodCount = periodCount == 0 ? 1 : periodCount;
    final currentStartValue = _boundedPeriod(
      _selectedStartPeriod,
      effectivePeriodCount,
    );
    final currentEndValue = _boundedPeriod(
      _selectedEndPeriod < currentStartValue
          ? currentStartValue
          : _selectedEndPeriod,
      effectivePeriodCount,
    );

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LongScreenshotScrollCapture(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              physics: widget.weekDragSelectionActive
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: AppSpacing.pagePadding,
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: provider.t('course_name'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return provider.t('please_enter_course_name');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: provider.t('location'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return provider.t('please_enter_location');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _teacherController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: provider.t('teacher')),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  provider.t('weekday_label'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CapsuleMultiSelect<int>(
                  options: [
                    for (int day = 1; day <= 7; day++)
                      CapsuleMultiSelectOption<int>(
                        value: day,
                        label: _weekdayLabel(provider, day),
                      ),
                  ],
                  selectedValues: _selectedWeekdays,
                  singleLine: true,
                  onChanged: _handleWeekdaysChanged,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  provider.t('teaching_weeks'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(72, 44),
                        ),
                        onPressed: () => _replaceSelectedWeeks(
                          Iterable<int>.generate(
                            provider.totalWeeks,
                            (index) => index + 1,
                          ),
                        ),
                        child: Text(provider.t('select_all')),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(72, 44),
                        ),
                        onPressed: () => _replaceSelectedWeeks(const <int>[]),
                        child: Text(provider.t('clear_selection')),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(72, 44),
                        ),
                        onPressed: () => _replaceSelectedWeeks(
                          Iterable<int>.generate(
                            provider.totalWeeks,
                            (index) => index + 1,
                          ).where((week) => week.isOdd),
                        ),
                        child: Text(provider.t('odd_weeks')),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(72, 44),
                        ),
                        onPressed: () => _replaceSelectedWeeks(
                          Iterable<int>.generate(
                            provider.totalWeeks,
                            (index) => index + 1,
                          ).where((week) => week.isEven),
                        ),
                        child: Text(provider.t('even_weeks')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CapsuleMultiSelect<int>(
                  key: const ValueKey('teaching-week-selector'),
                  options: [
                    for (int week = 1; week <= provider.totalWeeks; week++)
                      CapsuleMultiSelectOption<int>(
                        value: week,
                        label: _weekLabel(provider, week),
                      ),
                  ],
                  selectedValues: _selectedWeeks,
                  enableDragSelect: true,
                  onDragSelectionActiveChanged:
                      widget.onWeekDragSelectionActiveChanged,
                  onChanged: (selectedWeeks) {
                    setState(() {
                      _selectedWeeks
                        ..clear()
                        ..addAll(selectedWeeks);
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: AppPickerField(
                        label: provider.t('start_period'),
                        valueLabel: _periodLabel(provider, currentStartValue),
                        onTap: () => _pickPeriod(
                          provider: provider,
                          title: provider.t('start_period'),
                          selectedValue: currentStartValue,
                          maxPeriod: effectivePeriodCount,
                          onSelected: (value) {
                            _selectedStartPeriod = value;
                            if (_selectedEndPeriod < value) {
                              _selectedEndPeriod = value;
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppPickerField(
                        label: provider.t('end_period'),
                        valueLabel: _periodLabel(provider, currentEndValue),
                        onTap: () => _pickPeriod(
                          provider: provider,
                          title: provider.t('end_period'),
                          selectedValue: currentEndValue,
                          maxPeriod: effectivePeriodCount,
                          onSelected: (value) {
                            _selectedEndPeriod = value;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  provider.t('card_color'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: _presetColors.indexed.map((entry) {
                    final index = entry.$1;
                    final colorValue = entry.$2;
                    final isSelected = colorValue == _selectedColorValue;
                    return Semantics(
                      key: ValueKey('course-color-$index'),
                      button: true,
                      selected: isSelected,
                      label:
                          '颜色 ${index + 1}，${AppColors.colorName(colorValue)}',
                      child: InkResponse(
                        onTap: () {
                          setState(() {
                            _selectedColorValue = colorValue;
                          });
                        },
                        radius: 28,
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? tokens.textPrimary
                                  : tokens.surface,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  colorValue,
                                ).withValues(alpha: 0.24),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: bestContrastingForeground(
                                    Color(colorValue),
                                  ),
                                  size: 20,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.formBottomSafeArea),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.actionBarPadding,
        child: FilledButton(
          onPressed: _isSaving ? null : () => _saveCourse(periodCount),
          child: LoadingButtonLabel(
            isLoading: _isSaving,
            label: _isEditMode
                ? provider.t('save_changes')
                : provider.t('save'),
          ),
        ),
      ),
    );
  }

  void _handleWeekdaysChanged(Set<int> selectedWeekdays) {
    if (_isEditMode && selectedWeekdays.isEmpty) {
      return;
    }

    final nextWeekdays = _isEditMode
        ? _singleEditWeekdaySelection(selectedWeekdays)
        : selectedWeekdays;

    setState(() {
      _selectedWeekdays
        ..clear()
        ..addAll(nextWeekdays);
    });
  }

  void _replaceSelectedWeeks(Iterable<int> weeks) {
    setState(() {
      _selectedWeeks
        ..clear()
        ..addAll(weeks);
    });
  }

  Set<int> _singleEditWeekdaySelection(Set<int> selectedWeekdays) {
    final newlySelected = selectedWeekdays.difference(_selectedWeekdays);
    if (newlySelected.isNotEmpty) {
      return {newlySelected.first};
    }
    return {selectedWeekdays.first};
  }

  Future<void> _pickPeriod({
    required SettingsProvider provider,
    required String title,
    required int selectedValue,
    required int maxPeriod,
    required ValueChanged<int> onSelected,
  }) async {
    final selected = await showAppOptionPicker<int>(
      context,
      title: title,
      selectedValue: selectedValue,
      grid: true,
      gridCrossAxisCount: 3,
      options: [
        for (int period = 1; period <= maxPeriod; period++)
          AppPickerOption(value: period, label: _periodLabel(provider, period)),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      onSelected(selected);
    });
  }

  Future<void> _saveCourse(int periodCount) async {
    final provider = context.read<SettingsProvider>();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedWeekdays.isEmpty) {
      _showMessage(provider.t('please_select_weekday'));
      return;
    }

    if (_selectedWeeks.isEmpty) {
      _showMessage(provider.t('please_select_teaching_week'));
      return;
    }

    if (periodCount == 0) {
      _showMessage(provider.t('configure_periods_first'));
      return;
    }

    if (_selectedStartPeriod < 1 || _selectedEndPeriod > periodCount) {
      _showMessage(provider.t('selected_periods_out_of_range'));
      return;
    }

    if (_selectedEndPeriod < _selectedStartPeriod) {
      _showMessage(provider.t('end_period_invalid'));
      return;
    }

    final selectedWeeks = _selectedWeeks.toList()..sort();
    final selectedWeekdays = _selectedWeekdays.toList()..sort();
    Course buildCourse(int weekday, {String? id}) {
      return Course(
        id: id,
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        teacher: _teacherController.text.trim(),
        weekday: weekday,
        weeks: selectedWeeks,
        startPeriod: _selectedStartPeriod,
        endPeriod: _selectedEndPeriod,
        colorValue: _selectedColorValue,
      );
    }

    final courseProvider = context.read<CourseProvider>();
    final candidateCourses = _isEditMode
        ? [buildCourse(selectedWeekdays.first, id: widget.existingCourse!.id)]
        : [for (final weekday in selectedWeekdays) buildCourse(weekday)];
    final conflicts = courseProvider.findCourseConflicts(
      candidateCourses,
      ignoredCourseId: widget.existingCourse?.id,
    );
    var allowConflicts = false;
    if (conflicts.isNotEmpty) {
      allowConflicts = await showCourseConflictConfirmDialog(
        context,
        conflicts: conflicts,
      );
      if (!mounted || !allowConflicts) {
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    final didSave = _isEditMode
        ? await courseProvider.updateCourse(
            originalCourse: widget.existingCourse!,
            updatedCourse: candidateCourses.single,
            allowConflicts: allowConflicts,
          )
        : (await courseProvider.addCourses(
                candidateCourses,
                allowConflicts: allowConflicts,
              )) >
              0;

    if (!mounted) {
      return;
    }

    if (!didSave) {
      setState(() {
        _isSaving = false;
      });
      _showMessage(provider.t('duplicate_course_not_added'));
      return;
    }

    _showMessage(provider.t(_isEditMode ? 'course_updated' : 'course_added'));
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    showAppSnackBar(context, SnackBar(content: Text(message)));
  }

  int _boundedPeriod(int value, int max) {
    if (value < 1) {
      return 1;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  String _weekdayLabel(SettingsProvider provider, int day) {
    const keys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return provider.t(keys[day - 1]);
  }

  String _weekLabel(SettingsProvider provider, int week) {
    if (provider.languageCode == 'zh') {
      return '第 $week 周';
    }
    return 'Week $week';
  }

  String _periodLabel(SettingsProvider provider, int period) {
    if (provider.languageCode == 'zh') {
      return '第 $period 节';
    }
    return 'Period $period';
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm();

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _enableAlarm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    const sharedDecoration = InputDecoration(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LongScreenshotScrollCapture(
            controller: _scrollController,
            child: ListView(
              controller: _scrollController,
              padding: AppSpacing.pagePadding,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: sharedDecoration.copyWith(
                    labelText: provider.t('event_name'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return provider.t('please_enter_event_name');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _locationController,
                  decoration: sharedDecoration.copyWith(
                    labelText: provider.t('location'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 2,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: sharedDecoration.copyWith(
                    labelText: provider.t('note'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: InputDecorator(
                    decoration: sharedDecoration.copyWith(
                      labelText: provider.t('date'),
                    ),
                    child: Text(
                      _selectedDateTime == null
                          ? provider.t('select_date')
                          : _formatDate(_selectedDateTime!),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: InputDecorator(
                    decoration: sharedDecoration.copyWith(
                      labelText: provider.t('time'),
                    ),
                    child: Text(
                      _selectedDateTime == null
                          ? provider.t('select_time')
                          : _formatTime(_selectedDateTime!),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(provider.t('enable_alarm_reminder')),
                  value: _enableAlarm,
                  onChanged: (value) {
                    setState(() {
                      _enableAlarm = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.formBottomSafeArea),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: AppSpacing.actionBarPadding,
        child: FilledButton(
          onPressed: _isSaving ? null : _saveEvent,
          child: LoadingButtonLabel(
            isLoading: _isSaving,
            label: provider.t('save'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final current = _selectedDateTime ?? now;
    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        current.hour,
        current.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final base = _selectedDateTime ?? now;
    final provider = context.read<SettingsProvider>();
    final pickedTime = await showAppClockTimePicker(
      context,
      initialTime: TimeOfDay.fromDateTime(base),
      title: provider.t('time'),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _selectedDateTime = DateTime(
        base.year,
        base.month,
        base.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _saveEvent() async {
    final provider = context.read<SettingsProvider>();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDateTime == null) {
      _showMessage(provider.t('please_select_date_time'));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final event = Event(
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      note: _noteController.text.trim(),
      dateTime: _selectedDateTime!,
      enableAlarm: _enableAlarm,
    );

    await context.read<CourseProvider>().addEvent(event);

    if (!mounted) {
      return;
    }

    _showMessage(provider.t('event_added'));
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    showAppSnackBar(context, SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}/$month/$day';
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
