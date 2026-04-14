import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/native_alarm_service.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class TimetableTimeSettingsPage extends StatefulWidget {
  const TimetableTimeSettingsPage({super.key});

  @override
  State<TimetableTimeSettingsPage> createState() =>
      _TimetableTimeSettingsPageState();
}

class _TimetableTimeSettingsPageState extends State<TimetableTimeSettingsPage> {
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
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.date_range_outlined),
                    title: const Text('学期起始日期'),
                    subtitle: Text(_formatDate(provider.semesterStartDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _pickSemesterStartDate(context, provider),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.calendar_view_week_outlined),
                    title: const Text('上课周数'),
                    subtitle: Text('${provider.totalWeeks} 周'),
                    trailing: DropdownButton<int>(
                      value: provider.totalWeeks,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (int week = 12; week <= 30; week++)
                          DropdownMenuItem<int>(
                            value: week,
                            child: Text('$week'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _updateAndRefresh(
                            context,
                            provider,
                            () => provider.updateTotalWeeks(value),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Card(
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
                  ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('大课间发生在第几节课后'),
                    subtitle: Text('第 ${provider.bigBreakAfterPeriod} 节后'),
                    trailing: DropdownButton<int>(
                      value: provider.bigBreakAfterPeriod,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (int period = 1; period <= 6; period++)
                          DropdownMenuItem<int>(
                            value: period,
                            child: Text('第$period节后'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _updateAndRefresh(
                            context,
                            provider,
                            () => provider.updateBigBreakAfterPeriod(value),
                          );
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  _durationTile(
                    context: context,
                    icon: Icons.wb_sunny_outlined,
                    title: '大课间时长',
                    value: provider.bigBreak,
                    min: 5,
                    max: 60,
                    onChanged: (v) => _updateAndRefresh(
                      context,
                      provider,
                      () => provider.updateBigBreak(v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              Text('$value 分钟'),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (newValue) {
              onChanged(newValue.round());
            },
          ),
        ],
      ),
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
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
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
    await _refreshNativeAlarms(context, provider);
  }

  Future<void> _refreshNativeAlarms(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final courseProvider = context.read<CourseProvider>();
    await NativeAlarmService.instance.scheduleClasses(
      courses: courseProvider.courses.toList(),
      events: courseProvider.events.toList(),
      settings: provider,
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
