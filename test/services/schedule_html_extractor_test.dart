import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/services/schedule_html_extractor.dart';

void main() {
  group('semester start date extraction', () {
    test('parses the stable startDate element', () {
      final startDate = ScheduleHtmlExtractor.parseSemesterStartDate('''
<div>
  <span>学期起始日期: </span>&nbsp;<span id="startDate">2026-03-02</span>
</div>
''');

      expect(startDate, DateTime(2026, 3, 2));
    });

    test('falls back to the Chinese label text', () {
      final startDate = ScheduleHtmlExtractor.parseSemesterStartDate(
        '全部周次 学期起始日期： 2026-09-07 打印',
      );

      expect(startDate, DateTime(2026, 9, 7));
    });

    test('parses the direct date returned by the WebView script', () {
      final startDate = ScheduleHtmlExtractor.parseSemesterStartDate(
        '2026-03-02',
      );

      expect(startDate, DateTime(2026, 3, 2));
    });

    test('returns null for missing or invalid dates', () {
      expect(
        ScheduleHtmlExtractor.parseSemesterStartDate('学期起始日期: 2026-99-99'),
        isNull,
      );
      expect(
        ScheduleHtmlExtractor.parseSemesterStartDate('当前页面没有起始日期'),
        isNull,
      );
    });
  });
}
