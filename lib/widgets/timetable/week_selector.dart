import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../models/timetable_view_data.dart';

class WeekSelector extends StatelessWidget {
  const WeekSelector({
    super.key,
    required this.currentWeek,
    required this.options,
    required this.tooltip,
    required this.onSelected,
  });

  final int currentWeek;
  final List<TimetableWeekOption> options;
  final String tooltip;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    var currentLabel = options.first.label;
    for (final option in options) {
      if (option.value == currentWeek) {
        currentLabel = option.label;
        break;
      }
    }

    return PopupMenuButton<int>(
      tooltip: tooltip,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<int>(
            value: option.value,
            child: Row(
              children: [
                Expanded(child: Text(option.label)),
                if (option.value == currentWeek)
                  const Icon(Icons.check, size: 16),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
