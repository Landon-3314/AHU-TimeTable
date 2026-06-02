import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/models/course.dart';

void main() {
  test('course json uses Chinese fallback when name is missing', () {
    final course = Course.fromJson(const <String, dynamic>{});

    expect(course.name, '未命名课程');
  });
}
