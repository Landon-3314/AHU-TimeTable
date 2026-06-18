import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

class TimetableEmptyStateActions extends StatelessWidget {
  const TimetableEmptyStateActions({
    super.key,
    required this.addCourseLabel,
    required this.importCoursesLabel,
    required this.showImportCourses,
    required this.onAddCourse,
    required this.onImportCourses,
  });

  final String addCourseLabel;
  final String importCoursesLabel;
  final bool showImportCourses;
  final VoidCallback onAddCourse;
  final VoidCallback onImportCourses;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: onAddCourse,
          icon: const Icon(Icons.add),
          label: Text(addCourseLabel),
        ),
        if (showImportCourses)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: onImportCourses,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(importCoursesLabel),
          ),
      ],
    );
  }
}
