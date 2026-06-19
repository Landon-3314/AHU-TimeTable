import 'dart:convert';

import '../models/grade.dart';
import 'schedule_parser_service.dart';

class GradeParserService {
  const GradeParserService();

  GradeBook parseGradeInfo(
    String rawBody, {
    required String? studentId,
    required DateTime fetchedAt,
  }) {
    final raw = rawBody.trim();
    if (raw.isEmpty) {
      throw ScheduleParseException('成绩接口返回为空。');
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw ScheduleParseException('成绩接口结构异常。');
    }
    final root = Map<String, dynamic>.from(decoded);
    final grouped = root['semesterId2studentGrades'];
    if (grouped is! Map) {
      throw ScheduleParseException('成绩接口结构异常：缺少 semesterId2studentGrades。');
    }

    final terms = <GradeTerm>[];
    for (final entry in grouped.entries) {
      final recordsRaw = entry.value;
      if (recordsRaw is! List) {
        continue;
      }
      final records = recordsRaw
          .whereType<Map>()
          .map((item) => _parseRecord(Map<String, dynamic>.from(item)))
          .where((record) => record.courseName.isNotEmpty)
          .toList(growable: false);
      final firstRecord = recordsRaw.whereType<Map>().isEmpty
          ? null
          : Map<String, dynamic>.from(recordsRaw.whereType<Map>().first);
      terms.add(
        GradeTerm(
          remoteSemesterId: entry.key.toString(),
          semesterName:
              _text(firstRecord?['semesterName']) ?? entry.key.toString(),
          schoolYear: _text(firstRecord?['schoolYear']),
          term: _text(firstRecord?['term']),
          records: records,
        ),
      );
    }

    return GradeBook(
      studentId: studentId,
      fetchedAt: fetchedAt,
      terms: List<GradeTerm>.unmodifiable(terms),
    );
  }

  String? extractStudentIdFromGradeSheetUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    final last = segments.isEmpty ? '' : segments.last;
    return RegExp(r'^\d+$').hasMatch(last) ? last : null;
  }

  GradeRecord _parseRecord(Map<String, dynamic> item) {
    return GradeRecord(
      courseCode: _text(item['courseCode']) ?? '',
      courseName: _text(item['courseName']) ?? '',
      credits: _doubleOrNull(item['credits']),
      grade: _text(item['gaGrade']) ?? _text(item['grade']),
      gp: _doubleOrNull(item['gp']),
      courseType: _nameText(item['courseType']),
      courseProperty: _nameText(item['courseProperty']),
      passed: _boolOrNull(item['passed']),
      published: _boolOrNull(item['published']),
      gradeDetail: _text(item['gradeDetail']),
      lessonCode: _text(item['lessonCode']),
    );
  }

  String? _nameText(Object? value) {
    if (value is Map) {
      return _text(value['nameZh'] ?? value['name'] ?? value['label']);
    }
    return _text(value);
  }

  String? _text(Object? value) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text == null || text.isEmpty ? null : text;
  }

  double? _doubleOrNull(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('${value ?? ''}'.trim());
  }

  bool? _boolOrNull(Object? value) {
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
}
