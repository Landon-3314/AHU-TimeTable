import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'semester_start_date_dialog.dart';

Future<bool> ensureCurrentSemesterInitialized(BuildContext context) async {
  final provider = context.read<SettingsProvider>();
  if (provider.isCurrentSemesterInitialized) {
    return true;
  }

  final selectedDate = await showSemesterStartDateDialog(
    context: context,
    initialDate: provider.semesterStartDate,
    canCancel: false,
  );
  if (!context.mounted || selectedDate == null) {
    return false;
  }

  await provider.completeInitialSemesterStartDate(selectedDate);
  return context.mounted && provider.isCurrentSemesterInitialized;
}
