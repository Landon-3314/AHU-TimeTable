import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/grade_parser_service.dart';

void main() {
  const parser = GradeParserService();

  test('parses semesterId2studentGrades grouped by remote semester id', () {
    final book = parser.parseGradeInfo(
      jsonEncode({
        'gpaSemesterModel': {
          'gpa': 3.86,
          'majorRank': 37,
          'majorHeadCount': 314,
          'totalCredits': 114,
          'inPlanCredits': 80,
          'outPlanCredits': 34,
          'updatedDateTimeStr': '2026-06-18 23:53',
          'gpaSemesterSubStr': jsonEncode([
            {
              'semesterId': 202520261,
              'gpa': 4.2,
              'majorRank': 6,
              'totalCredits': 21,
              'inPlanCredits': 18,
              'outPlanCredits': 3,
            },
          ]),
        },
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
    expect(book.statistics?.gpa, 3.86);
    expect(book.statistics?.rank, 37);
    expect(book.statistics?.rankTotal, 314);
    expect(book.statistics?.totalCredits, 114);
    expect(book.statistics?.updatedAtText, '2026-06-18 23:53');
    expect(book.terms, hasLength(1));
    expect(book.terms.single.remoteSemesterId, '202520261');
    expect(book.terms.single.semesterName, '2025-2026学年秋季学期');
    expect(book.terms.single.statistics?.gpa, 4.2);
    expect(book.terms.single.statistics?.rank, 6);
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

  test('parses rendered grade sheet html with semester statistics', () {
    final book = parser.parseGradeSheetHtml(
      '''
      <html>
        <body>
          <div class="all-gpa">
            全程总学分： <span>114</span>；
            全程平均学分绩点（GPA）： <span>3.86</span>；
            学院专业全程GPA排名： <span>37/314</span>；
            全程计划内学分： <span>80</span>；
            全程计划外学分： <span>34</span>；
            统计时间： <span>2026-06-18 23:53</span>
          </div>
          <script>
            var gpaSemesterModel = {'gpa':3.86,'majorRank':2,'majorHeadCount':314,'totalCredits':27.5,'inPlanCredits':9.5,'outPlanCredits':18,'updatedDateTimeStr':'2026-06-18 23:53','gpaSemesterSubStr':'[{"gpa":4.2,"inPlanCredits":18,"majorRank":6,"outPlanCredits":3,"semesterId":202520261,"totalCredits":21}]'};
          </script>
          <h3 class="semesterName">2025-2026-1</h3>
          <table class="student-grade-table">
            <tbody>
              <tr><th>课程名称</th><th>学分</th><th>绩点</th><th>成绩</th><th>成绩明细</th></tr>
              <tr>
                <td>高等数学 MATH001 | 通识必修 | 理论课 | 必修</td>
                <td>4</td><td>4.5</td><td>95</td><td>平时:30 期末:65</td>
              </tr>
            </tbody>
          </table>
        </body>
      </html>
      ''',
      studentId: '123456',
      fetchedAt: DateTime(2026, 6, 18, 12),
    );

    expect(book.statistics?.gpa, 3.86);
    expect(book.statistics?.rank, 37);
    expect(book.statistics?.rankTotal, 314);
    expect(book.statistics?.totalCredits, 114);
    expect(book.terms, hasLength(1));
    expect(book.terms.single.semesterName, '2025-2026-1');
    expect(book.terms.single.statistics?.gpa, 4.2);
    expect(book.terms.single.records.single.courseName, '高等数学');
    expect(book.terms.single.records.single.courseCode, 'MATH001');
    expect(book.terms.single.records.single.credits, 4);
    expect(book.terms.single.records.single.gp, 4.5);
    expect(book.terms.single.records.single.grade, '95');
    expect(book.terms.single.records.single.gradeDetail, '平时:30 期末:65');
  });

  test('parses grade sheet statistics before ajax tables are rendered', () {
    final book = parser.parseGradeSheetHtml(
      '''
      <html><body>
        <script>
          var semesters = JSON.parse('[{"id":202520261,"nameZh":"2025-2026-1"}]');
          var gpaSemesterModel = {'gpa':3.86,'gpaSemesterSubStr':'[{"gpa":4.2,"majorRank":6,"semesterId":202520261,"totalCredits":21}]','majorRank':37,'majorHeadCount':314,'totalCredits':114};
          var gpaSemesterSubs = [{"gpa":4.2,"majorRank":6,"semesterId":202520261,"totalCredits":21}];
          function changeGpaShow() {}
        </script>
      </body></html>
      ''',
      studentId: '123456',
      fetchedAt: DateTime(2026, 6, 18, 12),
      allowEmptyTerms: true,
    );

    expect(book.statistics?.gpa, 3.86);
    expect(book.statistics?.rank, 37);
    expect(book.statistics?.rankTotal, 314);
    expect(book.terms.single.remoteSemesterId, '202520261');
    expect(book.terms.single.semesterName, '2025-2026-1');
    expect(book.terms.single.statistics?.gpa, 4.2);
    expect(book.terms.single.records, isEmpty);
  });

  test('merges api grades with page-wide statistics preference', () {
    final apiBook = parser.parseGradeInfo(
      jsonEncode({
        'gpaSemesterModel': {
          'gpa': 3.86,
          'majorRank': 2,
          'majorHeadCount': 314,
          'totalCredits': 27.5,
          'gpaSemesterSubStr': jsonEncode([
            {
              'semesterId': 49,
              'gpa': 3.65,
              'majorRank': 2,
              'majorHeadCount': 314,
              'totalCredits': 27.5,
            },
          ]),
        },
        'semesterId2studentGrades': {
          '49': [
            {
              'courseCode': 'GG64002',
              'courseName': '军事技能',
              'credits': 2,
              'gaGrade': '优秀',
              'semesterName': '2023-2024-1',
            },
          ],
        },
      }),
      studentId: '123456',
      fetchedAt: DateTime(2026, 6, 18, 12),
    );
    final pageBook = parser.parseGradeSheetHtml(
      '''
      <html><body>
        <div>全程总学分：114 全程平均学分绩点（GPA）：3.86 学院专业全程GPA排名：37/314</div>
      </body></html>
      ''',
      studentId: '123456',
      fetchedAt: DateTime(2026, 6, 18, 12),
      allowEmptyTerms: true,
    );

    final merged = parser.mergeGradeBooks(
      primary: apiBook,
      metadataFallback: pageBook,
    );

    expect(merged.statistics?.gpa, 3.86);
    expect(merged.statistics?.rank, 37);
    expect(merged.statistics?.rankTotal, 314);
    expect(merged.statistics?.totalCredits, 114);
    expect(merged.terms.single.statistics?.rank, 2);
    expect(merged.terms.single.records.single.courseName, '军事技能');
  });
}
