import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/services/schedule_parser_service.dart';

void main() {
  const parser = ScheduleParserService();

  test('parses unfinished exams from academic exam table', () {
    const examHtml = r'''
<table class="table table-hover table-condensed exam-table" id="exams">
  <tbody>
    <tr data-finished="false" class="unfinished">
      <td>
        <div class="time ">2026-05-18 19:00~21:00</div>
        <div>
          <span>磬苑校区</span>
          <span>博学南楼</span>
          <span>博学南楼B209</span>
          <span id="seat-2366312">座位号(1)</span>
        </div>
      </td>
      <td>
        <div>
          <span style="font-weight: bold;">离散数学（下） </span>
        </div>
        <div>
          <span class="tag-span type1">期中</span>
        </div>
      </td>
      <td class="text-center">未结束</td>
    </tr>
    <tr data-finished="false" class="unfinished">
      <td>
        <div class="time ">2026-05-22 19:00~21:00</div>
        <div>
          <span>磬苑校区</span>
          <span>博学北楼</span>
          <span>博学北楼A205</span>
          <span id="seat-2422989">座位号(2)</span>
        </div>
      </td>
      <td>
        <div>
          <span style="font-weight: bold;">信号与系统 </span>
        </div>
        <div>
          <span class="tag-span type1">期中</span>
        </div>
      </td>
      <td class="text-center">未结束</td>
    </tr>
    <tr data-finished="false" class="unfinished">
      <td>
        <div class="time ">2026-05-23 19:00~21:00</div>
        <div>
          <span>磬苑校区</span>
          <span>博学南楼</span>
          <span>博学南楼B101</span>
          <span id="seat-2366467">座位号(3)</span>
        </div>
      </td>
      <td>
        <div>
          <span style="font-weight: bold;">计算机组成原理 </span>
        </div>
        <div>
          <span class="tag-span type1">期中</span>
        </div>
      </td>
      <td class="text-center">未结束</td>
    </tr>
    <tr data-finished="true" class="finished hide">
      <td>
        <div class="time ">2026-01-21 08:00~10:00</div>
        <div>
          <span>磬苑校区</span>
          <span>博学南楼</span>
          <span>博学南楼B109</span>
          <span id="seat-1922344">座位号(2)</span>
        </div>
      </td>
      <td>
        <div>
          <span style="font-weight: bold;">最优化方法 </span>
        </div>
        <div>
          <span class="tag-span type2">期末</span>
        </div>
      </td>
      <td class="text-center">已结束</td>
    </tr>
  </tbody>
</table>
''';

    final exams = parser.parseExams(examHtml);

    expect(exams, hasLength(3));
    expect(exams[0].name, '离散数学（下）（期中）');
    expect(exams[0].location, '博学南楼B209');
    expect(exams[0].note, '座位号(1)');
    expect(exams[0].dateTime, DateTime(2026, 5, 18, 19));
    expect(exams[0].enableAlarm, isTrue);
    expect(exams[1].name, '信号与系统（期中）');
    expect(exams[1].location, '博学北楼A205');
    expect(exams[1].note, '座位号(2)');
    expect(exams[1].dateTime, DateTime(2026, 5, 22, 19));
    expect(exams[2].name, '计算机组成原理（期中）');
    expect(exams[2].location, '博学南楼B101');
    expect(exams[2].note, '座位号(3)');
    expect(exams[2].dateTime, DateTime(2026, 5, 23, 19));
  });

  test('returns empty list when exam table has no unfinished rows', () {
    const examHtml = r'''
<table class="exam-table" id="exams">
  <tbody>
    <tr data-finished="true" class="finished hide">
      <td><div class="time ">2026-01-21 08:00~10:00</div></td>
      <td><span>最优化方法 </span><span class="tag-span type2">期末</span></td>
      <td>已结束</td>
    </tr>
  </tbody>
</table>
''';

    expect(parser.parseExams(examHtml), isEmpty);
  });

  test('reports and skips unknown weeks and invalid periods', () {
    const timetableHtml = r'''
<table class="courseTable">
  <tr>
    <td class="dayPartUnit">上午</td>
    <td>
      <div class="tdHtml">
        <span class="course-name">正常课程</span>
        (1-4(单)周) (1-2节) 磬苑校区 A101 王老师
        <span class="course-name">未知周次</span>
        (待定周) (3-4节) 磬苑校区 A102 李老师
        <span class="course-name">非法节次</span>
        (1-4周) (5-2节) 磬苑校区 A103 周老师
      </div>
    </td>
  </tr>
</table>
''';

    final result = parser.parseTimetableReport(timetableHtml);

    expect(result.items, hasLength(1));
    expect(result.items.single.name, '正常课程');
    expect(result.items.single.weeks, [1, 3]);
    expect(result.skippedCount, 2);
    expect(result.skippedReasons.join('\n'), contains('未知周次'));
    expect(result.skippedReasons.join('\n'), contains('无法识别周次'));
    expect(result.skippedReasons.join('\n'), contains('非法节次'));
    expect(result.skippedReasons.join('\n'), contains('节次范围无效'));
  });

  test('rejects timetable when every course record is invalid', () {
    const timetableHtml = r'''
<table class="courseTable">
  <tr>
    <td class="dayPartUnit">上午</td>
    <td>
      <div class="tdHtml">
        <span class="course-name">非法课程</span>
        (1-4周) (0-2节) 磬苑校区 A101 王老师
      </div>
    </td>
  </tr>
</table>
''';

    expect(
      () => parser.parseTimetableReport(timetableHtml),
      throwsA(
        isA<ScheduleParseException>().having(
          (error) => error.message,
          'message',
          contains('节次范围无效'),
        ),
      ),
    );
  });
}
