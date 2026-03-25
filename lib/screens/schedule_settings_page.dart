import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

class ScheduleSettingsPage extends StatelessWidget {
  const ScheduleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(provider.t('schedule_time_settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SettingsSection(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.t('timeline_density'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${provider.pixelsPerMinute.toStringAsFixed(1)} px / ${provider.t('minutes_suffix')}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                    Slider(
                      value: provider.pixelsPerMinute,
                      min: 0.6,
                      max: 2.0,
                      divisions: 14,
                      label:
                          '${provider.pixelsPerMinute.toStringAsFixed(1)} px/${provider.t('minutes_suffix')}',
                      onChanged: provider.updatePixelsPerMinute,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsSection(
              child: Column(
                children: [
                  _SliderSettingTile(
                    title: provider.t('class_duration'),
                    value: provider.classDuration,
                    min: 30,
                    max: 60,
                    unit: provider.t('minutes_suffix'),
                    onChanged: provider.updateClassDuration,
                  ),
                  const Divider(height: 1),
                  _SliderSettingTile(
                    title: provider.t('short_break'),
                    value: provider.shortBreak,
                    min: 0,
                    max: 20,
                    unit: provider.t('minutes_suffix'),
                    onChanged: provider.updateShortBreak,
                  ),
                  const Divider(height: 1),
                  _SliderSettingTile(
                    title: provider.t('big_break'),
                    value: provider.bigBreak,
                    min: 10,
                    max: 30,
                    unit: provider.t('minutes_suffix'),
                    onChanged: provider.updateBigBreak,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SessionSection(
              title: provider.t('morning'),
              startTime: provider.morningStartTime,
              classCount: provider.morningClasses,
              onTimeChanged: provider.updateMorningStartTime,
              onCountChanged: provider.updateMorningClasses,
              maxClasses: 8,
            ),
            const SizedBox(height: 16),
            _SessionSection(
              title: provider.t('afternoon'),
              startTime: provider.afternoonStartTime,
              classCount: provider.afternoonClasses,
              onTimeChanged: provider.updateAfternoonStartTime,
              onCountChanged: provider.updateAfternoonClasses,
              maxClasses: 8,
            ),
            const SizedBox(height: 16),
            _SessionSection(
              title: provider.t('evening'),
              startTime: provider.eveningStartTime,
              classCount: provider.eveningClasses,
              onTimeChanged: provider.updateEveningStartTime,
              onCountChanged: provider.updateEveningClasses,
              maxClasses: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSection extends StatelessWidget {
  const _SessionSection({
    required this.title,
    required this.startTime,
    required this.classCount,
    required this.onTimeChanged,
    required this.onCountChanged,
    required this.maxClasses,
  });

  final String title;
  final TimeOfDay startTime;
  final int classCount;
  final Future<void> Function(TimeOfDay value) onTimeChanged;
  final Future<void> Function(int value) onCountChanged;
  final int maxClasses;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SettingsProvider>();

    return _SettingsSection(
      child: Column(
        children: [
          ListTile(
            title: Text('$title ${provider.t('session_start')}'),
            subtitle: Text(_formatTime(startTime)),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              final result = await showTimePicker(
                context: context,
                initialTime: startTime,
              );
              if (result != null) {
                await onTimeChanged(result);
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: Text('$title ${provider.t('session_classes')}'),
            subtitle: Text('$classCount ${provider.t('period_count')}'),
            trailing: DropdownButton<int>(
              value: classCount,
              underline: const SizedBox.shrink(),
              items: [
                for (int count = 0; count <= maxClasses; count++)
                  DropdownMenuItem<int>(value: count, child: Text('$count')),
              ],
              onChanged: (newValue) {
                if (newValue != null) {
                  onCountChanged(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _SliderSettingTile extends StatelessWidget {
  const _SliderSettingTile({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final String unit;
  final Future<void> Function(int value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value $unit',
            onChanged: (nextValue) {
              onChanged(nextValue.round());
            },
          ),
        ],
      ),
    );
  }
}
