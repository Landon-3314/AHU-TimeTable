import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';

class AddCoursePage extends StatelessWidget {
  const AddCoursePage({
    super.key,
    this.existingCourse,
  });

  final Course? existingCourse;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final isEditMode = existingCourse != null;

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
          children: [
            _CourseForm(existingCourse: existingCourse),
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
  });

  final Course? existingCourse;

  @override
  State<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends State<_CourseForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _teacherController = TextEditingController();

  static const List<int> _presetColors = [
    0xFF7C9AF2,
    0xFF5DC5B8,
    0xFFF3A76F,
    0xFFE98BB2,
    0xFF9A8CF2,
    0xFF7FCB72,
  ];

  int _selectedWeekday = 1;
  int _selectedColorValue = _presetColors.first;
  int _selectedStartPeriod = 1;
  int _selectedEndPeriod = 2;
  bool _isSaving = false;
  late final Set<int> _selectedWeeks;

  bool get _isEditMode => widget.existingCourse != null;

  @override
  void initState() {
    super.initState();
    final course = widget.existingCourse;
    _selectedWeeks = course == null ? <int>{1} : course.weeks.toSet();

    if (course != null) {
      _nameController.text = course.name;
      _locationController.text = course.location;
      _teacherController.text = course.teacher;
      _selectedWeekday = course.weekday;
      _selectedColorValue = course.colorValue;
      _selectedStartPeriod = course.startPeriod;
      _selectedEndPeriod = course.endPeriod;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: provider.t('course_name'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return provider.t('please_enter_course_name');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: provider.t('location'),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return provider.t('please_enter_location');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teacherController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: provider.t('teacher'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedWeekday,
                decoration: InputDecoration(
                  labelText: provider.t('weekday_label'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (int day = 1; day <= 7; day++)
                    DropdownMenuItem(
                      value: day,
                      child: Text(_weekdayLabel(provider, day)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedWeekday = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                provider.t('teaching_weeks'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int week = 1; week <= provider.totalWeeks; week++)
                    FilterChip(
                      label: Text(_weekLabel(provider, week)),
                      selected: _selectedWeeks.contains(week),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedWeeks.add(week);
                          } else {
                            _selectedWeeks.remove(week);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: currentStartValue,
                      decoration: InputDecoration(
                        labelText: provider.t('start_period'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (int period = 1; period <= effectivePeriodCount; period++)
                          DropdownMenuItem<int>(
                            value: period,
                            child: Text(_periodLabel(provider, period)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedStartPeriod = value;
                            if (_selectedEndPeriod < value) {
                              _selectedEndPeriod = value;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: currentEndValue,
                      decoration: InputDecoration(
                        labelText: provider.t('end_period'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (int period = 1; period <= effectivePeriodCount; period++)
                          DropdownMenuItem<int>(
                            value: period,
                            child: Text(_periodLabel(provider, period)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedEndPeriod = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                provider.t('card_color'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _presetColors.map((colorValue) {
                  final isSelected = colorValue == _selectedColorValue;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColorValue = colorValue;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: FilledButton(
          onPressed: _isSaving ? null : () => _saveCourse(periodCount),
          child: Text(
            _isSaving
                ? provider.t('saving')
                : (_isEditMode ? provider.t('save_changes') : provider.t('save')),
          ),
        ),
      ),
    );
  }

  Future<void> _saveCourse(int periodCount) async {
    final provider = context.read<SettingsProvider>();
    if (!_formKey.currentState!.validate()) {
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

    setState(() {
      _isSaving = true;
    });

    final course = Course(
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
      teacher: _teacherController.text.trim(),
      weekday: _selectedWeekday,
      weeks: _selectedWeeks.toList()..sort(),
      startPeriod: _selectedStartPeriod,
      endPeriod: _selectedEndPeriod,
      colorValue: _selectedColorValue,
    );

    final courseProvider = context.read<CourseProvider>();
    if (_isEditMode) {
      await courseProvider.updateCourse(
        originalCourse: widget.existingCourse!,
        updatedCourse: course,
      );
    } else {
      await courseProvider.addCourse(course);
    }

    if (!mounted) {
      return;
    }

    _showMessage(provider.t(_isEditMode ? 'course_updated' : 'course_added'));
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  DateTime? _selectedDateTime;
  bool _enableAlarm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    const sharedDecoration = InputDecoration(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: sharedDecoration.copyWith(
                  labelText: provider.t('location'),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
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
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(4),
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: FilledButton(
          onPressed: _isSaving ? null : _saveEvent,
          child: Text(_isSaving ? provider.t('saving') : provider.t('save')),
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
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
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
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      location: _locationController.text.trim(),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}/$month/$day $hour:$minute';
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

