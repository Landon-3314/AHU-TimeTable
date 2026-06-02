import '../models/course.dart';

class CourseConflict {
  const CourseConflict({required this.candidate, required this.existingCourse});

  final Course candidate;
  final Course existingCourse;
}

class CourseConflictPolicy {
  const CourseConflictPolicy();

  List<CourseConflict> findConflicts({
    required Iterable<Course> candidates,
    required Iterable<Course> existingCourses,
    String? ignoredCourseId,
  }) {
    final conflicts = <CourseConflict>[];
    final acceptedCandidates = <Course>[];
    for (final candidate in candidates) {
      for (final existing in [...existingCourses, ...acceptedCandidates]) {
        if (existing.id == ignoredCourseId ||
            hasSameIdentity(existing, candidate) ||
            existing.weekday != candidate.weekday ||
            !existing.weeks.any(candidate.weeks.contains) ||
            !_rangesOverlap(
              existing.startPeriod,
              existing.endPeriod,
              candidate.startPeriod,
              candidate.endPeriod,
            )) {
          continue;
        }
        conflicts.add(
          CourseConflict(candidate: candidate, existingCourse: existing),
        );
      }
      acceptedCandidates.add(candidate);
    }
    return conflicts;
  }

  bool hasSameIdentity(Course left, Course right) {
    return _normalize(left.name) == _normalize(right.name) &&
        _normalize(left.location) == _normalize(right.location) &&
        _normalize(left.teacher) == _normalize(right.teacher);
  }

  bool _rangesOverlap(
    int leftStart,
    int leftEnd,
    int rightStart,
    int rightEnd,
  ) {
    return leftStart <= rightEnd && rightStart <= leftEnd;
  }

  String _normalize(String value) => value.trim().toLowerCase();
}
