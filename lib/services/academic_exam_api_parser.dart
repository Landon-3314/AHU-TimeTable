import 'dart:convert';

import '../models/event.dart';
import 'schedule_parser_service.dart';

class AcademicExamApiParser {
  const AcademicExamApiParser();

  List<Event> parseStudentExamInfoVms(String rawBody) {
    final raw = rawBody.trim();
    if (raw.isEmpty) {
      throw ScheduleParseException('考试接口返回为空。');
    }

    final decoded = _decodeJson(raw);
    if (decoded is! List) {
      throw ScheduleParseException('考试接口结构异常：studentExamInfoVms 不是数组。');
    }

    final exams = <Event>[];
    final seen = <String>{};
    for (final rawExam in decoded) {
      if (rawExam is! Map) {
        continue;
      }
      final exam = Map<String, dynamic>.from(rawExam);
      if (_boolValue(exam['finished']) == true) {
        continue;
      }
      final courseName = _nameText(exam['course']);
      if (courseName.isEmpty) {
        throw ScheduleParseException('无法识别考试课程名称。');
      }
      final examType = _nameText(exam['examType']);
      final startAt = _parseExamStartTime(_text(exam['examTime']));
      final seatNo = _text(exam['seatNo']);
      final event = Event(
        name: examType.isEmpty ? courseName : '$courseName（$examType）',
        location: _joinParts([
          _nameText(exam['requiredCampus']),
          _nameText(exam['room']),
        ]),
        note: seatNo.isEmpty ? '' : '座位号($seatNo)',
        dateTime: startAt,
        enableAlarm: true,
      );
      final key = _examKey(event);
      if (seen.add(key)) {
        exams.add(event);
      }
    }
    return List<Event>.unmodifiable(exams);
  }

  String? extractStudentExamInfoVms(String html) {
    final match = RegExp(
      r'studentExamInfoVms\s*=',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }
    final arrayStart = html.indexOf('[', match.end);
    if (arrayStart < 0) {
      return null;
    }
    final arrayEnd = _findMatchingBracket(html, arrayStart, '[', ']');
    if (arrayEnd < 0) {
      return null;
    }
    return html.substring(arrayStart, arrayEnd + 1);
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (error) {
      try {
        return jsonDecode(_normalizeJavaScriptLiteral(raw));
      } catch (_) {
        throw ScheduleParseException('考试接口 JSON 解析失败: $error');
      }
    }
  }

  String _normalizeJavaScriptLiteral(String raw) {
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

  DateTime _parseExamStartTime(String rawTime) {
    final match = RegExp(
      r'(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{2})',
    ).firstMatch(rawTime);
    if (match == null) {
      throw ScheduleParseException('无法识别考试开始时间: $rawTime');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final parsed = DateTime(year, month, day, hour, minute);
    if (parsed.year != year ||
        parsed.month != month ||
        parsed.day != day ||
        parsed.hour != hour ||
        parsed.minute != minute) {
      throw ScheduleParseException('无法识别考试开始时间: $rawTime');
    }
    return parsed;
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

  bool? _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = '${value ?? ''}'.toLowerCase();
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return null;
  }

  String _examKey(Event event) {
    return [
      event.name,
      event.location,
      event.note,
      event.dateTime.toIso8601String(),
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
