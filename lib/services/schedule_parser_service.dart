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

  List<Course> parse(String html) {
    final normalizedHtml = html.trim();
    if (normalizedHtml.isEmpty) {
      throw ScheduleParseException('课表源码为空，无法解析。');
    }

    final tables = _extractScheduleTables(normalizedHtml);
    if (tables.isEmpty) {
      throw ScheduleParseException('未找到课表表格，请先登录并进入课表页面。');
    }

    final seen = <String>{};
    final courses = <Course>[];

    for (final tableHtml in tables) {
      for (final rowHtml in _extractRows(tableHtml)) {
        final rowStartPeriod = _extractRowStartPeriod(rowHtml);
        if (rowStartPeriod == null) {
          continue;
        }

        for (final cell in _extractCells(rowHtml)) {
          if (!cell.isCourseCell || cell.isHidden) {
            continue;
          }

          final weekday = cell.weekday;
          if (weekday == null || weekday < 1 || weekday > 7) {
            continue;
          }

          final startPeriod = rowStartPeriod;
          final endPeriod = (rowStartPeriod + cell.rowSpan - 1)
              .clamp(1, 13)
              .toInt();
          final tdHtml = cell.visibleTdHtml;
          if (tdHtml == null || tdHtml.trim().isEmpty) {
            continue;
          }

          final parsedCourses = _extractCoursesFromTdHtml(
            tdHtml: tdHtml,
            weekday: weekday,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
          );

          for (final course in parsedCourses) {
            final key = _courseKey(course);
            if (seen.add(key)) {
              courses.add(course);
            }
          }
        }
      }
    }

    if (courses.isEmpty) {
      throw ScheduleParseException('未识别到课程，请确认当前页面仍是教务课表页。');
    }

    return courses;
  }

  List<String> _extractScheduleTables(String html) {
    final tablePattern = RegExp(
      r"""<table\b[^>]*class\s*=\s*['"][^'"]*(?:Wjkc|courseTable)[^'"]*['"][^>]*>[\s\S]*?<\/table>""",
      caseSensitive: false,
    );
    return tablePattern
        .allMatches(html)
        .map((match) => match.group(0)!)
        .toList();
  }

  List<String> _extractRows(String tableHtml) {
    final rowPattern = RegExp(
      r'<tr\b[^>]*>[\s\S]*?<\/tr>',
      caseSensitive: false,
    );
    return rowPattern
        .allMatches(tableHtml)
        .map((match) => match.group(0)!)
        .toList();
  }

  int? _extractRowStartPeriod(String rowHtml) {
    for (final cell in _extractCells(rowHtml)) {
      if (!cell.isPeriodCell) {
        continue;
      }

      final plainText = _cleanText(_htmlToPlainText(cell.innerHtml));
      final match = RegExp(r'(\d{1,2})').firstMatch(plainText);
      if (match == null) {
        return null;
      }

      final period = int.tryParse(match.group(1)!);
      if (period == null || period < 1 || period > 13) {
        return null;
      }
      return period;
    }
    return null;
  }

  List<_HtmlCell> _extractCells(String rowHtml) {
    final matches = RegExp(
      r'<td\b([^>]*)>([\s\S]*?)<\/td>',
      caseSensitive: false,
    ).allMatches(rowHtml);

    return matches.map((match) {
      final attrs = match.group(1) ?? '';
      final innerHtml = match.group(2) ?? '';
      return _HtmlCell(
        className: _extractAttribute(attrs, 'class') ?? '',
        style: (_extractAttribute(attrs, 'style') ?? '').toLowerCase(),
        rowSpan: _parseRowSpan(_extractAttribute(attrs, 'rowspan')),
        innerHtml: innerHtml,
      );
    }).toList();
  }

  List<Course> _extractCoursesFromTdHtml({
    required String tdHtml,
    required int weekday,
    required int startPeriod,
    required int endPeriod,
  }) {
    final blocks = _splitCourseBlocks(tdHtml);
    if (blocks.isEmpty) {
      return const <Course>[];
    }

    final results = <Course>[];
    final seen = <String>{};

    for (final blockHtml in blocks) {
      final blockCourses = _parseBlock(
        blockHtml: blockHtml,
        weekday: weekday,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
      );

      for (final course in blockCourses) {
        final key = _courseKey(course);
        if (seen.add(key)) {
          results.add(course);
        }
      }
    }

    return results;
  }

  List<String> _splitCourseBlocks(String tdHtml) {
    final normalized = tdHtml.replaceAll(
      RegExp(r'<hr\b[^>]*\/?>', caseSensitive: false),
      '<!--COURSE-SPLIT-->',
    );
    final segments = normalized.split('<!--COURSE-SPLIT-->');
    final blocks = <String>[];

    final namePattern = RegExp(
      r"""<[^>]*class\s*=\s*['"][^'"]*course-name[^'"]*['"][^>]*>[\s\S]*?<\/[^>]+>""",
      caseSensitive: false,
    );

    for (final segment in segments) {
      final matches = namePattern.allMatches(segment).toList();
      if (matches.isEmpty) {
        continue;
      }

      for (var index = 0; index < matches.length; index += 1) {
        final start = matches[index].start;
        final end = index + 1 < matches.length
            ? matches[index + 1].start
            : segment.length;
        final block = segment.substring(start, end).trim();
        if (block.isNotEmpty) {
          blocks.add(block);
        }
      }
    }

    return blocks;
  }

  List<Course> _parseBlock({
    required String blockHtml,
    required int weekday,
    required int startPeriod,
    required int endPeriod,
  }) {
    final name = _extractCourseName(blockHtml);
    if (name.isEmpty) {
      return const <Course>[];
    }

    final plainText = _cleanText(_htmlToPlainText(blockHtml));
    if (plainText.isEmpty) {
      return const <Course>[];
    }

    final globalMatches = _extractGlobalMatches(
      name: name,
      plainText: plainText,
      weekday: weekday,
      fallbackStart: startPeriod,
      fallbackEnd: endPeriod,
    );
    if (globalMatches.isNotEmpty) {
      return globalMatches;
    }

    final detailText = _resolveDetailText(name: name, plainText: plainText);
    final detailSegments = _splitDetailSegments(detailText);
    if (detailSegments.isEmpty) {
      return <Course>[
        _buildCourse(
          name: name,
          location: '',
          teacher: '',
          weekday: weekday,
          weeks: const <int>[1],
          startPeriod: startPeriod,
          endPeriod: endPeriod,
        ),
      ];
    }

    final results = <Course>[];
    final seen = <String>{};
    for (final segment in detailSegments) {
      final parsedTail = _parseLocationAndTeacher(segment);
      final course = _buildCourse(
        name: name,
        location: parsedTail.location,
        teacher: parsedTail.teacher,
        weekday: weekday,
        weeks: _parseWeeks(segment),
        startPeriod: startPeriod,
        endPeriod: endPeriod,
      );
      final key = _courseKey(course);
      if (seen.add(key)) {
        results.add(course);
      }
    }

    return results.isEmpty
        ? <Course>[
            _buildCourse(
              name: name,
              location: '',
              teacher: '',
              weekday: weekday,
              weeks: const <int>[1],
              startPeriod: startPeriod,
              endPeriod: endPeriod,
            ),
          ]
        : results;
  }

  String _extractCourseName(String blockHtml) {
    final match = RegExp(
      r"""<[^>]*class\s*=\s*['"][^'"]*course-name[^'"]*['"][^>]*>([\s\S]*?)<\/[^>]+>""",
      caseSensitive: false,
    ).firstMatch(blockHtml);
    if (match == null) {
      return '';
    }
    return _cleanText(_htmlToPlainText(match.group(1)!));
  }

  List<Course> _extractGlobalMatches({
    required String name,
    required String plainText,
    required int weekday,
    required int fallbackStart,
    required int fallbackEnd,
  }) {
    final results = <Course>[];
    final seen = <String>{};
    final regex = RegExp(
      r'\(([\d,\-~\s]+)\s*[\u5468\u9031\u935B]\)\s*\(([\d\-~\s]+)\s*[\u8282\u7BC0\u947A]\)\s+(\S+)\s+(\S+)\s+([^\s()]+(?:/[^\s()]+)*)',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(plainText)) {
      final weeks = _parseWeeksFromParts(match.group(1) ?? '', '');
      final parsedPeriod = _parsePeriodRange(
        match.group(2) ?? '',
        fallbackStart,
        fallbackEnd,
      );
      final location = '${match.group(3) ?? ''} ${match.group(4) ?? ''}'
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final teacher = (match.group(5) ?? '').trim();
      final course = _buildCourse(
        name: name,
        location: location,
        teacher: teacher,
        weekday: weekday,
        weeks: weeks,
        startPeriod: parsedPeriod.startPeriod,
        endPeriod: parsedPeriod.endPeriod,
      );
      final key = _courseKey(course);
      if (seen.add(key)) {
        results.add(course);
      }
    }

    return results;
  }

  String _resolveDetailText({required String name, required String plainText}) {
    if (plainText.startsWith(name)) {
      return plainText.substring(name.length).trim();
    }

    return plainText.replaceFirst(name, '').trim();
  }

  List<String> _splitDetailSegments(String detailText) {
    final text = _normalizeDetailText(detailText);
    if (text.isEmpty) {
      return const <String>[];
    }

    final markers = _extractWeekMarkers(text);
    if (markers.length <= 1) {
      return <String>[text];
    }

    final segments = <String>[];
    for (var index = 0; index < markers.length; index += 1) {
      final start = markers[index].index;
      final end = index + 1 < markers.length
          ? markers[index + 1].index
          : text.length;
      final segment = text.substring(start, end).trim();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }

    return segments.isEmpty ? <String>[text] : segments;
  }

  List<int> _parseWeeks(String detailText) {
    final directMatch = RegExp(
      r'(?:\()?\s*([\d\s,\-~]+)\s*[\u5468\u9031\u935B](?:\(([\u5355\u53CC])\))?(?:\))?',
      caseSensitive: false,
    ).firstMatch(_normalizeDetailText(detailText));
    if (directMatch == null) {
      return const <int>[1];
    }
    return _parseWeeksFromParts(
      directMatch.group(1) ?? '',
      directMatch.group(2) ?? '',
    );
  }

  List<_WeekMarker> _extractWeekMarkers(String text) {
    final markers = <_WeekMarker>[];
    final regex = RegExp(
      r'(?:\()?\s*([\d\s,\-~]+)\s*[\u5468\u9031\u935B](?:\(([\u5355\u53CC])\))?(?:\))?',
      caseSensitive: false,
    );

    for (final match in regex.allMatches(text)) {
      markers.add(_WeekMarker(index: match.start));
    }
    return markers;
  }

  List<int> _parseWeeksFromParts(String rawBody, String oddEven) {
    final cleaned = rawBody
        .replaceAll(RegExp(r'[~\uFF5E]'), '-')
        .replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) {
      return const <int>[1];
    }

    final weeks = <int>{};
    for (final part in cleaned.split(',')) {
      if (part.isEmpty) {
        continue;
      }

      final rangeMatch = RegExp(r'^(\d{1,2})-(\d{1,2})$').firstMatch(part);
      if (rangeMatch != null) {
        final start = int.tryParse(rangeMatch.group(1)!);
        final end = int.tryParse(rangeMatch.group(2)!);
        if (start != null && end != null && start <= end) {
          for (var week = start; week <= end; week += 1) {
            weeks.add(week);
          }
        }
        continue;
      }

      final single = int.tryParse(part);
      if (single != null) {
        weeks.add(single);
      }
    }

    final sorted = weeks.toList()..sort();
    final filtered = oddEven == '\u5355'
        ? sorted.where((week) => week.isOdd).toList()
        : oddEven == '\u53CC'
        ? sorted.where((week) => week.isEven).toList()
        : sorted;

    return filtered.isEmpty ? const <int>[1] : filtered;
  }

  _PeriodRange _parsePeriodRange(
    String periodText,
    int fallbackStart,
    int fallbackEnd,
  ) {
    final text = periodText.trim();
    final rangeMatch = RegExp(
      r'^(\d{1,2})\s*[-~]\s*(\d{1,2})$',
    ).firstMatch(text);
    if (rangeMatch != null) {
      return _PeriodRange(
        startPeriod: int.parse(rangeMatch.group(1)!),
        endPeriod: int.parse(rangeMatch.group(2)!),
      );
    }

    final singleMatch = RegExp(r'^(\d{1,2})$').firstMatch(text);
    if (singleMatch != null) {
      final period = int.parse(singleMatch.group(1)!);
      return _PeriodRange(startPeriod: period, endPeriod: period);
    }

    return _PeriodRange(startPeriod: fallbackStart, endPeriod: fallbackEnd);
  }

  _LocationTeacher _parseLocationAndTeacher(String detailText) {
    final text = _stripTimingFragments(detailText);
    if (text.isEmpty) {
      return const _LocationTeacher(location: '', teacher: '');
    }

    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return const _LocationTeacher(location: '', teacher: '');
    }
    if (tokens.length == 1) {
      return _LocationTeacher(location: tokens.first, teacher: '');
    }

    final tailMatch = RegExp(
      r'(.+?)\s+([^\s()]+(?:/[^\s()]+)*)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (tailMatch == null) {
      return _LocationTeacher(location: text, teacher: '');
    }

    return _LocationTeacher(
      location: (tailMatch.group(1) ?? '').trim(),
      teacher: (tailMatch.group(2) ?? '').trim(),
    );
  }

  String _stripTimingFragments(String detailText) {
    return _normalizeDetailText(detailText)
        .replaceAll(
          RegExp(
            r'\(([\d\s,\-~]+)\s*[\u5468\u9031\u935B](?:\(([\u5355\u53CC])\))?\)',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\(\d{1,2}\s*-\s*\d{1,2}\s*[\u8282\u7BC0\u947A]\)'),
          ' ',
        )
        .replaceAll(RegExp(r'\(\d{1,2}\s*[\u8282\u7BC0\u947A]\)'), ' ')
        .replaceAll(RegExp(r'[()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeDetailText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[\uFF0C\u3001]'), ',')
        .replaceAll(RegExp(r'[~\uFF5E]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _htmlToPlainText(String html) {
    var plainText = html
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ');

    plainText = plainText
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s+\n'), '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n');

    return plainText.trim();
  }

  String _cleanText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Course _buildCourse({
    required String name,
    required String location,
    required String teacher,
    required int weekday,
    required List<int> weeks,
    required int startPeriod,
    required int endPeriod,
  }) {
    return Course(
      name: name,
      location: location,
      teacher: teacher,
      weekday: weekday,
      weeks: weeks,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      colorValue: _pickColor(name),
    );
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

  String? _extractAttribute(String attrs, String name) {
    final pattern = RegExp(
      '$name\\s*=\\s*([\'"])(.*?)\\1',
      caseSensitive: false,
    );
    return pattern.firstMatch(attrs)?.group(2);
  }

  int _parseRowSpan(String? rawValue) {
    final parsed = int.tryParse(rawValue ?? '1') ?? 1;
    return parsed.clamp(1, 99).toInt();
  }
}

class _HtmlCell {
  const _HtmlCell({
    required this.className,
    required this.style,
    required this.rowSpan,
    required this.innerHtml,
  });

  final String className;
  final String style;
  final int rowSpan;
  final String innerHtml;

  bool get isPeriodCell => className.contains('dayPartUnit');

  bool get isCourseCell => className.contains('td-content');

  bool get isHidden =>
      style.contains('display:none') || style.contains('display: none');

  int? get weekday {
    final match = RegExp(r'(?:^|\s)([1-7])(?:\s|$)').firstMatch(className);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String? get visibleTdHtml => innerHtml;
}

class _WeekMarker {
  const _WeekMarker({required this.index});

  final int index;
}

class _PeriodRange {
  const _PeriodRange({required this.startPeriod, required this.endPeriod});

  final int startPeriod;
  final int endPeriod;
}

class _LocationTeacher {
  const _LocationTeacher({required this.location, required this.teacher});

  final String location;
  final String teacher;
}
