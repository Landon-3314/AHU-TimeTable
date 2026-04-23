import 'package:flutter/material.dart';

Future<DateTime?> showSemesterStartDateDialog({
  required BuildContext context,
  required DateTime initialDate,
  String title = '选择学期开始日期',
  String message = '用于计算当前周次，也会同步到设置里的学期开始日期。',
}) {
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var draftDate = initialDate;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(_formatDate(draftDate)),
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: draftDate,
                      firstDate: DateTime(now.year - 2),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (picked == null) {
                      return;
                    }
                    setDialogState(() {
                      draftDate = picked;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(draftDate),
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
