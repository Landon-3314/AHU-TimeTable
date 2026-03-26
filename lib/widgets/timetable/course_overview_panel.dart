import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/course.dart';
import 'course_card.dart';

class CourseOverviewPanel extends StatelessWidget {
  const CourseOverviewPanel({
    super.key,
    required this.courses,
    required this.coursePeriodTextBuilder,
    required this.onCourseTap,
  });

  final List<Course> courses;
  final String Function(Course course) coursePeriodTextBuilder;
  final ValueChanged<Course> onCourseTap;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return Center(
        child: Text(
          '本学期没有课程',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return SafeArea(
      child: ListView.builder(
        padding: AppSpacing.listPagePadding,
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final course = courses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CourseCard(
              course: course,
              periodText: coursePeriodTextBuilder(course),
              accentColor: Color(course.colorValue),
              onTap: () => onCourseTap(course),
            ),
          );
        },
      ),
    );
  }
}
