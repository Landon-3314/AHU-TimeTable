import 'dart:convert';

import '../models/course.dart';
import 'schedule_parser_service.dart';

class AcademicCourseApiParser {
  const AcademicCourseApiParser();

  static const int _maxSupportedWeek = 52;
  static const int _maxSupportedPeriod = 30;
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

  ScheduleParseReport<Course> parsePrintData(String rawBody) {
    final raw = rawBody.trim();
    if (raw.isEmpty) {
      throw ScheduleParseException('课表接口返回为空。');
    }

    final decoded = _decodeJson(raw);
    final root = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    final studentTables = root?['studentTableVms'];
    if (studentTables is! List) {
      throw ScheduleParseException('课表接口结构异常：缺少 studentTableVms。');
    }
    if (studentTables.isEmpty) {
      return const ScheduleParseReport<Course>(
        items: <Course>[],
        skippedReasons: <String>[],
      );
    }

    final firstTable = studentTables.first;
    if (firstTable is! Map) {
      throw ScheduleParseException('课表接口结构异常：studentTableVms[0] 不是对象。');
    }
    final activities = firstTable['activities'];
    if (activities is! List) {
      throw ScheduleParseException('课表接口结构异常：缺少 activities。');
    }

    final courses = <Course>[];
    final skippedReasons = <String>[];
    final seen = <String>{};
    for (final rawActivity in activities) {
      if (rawActivity is! Map) {
        skippedReasons.add('未知课程：activity 不是对象。');
        continue;
      }
      final activity = Map<String, dynamic>.from(rawActivity);
      final name = _text(activity['courseName']);
      try {
        if (name.isEmpty) {
          throw ScheduleParseException('课程名称为空。');
        }
        final course = Course(
          name: name,
          location: _joinParts([
            _nameText(activity['campus']),
            _nameText(activity['building']),
            _nameText(activity['room']),
          ]),
          teacher: _teacherText(activity),
          weekday: _validateInt(
            label: '星期',
            value: activity['weekday'],
            min: 1,
            max: 7,
          ),
          weeks: _parseWeekIndexes(activity['weekIndexes']),
          startPeriod: _validateInt(
            label: '开始节次',
            value: activity['startUnit'],
            min: 1,
            max: _maxSupportedPeriod,
          ),
          endPeriod: _validateInt(
            label: '结束节次',
            value: activity['endUnit'],
            min: 1,
            max: _maxSupportedPeriod,
          ),
          colorValue: _pickColor(name),
        );
        if (course.endPeriod < course.startPeriod) {
          throw ScheduleParseException('节次范围无效。');
        }
        final key = _courseKey(course);
        if (seen.add(key)) {
          courses.add(course);
        }
      } on ScheduleParseException catch (error) {
        skippedReasons.add('${name.isEmpty ? '未知课程' : name}: ${error.message}');
      }
    }

    return ScheduleParseReport<Course>(
      items: List<Course>.unmodifiable(courses),
      skippedReasons: List<String>.unmodifiable(skippedReasons),
    );
  }

  int? extractCurrentSemesterId(String html) {
    final jsonParseMatch = RegExp(
      r'''currentSemester\s*=\s*JSON\.parse\(\s*['"](.*?)['"]\s*\)''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (jsonParseMatch != null) {
      final parsed = _extractSemesterIdFromSnippet(
        jsonParseMatch.group(1)?.replaceAll(r'\"', '"') ?? '',
      );
      if (parsed != null) {
        return parsed;
      }
    }

    final variableMatch = RegExp(
      r'currentSemester\s*=',
      caseSensitive: false,
    ).firstMatch(html);
    if (variableMatch == null) {
      return int.tryParse(
        RegExp(
              r'currentSemesterId\s*[:=]\s*(\d+)',
              caseSensitive: false,
            ).firstMatch(html)?.group(1) ??
            '',
      );
    }

    final objectStart = html.indexOf('{', variableMatch.end);
    if (objectStart < 0) {
      return null;
    }
    final objectEnd = _findMatchingBracket(html, objectStart, '{', '}');
    if (objectEnd < 0) {
      return null;
    }
    final rawObject = html.substring(objectStart, objectEnd + 1);
    return _extractSemesterIdFromSnippet(rawObject);
  }

  int? _extractSemesterIdFromSnippet(String rawObject) {
    try {
      final decoded = jsonDecode(rawObject);
      if (decoded is Map) {
        return _intOrNull(decoded['id']);
      }
    } catch (_) {
      try {
        final decoded = jsonDecode(
          _normalizeJavaScriptObjectLiteral(rawObject),
        );
        if (decoded is Map) {
          return _intOrNull(decoded['id']);
        }
      } catch (_) {
        final idMatch = RegExp(
          r'''(?:^|[,{])\s*(?:id|'id'|"id")\s*:\s*(\d+)''',
          caseSensitive: false,
        ).allMatches(rawObject).lastOrNull;
        return int.tryParse(idMatch?.group(1) ?? '');
      }
    }
    return null;
  }

  String _normalizeJavaScriptObjectLiteral(String raw) {
    final quoted = _convertSingleQuotedStrings(raw);
    final withoutTrailingCommas = quoted.replaceAllMapped(
      RegExp(r',(\s*[\]}])'),
      (match) => match.group(1) ?? '',
    );
    return withoutTrailingCommas.replaceAllMapped(
      RegExp(r'([{,]\s*)([A-Za-z_$][\w$]*)\s*:'),
      (match) => '${match.group(1)}"${match.group(2)}":',
    );
  }

  String _convertSingleQuotedStrings(String raw) {
    final buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var escaped = false;
    for (var i = 0; i < raw.length; i += 1) {
      final char = raw[i];
      if (inSingleQuote) {
        if (escaped) {
          escaped = false;
          if (char == "'") {
            buffer.write("'");
          } else if (char == '"') {
            buffer.write(r'\"');
          } else if (char == '\\') {
            buffer.write(r'\\');
          } else {
            buffer.write('\\$char');
          }
          continue;
        }
        if (char == '\\') {
          escaped = true;
          continue;
        }
        if (char == "'") {
          inSingleQuote = false;
          buffer.write('"');
          continue;
        }
        if (char == '"') {
          buffer.write(r'\"');
        } else if (char == '\n') {
          buffer.write(r'\n');
        } else if (char == '\r') {
          buffer.write(r'\r');
        } else {
          buffer.write(char);
        }
        continue;
      }

      if (inDoubleQuote) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inDoubleQuote = false;
        }
        continue;
      }

      if (char == "'") {
        inSingleQuote = true;
        buffer.write('"');
      } else {
        if (char == '"') {
          inDoubleQuote = true;
        }
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (error) {
      throw ScheduleParseException('课表接口 JSON 解析失败: $error');
    }
  }

  List<int> _parseWeekIndexes(Object? rawValue) {
    if (rawValue is! List) {
      throw ScheduleParseException('周次为空。');
    }
    final weeks =
        rawValue
            .map(_intOrNull)
            .whereType<int>()
            .where((week) => week >= 1 && week <= _maxSupportedWeek)
            .toSet()
            .toList()
          ..sort();
    if (weeks.isEmpty) {
      throw ScheduleParseException('周次范围无效。');
    }
    if (weeks.length != rawValue.length) {
      throw ScheduleParseException('周次范围无效。');
    }
    return weeks;
  }

  int _validateInt({
    required String label,
    required Object? value,
    required int min,
    required int max,
  }) {
    final parsed = _intOrNull(value);
    if (parsed == null || parsed < min || parsed > max) {
      throw ScheduleParseException('$label范围无效。');
    }
    return parsed;
  }

  String _teacherText(Map<String, dynamic> activity) {
    final teacherNames = activity['teacherNames'];
    if (teacherNames is List) {
      return _joinNames(teacherNames.map(_nameText));
    }
    final teacherText = _text(teacherNames);
    if (teacherText.isNotEmpty) {
      return teacherText;
    }

    final teachers = activity['teachers'];
    if (teachers is List) {
      return _joinNames(teachers.map(_nameText));
    }
    return _nameText(teachers);
  }

  String _joinNames(Iterable<Object?> values) {
    final parts = <String>[];
    for (final value in values) {
      final text = value is String ? _text(value) : _nameText(value);
      if (text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }
    return parts.join('、');
  }

  String _nameText(Object? value) {
    if (value is Map) {
      return _text(
        value['nameZh'] ?? value['name'] ?? value['label'] ?? value['text'],
      );
    }
    return _text(value);
  }

  String _joinParts(Iterable<Object?> values) {
    final parts = <String>[];
    for (final value in values) {
      final text = value is String ? _text(value) : _nameText(value);
      if (text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }
    return parts.join(' ');
  }

  String _text(Object? value) {
    if (value == null) {
      return '';
    }
    return value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int? _intOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('${value ?? ''}'.trim());
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

  int _findMatchingBracket(
    String source,
    int start,
    String open,
    String close,
  ) {
    var depth = 0;
    var inString = false;
    var quote = '';
    var escaped = false;
    for (var i = start; i < source.length; i += 1) {
      final char = source[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == quote) {
          inString = false;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }
      if (char == open) {
        depth += 1;
      } else if (char == close) {
        depth -= 1;
        if (depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }
}
