import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../models/clock_time.dart';
import '../models/time_slot.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class PeriodStartTimeSettingsPage extends StatefulWidget {
  const PeriodStartTimeSettingsPage({super.key});

  @override
  State<PeriodStartTimeSettingsPage> createState() =>
      _PeriodStartTimeSettingsPageState();
}

class _PeriodStartTimeSettingsPageState
    extends State<PeriodStartTimeSettingsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final slots = provider.timeSlots;

    return Scaffold(
      appBar: AppBar(title: const Text('每节课起始时间')),
      body: LongScreenshotScrollCapture(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: AppSpacing.pagePadding,
          children: [
            _SessionStartTimeSection(
              title: '上午',
              emptyText: '上午未设置课程节次',
              slots: _slotsForLabel(slots, 'Morning'),
              onChanged: (index, value) => _updateStartTime(
                context,
                provider,
                ClassDayPeriod.morning,
                index,
                value,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SessionStartTimeSection(
              title: '下午',
              emptyText: '下午未设置课程节次',
              slots: _slotsForLabel(slots, 'Afternoon'),
              onChanged: (index, value) => _updateStartTime(
                context,
                provider,
                ClassDayPeriod.afternoon,
                index,
                value,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SessionStartTimeSection(
              title: '晚上',
              emptyText: '晚上未设置课程节次',
              slots: _slotsForLabel(slots, 'Evening'),
              onChanged: (index, value) => _updateStartTime(
                context,
                provider,
                ClassDayPeriod.evening,
                index,
                value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TimeSlot> _slotsForLabel(List<TimeSlot> slots, String label) {
    return slots.where((slot) => slot.label == label).toList(growable: false);
  }

  Future<void> _updateStartTime(
    BuildContext context,
    SettingsProvider provider,
    ClassDayPeriod period,
    int index,
    TimeOfDay value,
  ) async {
    await provider.updatePeriodStartTime(period, index, value);
    if (!context.mounted) {
      return;
    }

    final courseProvider = context.read<CourseProvider>();
    await AppServices.refreshSchedules(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      settings: provider,
    );
  }
}

class _SessionStartTimeSection extends StatelessWidget {
  const _SessionStartTimeSection({
    required this.title,
    required this.emptyText,
    required this.slots,
    required this.onChanged,
  });

  final String title;
  final String emptyText;
  final List<TimeSlot> slots;
  final Future<void> Function(int index, TimeOfDay value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionTitle(title: title, subtitle: '${slots.length} 节课'),
        AppSurface(
          child: slots.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(emptyText),
                )
              : Column(
                  children: [
                    for (var index = 0; index < slots.length; index++) ...[
                      if (index > 0) const Divider(height: 1),
                      _PeriodStartTimeTile(
                        slot: slots[index],
                        onTap: () => _pickTime(context, index, slots[index]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context, int index, TimeSlot slot) async {
    final result = await showTimePicker(
      context: context,
      initialTime: _toTimeOfDay(slot.startTime),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (result != null) {
      await onChanged(index, result);
    }
  }

  TimeOfDay _toTimeOfDay(ClockTime time) {
    return TimeOfDay(
      hour: time.hour.clamp(0, 23).toInt(),
      minute: time.minute.clamp(0, 59).toInt(),
    );
  }
}

class _PeriodStartTimeTile extends StatelessWidget {
  const _PeriodStartTimeTile({required this.slot, required this.onTap});

  final TimeSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppActionTile(
      icon: Icons.access_time_outlined,
      title: '第 ${slot.periodNumber} 节',
      subtitle:
          '${slot.startTime.format24Hour()} - ${slot.endTime.format24Hour()}',
      onTap: onTap,
    );
  }
}
