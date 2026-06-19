import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/academic_exam_api_parser.dart';
import 'package:AnKe/services/schedule_parser_service.dart';

void main() {
  const parser = AcademicExamApiParser();

  test('parses unfinished studentExamInfoVms into events', () {
    final raw = jsonEncode([
      {
        'course': {'nameZh': '离散数学（下）'},
        'examType': {'nameZh': '期中'},
        'examTime': '2026-05-18 19:00~21:00',
        'seatNo': '1',
        'requiredCampus': {'nameZh': '磬苑校区'},
        'room': '博学南楼B209',
        'finished': false,
      },
      {
        'course': {'nameZh': '最优化方法'},
        'examType': {'nameZh': '期末'},
        'examTime': '2026-01-21 08:00~10:00',
        'seatNo': '2',
        'requiredCampus': {'nameZh': '磬苑校区'},
        'room': '博学南楼B109',
        'finished': true,
      },
    ]);

    final exams = parser.parseStudentExamInfoVms(raw);

    expect(exams, hasLength(1));
    expect(exams.single.name, '离散数学（下）（期中）');
    expect(exams.single.location, '磬苑校区 博学南楼B209');
    expect(exams.single.note, '座位号(1)');
    expect(exams.single.dateTime, DateTime(2026, 5, 18, 19));
    expect(exams.single.enableAlarm, isTrue);
  });

  test('extracts studentExamInfoVms from a page script', () {
    const html = '''
<script>
  window.studentExamInfoVms = [{"course":{"nameZh":"信号与系统"},"examType":{"nameZh":"期中"},"examTime":"2026-05-22 19:00~21:00","finished":false}];
</script>
''';

    final raw = parser.extractStudentExamInfoVms(html);

    expect(raw, isNotNull);
    expect(parser.parseStudentExamInfoVms(raw!), hasLength(1));
  });

  test('parses AHUTong style JavaScript literal with single quotes', () {
    const raw = r'''
[
  {
    course: { nameZh: '数据库原理' },
    examType: { nameZh: '期末' },
    examTime: '2026-06-20 09:00~11:00',
    seatNo: '12',
    requiredCampus: { nameZh: '龙河校区' },
    room: '逸夫楼101',
    finished: false,
  }
]
''';

    final exams = parser.parseStudentExamInfoVms(raw);

    expect(exams, hasLength(1));
    expect(exams.single.name, '数据库原理（期末）');
    expect(exams.single.location, '龙河校区 逸夫楼101');
    expect(exams.single.note, '座位号(12)');
  });

  test('returns null when the script variable is malformed', () {
    const html = '<script>studentExamInfoVms = [{"course":{};</script>';

    expect(parser.extractStudentExamInfoVms(html), isNull);
  });

  test('throws a parser exception for invalid exam time', () {
    final raw = jsonEncode([
      {
        'course': {'nameZh': '离散数学'},
        'examType': {'nameZh': '期中'},
        'examTime': '待定',
        'finished': false,
      },
    ]);

    expect(
      () => parser.parseStudentExamInfoVms(raw),
      throwsA(isA<ScheduleParseException>()),
    );
  });
}
