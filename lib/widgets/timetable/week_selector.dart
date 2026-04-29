import 'package:flutter/material.dart';

import '../../models/timetable_view_data.dart';
import '../common/app_ui.dart';

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
    var currentLabel = options.first.label;
    for (final option in options) {
      if (option.value == currentWeek) {
        currentLabel = option.label;
        break;
      }
    }

    return AppPickerPill(
      label: currentLabel,
      onTap: () async {
        final selected = await showAppOptionPicker<int>(
          context,
          title: tooltip,
          selectedValue: currentWeek,
          grid: true,
          gridCrossAxisCount: 3,
          options: [
            for (final option in options)
              AppPickerOption(value: option.value, label: option.label),
          ],
        );
        if (selected != null) {
          onSelected(selected);
        }
      },
    );
  }
}
