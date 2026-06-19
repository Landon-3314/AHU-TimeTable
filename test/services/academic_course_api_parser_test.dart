import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/academic_course_api_parser.dart';

void main() {
  const parser = AcademicCourseApiParser();

  test('parses print-data activities into courses and skipped reasons', () {
    final payload = jsonEncode({
      'studentTableVms': [
        {
          'activities': [
            {
              'courseName': '线性代数',
              'teacherNames': ['张三', '李四'],
              'campus': '磬苑校区',
              'building': '博学南楼',
              'room': 'A101',
              'weekday': 1,
              'weekIndexes': [1, 2, 3],
              'startUnit': 1,
              'endUnit': 2,
            },
            {
              'courseName': '非法星期',
              'teacherNames': '王五',
              'room': 'B201',
              'weekday': 8,
              'weekIndexes': [1],
              'startUnit': 3,
              'endUnit': 4,
            },
            {
              'courseName': '非法节次',
              'teacherNames': '赵六',
              'room': 'B202',
              'weekday': 2,
              'weekIndexes': [1],
              'startUnit': 5,
              'endUnit': 31,
            },
          ],
        },
      ],
    });

    final report = parser.parsePrintData(payload);

    expect(report.items, hasLength(1));
    expect(report.items.single.name, '线性代数');
    expect(report.items.single.teacher, '张三、李四');
    expect(report.items.single.location, '磬苑校区 博学南楼 A101');
    expect(report.items.single.weekday, 1);
    expect(report.items.single.weeks, [1, 2, 3]);
    expect(report.items.single.startPeriod, 1);
    expect(report.items.single.endPeriod, 2);
    expect(report.skippedCount, 2);
    expect(report.skippedReasons.join('\n'), contains('非法星期'));
    expect(report.skippedReasons.join('\n'), contains('星期'));
    expect(report.skippedReasons.join('\n'), contains('非法节次'));
    expect(report.skippedReasons.join('\n'), contains('节次'));
  });

  test('returns an empty report for valid empty activities', () {
    final payload = jsonEncode({
      'studentTableVms': [
        {'activities': <Object>[]},
      ],
    });

    final report = parser.parsePrintData(payload);

    expect(report.items, isEmpty);
    expect(report.skippedReasons, isEmpty);
  });

  test('deduplicates identical activities', () {
    final activity = {
      'courseName': '编译原理',
      'teacherNames': '陈老师',
      'room': 'C301',
      'weekday': 3,
      'weekIndexes': [4, 5],
      'startUnit': 7,
      'endUnit': 8,
    };
    final payload = jsonEncode({
      'studentTableVms': [
        {
          'activities': [activity, activity],
        },
      ],
    });

    final report = parser.parsePrintData(payload);

    expect(report.items, hasLength(1));
    expect(report.items.single.name, '编译原理');
  });

  test('extracts current semester id from course table page script', () {
    const html = '''
<script>
  var currentSemester = {"id": 202520261, "nameZh": "2025-2026-1"};
</script>
''';

    expect(parser.extractCurrentSemesterId(html), 202520261);
  });

  test('extracts current semester id from JSON.parse page script', () {
    const html = r'''
<script>
  var currentSemester = JSON.parse('{\"id\":202520262,\"name\":\"2025-2026-2\"}');
</script>
''';

    expect(parser.extractCurrentSemesterId(html), 202520262);
  });

  test('extracts current semester id from single quoted semester object', () {
    const html = '''
<script>
  var currentSemester = {'id': 202520263, 'name': '2025-2026-3'};
</script>
''';

    expect(parser.extractCurrentSemesterId(html), 202520263);
  });

  test('prefers top level semester id over nested calendar id', () {
    const html = '''
<script>
  var currentSemester = {'approvedYear':'2025','calendarAssoc':{'id':1},'id':202520264,'name':'2025-2026-4'};
</script>
''';

    expect(parser.extractCurrentSemesterId(html), 202520264);
  });
}
