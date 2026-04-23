import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

import '../models/course.dart';

class ScheduleParseException implements Exception {
  ScheduleParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScheduleParserService {
  const ScheduleParserService();

  static const List<int> _coursePalette = <int>[
    0xFF7C9AF2,
    0xFF56C8B4,
    0xFF6FB0F3,
    0xFFF0C86D,
    0xFFF49060,
    0xFFA9CE95,
    0xFFD2A1F2,
    0xFF9AA6BD,
  ];

  // Support normal Chinese labels and mojibake exports.
  static final RegExp _timeRegExp = RegExp(
    r'\(((?:[^()]|\((?:单|双|单周|双周)\))+?)(?:周|鍛[^\)]*)\)\s*\(([\d\-]+)(?:节|鑺[^\)]*)\)\s+(\S+)\s+(\S+)\s+(\S+)',
  );

  List<Course> parse(String html) {
    final normalizedHtml = html.trim();
    if (normalizedHtml.isEmpty) {
      throw ScheduleParseException('课表源码为空，无法解析。');
    }

    try {
      final document = parser.parse(normalizedHtml);
      final table = document.querySelector('table.courseTable');
      if (table == null) {
        throw ScheduleParseException('未找到课表表格，请确认当前页面仍然是教务课表页。');
      }

      final occupiedGrid = <int, Map<int, bool>>{};
      final courses = <Course>[];
      final seen = <String>{};
      final rows = table.querySelectorAll('tr');

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
        final row = rows[rowIndex];
        final cells = row.children.where((node) {
          return node.localName == 'td' || node.localName == 'th';
        }).cast<Element>();

        var colIndex = 0;
        for (final cell in cells) {
          while (occupiedGrid[rowIndex]?[colIndex] == true) {
            colIndex += 1;
          }

          final className = cell.classes.join(' ');
          final style = (cell.attributes['style'] ?? '').toLowerCase();
          final isHidden =
              style.contains('display:none') || style.contains('display: none');
          final rowspan = _parseSpan(cell.attributes['rowspan']);
          final colspan = _parseSpan(cell.attributes['colspan']);

          if (isHidden) {
            continue;
          }

          _markOccupied(
            occupiedGrid: occupiedGrid,
            rowIndex: rowIndex,
            colIndex: colIndex,
            rowspan: rowspan,
            colspan: colspan,
          );

          final weekday = colIndex;
          if (weekday < 1 || weekday > 7 || className.contains('dayPartUnit')) {
            colIndex += colspan;
            continue;
          }

          final tdHtmlNodes = cell.querySelectorAll('.tdHtml');
          if (tdHtmlNodes.isEmpty) {
            colIndex += colspan;
            continue;
          }

          for (final block in _extractUniqueLessonBlocks(tdHtmlNodes)) {
            final lessonFragments = _groupLessonsFromBlock(block);
            for (final lesson in lessonFragments) {
              if (lesson.name.isEmpty || lesson.cleanedText.isEmpty) {
                continue;
              }

              for (final match in _timeRegExp.allMatches(lesson.cleanedText)) {
                final period = _parsePeriodRange(match.group(2) ?? '');
                final course = Course(
                  name: lesson.name,
                  location: '${match.group(3) ?? ''} ${match.group(4) ?? ''}'
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim(),
                  teacher: (match.group(5) ?? '').trim(),
                  weekday: weekday,
                  weeks: _parseWeeks(match.group(1) ?? ''),
                  startPeriod: period.start,
                  endPeriod: period.end,
                  colorValue: _pickColor(lesson.name),
                );

                final key = _courseKey(course);
                if (seen.add(key)) {
                  courses.add(course);
                }
              }
            }
          }

          colIndex += colspan;
        }
      }

      if (courses.isEmpty) {
        throw ScheduleParseException('没有识别到课程，请确认课表 HTML 结构没有变化。');
      }

      return courses;
    } on ScheduleParseException {
      rethrow;
    } catch (error) {
      throw ScheduleParseException('DOM解析失败: ${error.toString()}');
    }
  }

  List<Element> _extractUniqueLessonBlocks(List<Element> blocks) {
    final seen = <String>{};
    final visibleBlocks = <Element>[];
    final hiddenFallbackBlocks = <Element>[];

    for (final block in blocks) {
      final style = (block.attributes['style'] ?? '').toLowerCase();
      final inner = block.innerHtml.trim();
      final hasCourseName = block.querySelector('.course-name') != null;
      if (!hasCourseName || inner.isEmpty) {
        continue;
      }

      if (!seen.add(inner)) {
        continue;
      }

      if (style.contains('opacity: 0')) {
        hiddenFallbackBlocks.add(block);
      } else {
        visibleBlocks.add(block);
      }
    }

    return visibleBlocks.isNotEmpty ? visibleBlocks : hiddenFallbackBlocks;
  }

  List<_LessonFragment> _groupLessonsFromBlock(Element block) {
    final fragments = <_LessonFragment>[];
    var currentName = '';
    final buffer = StringBuffer();

    void flush() {
      if (currentName.isEmpty) {
        return;
      }

      final cleanedText = _cleanHtmlFragment(buffer.toString());
      if (cleanedText.isNotEmpty) {
        fragments.add(
          _LessonFragment(name: currentName, cleanedText: cleanedText),
        );
      }
      currentName = '';
      buffer.clear();
    }

    for (final node in block.nodes) {
      if (node is Element && node.classes.contains('course-name')) {
        flush();
        currentName = node.text.trim();
        buffer.write(node.outerHtml);
        continue;
      }

      if (node is Element) {
        buffer.write(node.outerHtml);
      } else {
        buffer.write(node.text);
      }
    }

    flush();
    return fragments;
  }

  String _cleanHtmlFragment(String html) {
    var cleanedText = html;

    cleanedText = cleanedText.replaceAll('&nbsp;', ' ');
    cleanedText = cleanedText.replaceAll('\u00a0', ' ');
    cleanedText = cleanedText.replaceAll(
      RegExp(r'</div>|<br\s*/?>|</p>', caseSensitive: false),
      '\n',
    );
    cleanedText = cleanedText.replaceAll(RegExp(r'<[^>]*>'), ' ');
    cleanedText = cleanedText.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleanedText = cleanedText.replaceAll(RegExp(r'\n[ ]+'), '\n');
    cleanedText = cleanedText.replaceAll(RegExp(r'[ ]+\n'), '\n');
    cleanedText = cleanedText.replaceAll(RegExp(r'\n{2,}'), '\n');

    return cleanedText.trim();
  }

  List<int> _parseWeeks(String weekStr) {
    final weeks = <int>[];
    final standardizedStr = weekStr
        .replaceAll('~', '-')
        .replaceAll('至', '-')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll('周', '')
        .replaceAll(RegExp(r'\s+'), '');
    final parts = standardizedStr.split(',');

    for (final part in parts) {
      if (part.isEmpty) {
        continue;
      }

      final qualifierMatch = RegExp(
        r'^(.*?)(?:\((单|双|单周|双周)\)|(单|双|单周|双周))?$',
      ).firstMatch(part);
      final rawRange = (qualifierMatch?.group(1) ?? part).trim();
      final qualifier =
          (qualifierMatch?.group(2) ?? qualifierMatch?.group(3) ?? '')
              .replaceAll('周', '');

      if (rawRange.contains('-')) {
        final bounds = rawRange.split('-');
        if (bounds.length != 2) {
          continue;
        }

        final start = int.tryParse(bounds[0]) ?? 0;
        final end = int.tryParse(bounds[1]) ?? 0;
        if (start <= 0 || end < start) {
          continue;
        }

        for (var week = start; week <= end; week += 1) {
          if (_matchesWeekQualifier(week, qualifier)) {
            weeks.add(week);
          }
        }
        continue;
      }

      final week = int.tryParse(rawRange);
      if (week != null && _matchesWeekQualifier(week, qualifier)) {
        weeks.add(week);
      }
    }

    final result = weeks.toSet().toList()..sort();
    return result.isEmpty ? <int>[1] : result;
  }

  bool _matchesWeekQualifier(int week, String qualifier) {
    switch (qualifier) {
      case '单':
        return week.isOdd;
      case '双':
        return week.isEven;
      default:
        return true;
    }
  }

  _PeriodRange _parsePeriodRange(String rawPeriods) {
    final normalized = rawPeriods.trim();
    final rangeMatch = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
    if (rangeMatch != null) {
      return _PeriodRange(
        start: int.parse(rangeMatch.group(1)!),
        end: int.parse(rangeMatch.group(2)!),
      );
    }

    final singleMatch = RegExp(r'^(\d{1,2})$').firstMatch(normalized);
    if (singleMatch != null) {
      final value = int.parse(singleMatch.group(1)!);
      return _PeriodRange(start: value, end: value);
    }

    throw ScheduleParseException('无法识别节次: $rawPeriods');
  }

  void _markOccupied({
    required Map<int, Map<int, bool>> occupiedGrid,
    required int rowIndex,
    required int colIndex,
    required int rowspan,
    required int colspan,
  }) {
    for (var r = 0; r < rowspan; r += 1) {
      final row = occupiedGrid.putIfAbsent(rowIndex + r, () => <int, bool>{});
      for (var c = 0; c < colspan; c += 1) {
        row[colIndex + c] = true;
      }
    }
  }

  int _parseSpan(String? rawValue) {
    final parsed = int.tryParse(rawValue ?? '1') ?? 1;
    return parsed.clamp(1, 99).toInt();
  }

  int _pickColor(String seed) {
    return _coursePalette[_stableHash(seed) % _coursePalette.length];
  }

  int _stableHash(String source) {
    var hash = 0;
    for (final codeUnit in source.codeUnits) {
      hash = ((hash << 5) - hash) + codeUnit;
      hash &= 0x7fffffff;
    }
    return hash.abs();
  }

  String _courseKey(Course course) {
    return [
      course.name,
      course.location,
      course.teacher,
      course.weekday,
      course.weeks.join(','),
      course.startPeriod,
      course.endPeriod,
    ].join('|');
  }
}

class _LessonFragment {
  const _LessonFragment({required this.name, required this.cleanedText});

  final String name;
  final String cleanedText;
}

class _PeriodRange {
  const _PeriodRange({required this.start, required this.end});

  final int start;
  final int end;
}
