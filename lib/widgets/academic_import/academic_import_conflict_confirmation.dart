import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../providers/course_provider.dart';
import '../common/app_ui.dart';

Future<int?> importTimetableCoursesWithConflictConfirmation({
  required BuildContext context,
  required CourseProvider courseProvider,
  required List<Course> courses,
  bool confirmConflicts = true,
}) async {
  if (!confirmConflicts) {
    return courseProvider.mergeImportedCourses(courses);
  }

  final conflicts = courseProvider.findImportedCourseConflicts(courses);
  var allowConflicts = false;
  if (conflicts.isNotEmpty) {
    allowConflicts = await showCourseConflictConfirmDialog(
      context,
      conflicts: conflicts,
    );
    if (!context.mounted || !allowConflicts) {
      return null;
    }
  }
  return courseProvider.mergeImportedCourses(
    courses,
    allowConflicts: allowConflicts,
  );
}
