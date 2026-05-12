import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';

class AppWheelPickerOption<T> {
  const AppWheelPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

enum AppWheelPickerItemStyle { large, compact }

class AppWheelScrollPhysics extends FixedExtentScrollPhysics {
  const AppWheelScrollPhysics({super.parent});

  static const double maxPickerFlingVelocity = 1800;
  static const double maxCarriedMomentum = 360;

  @override
  double get maxFlingVelocity => maxPickerFlingVelocity;

  @override
  double carriedMomentum(double existingVelocity) {
    final capped = math.min(existingVelocity.abs() * 0.08, maxCarriedMomentum);
    return existingVelocity.sign * capped;
  }

  @override
  AppWheelScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return AppWheelScrollPhysics(parent: buildParent(ancestor));
  }
}

Future<TimeOfDay?> showAppClockTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String title = '选择时间',
}) {
  return _showWheelPickerSheet<TimeOfDay>(
    context,
    child: _ClockTimeWheelSheet(initialTime: initialTime, title: title),
  );
}

Future<int?> showCourseReminderAdvancePicker(
  BuildContext context, {
  required int initialMinutes,
  String title = '提前提醒时间',
}) {
  return _showWheelPickerSheet<int>(
    context,
    child: _ReminderAdvanceWheelSheet(
      title: title,
      initialMinutes: initialMinutes,
      maxMinutes: 23 * 60 + 59,
      showDays: false,
    ),
  );
}

Future<int?> showEventReminderAdvancePicker(
  BuildContext context, {
  required int initialMinutes,
  String title = '日程提前提醒时间',
}) {
  return _showWheelPickerSheet<int>(
    context,
    child: _ReminderAdvanceWheelSheet(
      title: title,
      initialMinutes: initialMinutes,
      maxMinutes: 7 * 24 * 60 + 23 * 60 + 59,
      showDays: true,
    ),
  );
}

Future<T?> showAppWheelValuePicker<T>(
  BuildContext context, {
  required String title,
  required List<AppWheelPickerOption<T>> options,
  required T selectedValue,
}) {
  if (options.isEmpty) {
    return Future<T?>.value();
  }
  return _showWheelPickerSheet<T>(
    context,
    child: _ValueWheelSheet<T>(
      title: title,
      options: options,
      selectedValue: selectedValue,
    ),
  );
}

Future<T?> _showWheelPickerSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: child,
      );
    },
  );
}

class _ClockTimeWheelSheet extends StatefulWidget {
  const _ClockTimeWheelSheet({required this.initialTime, required this.title});

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_ClockTimeWheelSheet> createState() => _ClockTimeWheelSheetState();
}

class _ClockTimeWheelSheetState extends State<_ClockTimeWheelSheet> {
  late int _periodIndex;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _periodIndex = widget.initialTime.hour >= 12 ? 1 : 0;
    _hour = widget.initialTime.hour % 12;
    _minute = widget.initialTime.minute.clamp(0, 59).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return _WheelSheetScaffold(
      title: widget.title,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        final hour = _periodIndex == 0 ? _hour : _hour + 12;
        Navigator.of(context).pop(TimeOfDay(hour: hour, minute: _minute));
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _WheelColumnLabels(labels: ['', '时', '分']),
          SizedBox(
            height: _WheelMetrics.pickerHeight,
            child: Row(
              children: [
                Expanded(
                  child: AppWheelPicker<String>(
                    values: const ['上午', '下午'],
                    selectedIndex: _periodIndex,
                    looping: false,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _periodIndex = index;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: AppWheelPicker<int>(
                    values: List<int>.generate(12, (index) => index),
                    selectedIndex: _hour,
                    labelBuilder: _twoDigits,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _hour = index;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: AppWheelPicker<int>(
                    values: List<int>.generate(60, (index) => index),
                    selectedIndex: _minute,
                    labelBuilder: _twoDigits,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _minute = index;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderAdvanceWheelSheet extends StatefulWidget {
  const _ReminderAdvanceWheelSheet({
    required this.title,
    required this.initialMinutes,
    required this.maxMinutes,
    required this.showDays,
  });

  final String title;
  final int initialMinutes;
  final int maxMinutes;
  final bool showDays;

  @override
  State<_ReminderAdvanceWheelSheet> createState() =>
      _ReminderAdvanceWheelSheetState();
}

class _ReminderAdvanceWheelSheetState
    extends State<_ReminderAdvanceWheelSheet> {
  late int _days;
  late int _hours;
  late int _minutes;

  int get _totalMinutes => _days * 24 * 60 + _hours * 60 + _minutes;

  @override
  void initState() {
    super.initState();
    final safeMinutes = widget.initialMinutes
        .clamp(1, widget.maxMinutes)
        .toInt();
    _days = widget.showDays ? safeMinutes ~/ (24 * 60) : 0;
    final remaining = widget.showDays ? safeMinutes % (24 * 60) : safeMinutes;
    _hours = remaining ~/ 60;
    _minutes = remaining % 60;
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.showDays ? ['天', '时', '分'] : ['时', '分'];
    return _WheelSheetScaffold(
      title: widget.title,
      confirmEnabled: _totalMinutes > 0,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        if (_totalMinutes <= 0) {
          return;
        }
        Navigator.of(
          context,
        ).pop(_totalMinutes.clamp(1, widget.maxMinutes).toInt());
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WheelColumnLabels(labels: labels),
          SizedBox(
            height: _WheelMetrics.pickerHeight,
            child: Row(
              children: [
                if (widget.showDays)
                  Expanded(
                    child: AppWheelPicker<int>(
                      values: List<int>.generate(8, (index) => index),
                      selectedIndex: _days,
                      labelBuilder: _twoDigits,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _days = index;
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: AppWheelPicker<int>(
                    values: List<int>.generate(24, (index) => index),
                    selectedIndex: _hours,
                    labelBuilder: _twoDigits,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _hours = index;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: AppWheelPicker<int>(
                    values: List<int>.generate(60, (index) => index),
                    selectedIndex: _minutes,
                    labelBuilder: _twoDigits,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _minutes = index;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueWheelSheet<T> extends StatefulWidget {
  const _ValueWheelSheet({
    required this.title,
    required this.options,
    required this.selectedValue,
  });

  final String title;
  final List<AppWheelPickerOption<T>> options;
  final T selectedValue;

  @override
  State<_ValueWheelSheet<T>> createState() => _ValueWheelSheetState<T>();
}

class _ValueWheelSheetState<T> extends State<_ValueWheelSheet<T>> {
  late int _selectedIndex;

  AppWheelPickerOption<T> get _selectedOption => widget.options[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.options.indexWhere(
      (option) => option.value == widget.selectedValue,
    );
    if (_selectedIndex < 0) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WheelSheetScaffold(
      title: widget.title,
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () => Navigator.of(context).pop(_selectedOption.value),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _WheelMetrics.pickerHeight,
            child: AppWheelPicker<AppWheelPickerOption<T>>(
              values: widget.options,
              selectedIndex: _selectedIndex,
              looping: false,
              itemStyle: AppWheelPickerItemStyle.compact,
              labelBuilder: (option) => option.label,
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            child: _selectedOption.subtitle == null
                ? const SizedBox(height: 24)
                : Padding(
                    key: ValueKey<String>(_selectedOption.subtitle!),
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      _selectedOption.subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WheelSheetScaffold extends StatelessWidget {
  const _WheelSheetScaffold({
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onConfirm,
    this.confirmEnabled = true,
  });

  final String title;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            TextButton(onPressed: onCancel, child: const Text('取消')),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: confirmEnabled ? onConfirm : null,
              child: const Text('确定'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _WheelColumnLabels extends StatelessWidget {
  const _WheelColumnLabels({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppWheelPicker<T> extends StatefulWidget {
  const AppWheelPicker({
    super.key,
    required this.values,
    required this.selectedIndex,
    required this.onSelectedItemChanged,
    this.labelBuilder,
    this.looping = true,
    this.itemStyle = AppWheelPickerItemStyle.large,
  });

  final List<T> values;
  final int selectedIndex;
  final ValueChanged<int> onSelectedItemChanged;
  final String Function(T value)? labelBuilder;
  final bool looping;
  final AppWheelPickerItemStyle itemStyle;

  @override
  State<AppWheelPicker<T>> createState() => _AppWheelPickerState<T>();
}

class _AppWheelPickerState<T> extends State<AppWheelPicker<T>> {
  static const int _loopBase = 1000;
  late FixedExtentScrollController _controller;
  late int _lastReportedIndex;

  int get _initialItem {
    if (!widget.looping || widget.values.isEmpty) {
      return widget.selectedIndex;
    }
    return widget.values.length * _loopBase + widget.selectedIndex;
  }

  @override
  void initState() {
    super.initState();
    _lastReportedIndex = widget.selectedIndex;
    _controller = FixedExtentScrollController(initialItem: _initialItem);
  }

  @override
  void didUpdateWidget(covariant AppWheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structureChanged =
        oldWidget.values.length != widget.values.length ||
        oldWidget.looping != widget.looping;
    if (structureChanged) {
      _controller.jumpToItem(_initialItem);
      _lastReportedIndex = widget.selectedIndex;
      return;
    }

    final selectedExternally =
        oldWidget.selectedIndex != widget.selectedIndex &&
        widget.selectedIndex != _lastReportedIndex;
    if (selectedExternally) {
      _animateToLogicalIndex(widget.selectedIndex);
      _lastReportedIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            height: _WheelMetrics.itemExtent,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: _controller,
          itemExtent: _WheelMetrics.itemExtent,
          physics: const AppWheelScrollPhysics(),
          perspective: 0.002,
          diameterRatio: 1.55,
          overAndUnderCenterOpacity: 1,
          onSelectedItemChanged: (rawIndex) {
            final index = widget.values.isEmpty
                ? 0
                : rawIndex.remainder(widget.values.length);
            _lastReportedIndex = index;
            widget.onSelectedItemChanged(index);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.looping ? null : widget.values.length,
            builder: (context, rawIndex) {
              if (rawIndex < 0 || widget.values.isEmpty) {
                return null;
              }
              final index = rawIndex.remainder(widget.values.length);
              final value = widget.values[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _animateToRawIndex(rawIndex),
                child: _WheelPickerItem(
                  index: index,
                  selectedIndex: widget.selectedIndex,
                  itemCount: widget.values.length,
                  label: widget.labelBuilder?.call(value) ?? value.toString(),
                  itemStyle: widget.itemStyle,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _animateToRawIndex(int rawIndex) {
    return _controller.animateToItem(
      rawIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _animateToLogicalIndex(int index) {
    if (!widget.looping || widget.values.isEmpty || !_controller.hasClients) {
      return _animateToRawIndex(index);
    }
    return _animateToRawIndex(_nearestRawIndexFor(index));
  }

  int _nearestRawIndexFor(int index) {
    final itemCount = widget.values.length;
    final current = _controller.selectedItem;
    final base = current - current.remainder(itemCount);
    final candidates = <int>[
      base + index,
      base + index - itemCount,
      base + index + itemCount,
    ];
    candidates.sort(
      (left, right) =>
          (left - current).abs().compareTo((right - current).abs()),
    );
    return candidates.first;
  }
}

class _WheelPickerItem extends StatelessWidget {
  const _WheelPickerItem({
    required this.index,
    required this.selectedIndex,
    required this.itemCount,
    required this.label,
    required this.itemStyle,
  });

  final int index;
  final int selectedIndex;
  final int itemCount;
  final String label;
  final AppWheelPickerItemStyle itemStyle;

  @override
  Widget build(BuildContext context) {
    final distance = _wheelDistance(index, selectedIndex, itemCount);
    final opacity = switch (distance) {
      0 => 1.0,
      1 => 0.48,
      _ => 0.14,
    };
    final fontSize = _fontSizeForDistance(distance);
    return Center(
      child: AnimatedDefaultTextStyle(
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        style: TextStyle(
          color: AppColors.textPrimary.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: distance == 0 ? FontWeight.w800 : FontWeight.w700,
          height: 1,
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.visible),
      ),
    );
  }

  double _fontSizeForDistance(int distance) {
    return switch (itemStyle) {
      AppWheelPickerItemStyle.large => switch (distance) {
        0 => 48.0,
        1 => 39.0,
        _ => 31.0,
      },
      AppWheelPickerItemStyle.compact => switch (distance) {
        0 => 28.0,
        1 => 23.0,
        _ => 19.0,
      },
    };
  }
}

class _WheelMetrics {
  const _WheelMetrics._();

  static const double itemExtent = 72;
  static const double pickerHeight = itemExtent * 5;
}

int _wheelDistance(int index, int selectedIndex, int itemCount) {
  final direct = (index - selectedIndex).abs();
  return direct > itemCount / 2 ? itemCount - direct : direct;
}

String _twoDigits(Object value) {
  return (value as int).toString().padLeft(2, '0');
}
