import 'package:flutter/material.dart';

import '../core/app_constants.dart';

Future<DateTime?> showSemesterStartDateDialog({
  required BuildContext context,
  required DateTime initialDate,
  String title = '选择学期开始日期',
  String message = '用于计算当前周次，也会同步到设置里的学期开始日期。',
  bool canCancel = true,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      var draftDate = initialDate;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return PopScope(
            canPop: canCancel,
            child: AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(message),
                  const SizedBox(height: AppSpacing.xl),
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
              actionsPadding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                0,
                AppSpacing.xxl,
                AppSpacing.xxl,
              ),
              actions: [
                _SemesterStartDateDialogActions(
                  canCancel: canCancel,
                  onCancel: () => Navigator.of(dialogContext).pop(),
                  onConfirm: () => Navigator.of(dialogContext).pop(draftDate),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _SemesterStartDateDialogActions extends StatelessWidget {
  const _SemesterStartDateDialogActions({
    required this.canCancel,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool canCancel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    if (!canCancel) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onConfirm, child: const Text('确认')),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(onPressed: onCancel, child: const Text('取消')),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: FilledButton(onPressed: onConfirm, child: const Text('确认')),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
