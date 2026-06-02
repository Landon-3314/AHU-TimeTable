import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/models/course.dart';
import 'package:timetable/services/course_conflict_policy.dart';

void main() {
  const policy = CourseConflictPolicy();

  test('reports overlapping periods for different courses', () {
    final conflicts = policy.findConflicts(
      candidates: [
        _course(
          id: 'candidate',
          name: '线性代数',
          weekday: DateTime.monday,
          weeks: const [1],
          startPeriod: 2,
          endPeriod: 3,
        ),
      ],
      existingCourses: [
        _course(
          id: 'existing',
          name: '大学英语',
          weekday: DateTime.monday,
          weeks: const [1],
          startPeriod: 3,
          endPeriod: 4,
        ),
      ],
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single.candidate.name, '线性代数');
    expect(conflicts.single.existingCourse.name, '大学英语');
  });

  test('does not report normalized duplicate identity as conflict', () {
    final conflicts = policy.findConflicts(
      candidates: [
        _course(
          id: 'candidate',
          name: ' math ',
          location: ' ROOM 101 ',
          teacher: ' DR. CHEN ',
        ),
      ],
      existingCourses: [
        _course(
          id: 'existing',
          name: 'Math',
          location: 'Room 101',
          teacher: 'Dr. Chen',
        ),
      ],
    );

    expect(conflicts, isEmpty);
  });

  test('does not report courses on different weekdays', () {
    final conflicts = policy.findConflicts(
      candidates: [_course(id: 'candidate', weekday: DateTime.tuesday)],
      existingCourses: [_course(id: 'existing', weekday: DateTime.monday)],
    );

    expect(conflicts, isEmpty);
  });

  test('does not report courses in different weeks', () {
    final conflicts = policy.findConflicts(
      candidates: [
        _course(id: 'candidate', weeks: const [2]),
      ],
      existingCourses: [
        _course(id: 'existing', weeks: const [1]),
      ],
    );

    expect(conflicts, isEmpty);
  });

  test('does not report courses with separate period ranges', () {
    final conflicts = policy.findConflicts(
      candidates: [_course(id: 'candidate', startPeriod: 3, endPeriod: 4)],
      existingCourses: [_course(id: 'existing', startPeriod: 1, endPeriod: 2)],
    );

    expect(conflicts, isEmpty);
  });

  test('reports conflicts within the incoming course batch', () {
    final conflicts = policy.findConflicts(
      candidates: [
        _course(id: 'first', name: '线性代数'),
        _course(id: 'second', name: '大学英语'),
      ],
      existingCourses: const [],
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single.candidate.id, 'second');
    expect(conflicts.single.existingCourse.id, 'first');
  });
}

Course _course({
  required String id,
  String name = '课程',
  String location = 'A101',
  String teacher = '教师',
  int weekday = DateTime.monday,
  List<int> weeks = const [1],
  int startPeriod = 1,
  int endPeriod = 2,
}) {
  return Course(
    id: id,
    name: name,
    location: location,
    teacher: teacher,
    weekday: weekday,
    weeks: weeks,
    startPeriod: startPeriod,
    endPeriod: endPeriod,
    colorValue: 0xFF2563EB,
  );
}
