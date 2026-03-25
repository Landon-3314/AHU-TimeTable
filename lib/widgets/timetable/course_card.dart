import 'package:flutter/material.dart';

import '../../models/course.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.periodText,
    required this.accentColor,
    required this.onTap,
  });

  final Course course;
  final String periodText;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _teacherLocationText(course),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      periodText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accentColor.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _teacherLocationText(Course course) {
    if (course.teacher.trim().isEmpty) {
      return course.location;
    }
    if (course.location.trim().isEmpty) {
      return course.teacher;
    }
    return '${course.teacher} / ${course.location}';
  }
}
