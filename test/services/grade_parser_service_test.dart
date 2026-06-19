import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/grade_parser_service.dart';

void main() {
  const parser = GradeParserService();

  test('parses semesterId2studentGrades grouped by remote semester id', () {
    final book = parser.parseGradeInfo(
      jsonEncode({
        'semesterId2studentGrades': {
          '202520261': [
            {
              'courseCode': 'MATH001',
              'courseName': '高等数学',
              'credits': 4.0,
              'gaGrade': '95',
              'gp': 4.0,
              'courseType': {'nameZh': '必修'},
              'courseProperty': {'nameZh': '专业基础课'},
              'passed': true,
              'published': true,
              'gradeDetail': '平时:30 期末:65',
              'lessonCode': 'MATH001-01',
              'semesterName': '2025-2026学年秋季学期',
            },
          ],
        },
      }),
      studentId: '123456',
      fetchedAt: DateTime(2026, 6, 18, 12),
    );

    expect(book.studentId, '123456');
    expect(book.fetchedAt, DateTime(2026, 6, 18, 12));
    expect(book.terms, hasLength(1));
    expect(book.terms.single.remoteSemesterId, '202520261');
    expect(book.terms.single.semesterName, '2025-2026学年秋季学期');
    expect(book.terms.single.records, hasLength(1));
    final record = book.terms.single.records.single;
    expect(record.courseCode, 'MATH001');
    expect(record.courseName, '高等数学');
    expect(record.credits, 4.0);
    expect(record.grade, '95');
    expect(record.gp, 4.0);
    expect(record.courseType, '必修');
    expect(record.courseProperty, '专业基础课');
    expect(record.passed, isTrue);
    expect(record.published, isTrue);
    expect(record.gradeDetail, '平时:30 期末:65');
    expect(record.lessonCode, 'MATH001-01');
  });

  test('extracts student id from grade sheet final url', () {
    expect(
      parser.extractStudentIdFromGradeSheetUrl(
        'https://jw.ahu.edu.cn/student/for-std/grade/sheet/123456',
      ),
      '123456',
    );
  });
}
