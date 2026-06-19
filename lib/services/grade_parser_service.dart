import 'dart:convert';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

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

    final statistics = _parseStatisticsModel(root['gpaSemesterModel']);
    final termStatisticsById = _parseTermStatisticsById(
      root['gpaSemesterModel'],
      rankTotalFallback: statistics?.rankTotal,
    );
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
          statistics: termStatisticsById[entry.key.toString()],
          records: records,
        ),
      );
    }

    return GradeBook(
      studentId: studentId,
      fetchedAt: fetchedAt,
      statistics: statistics,
      terms: List<GradeTerm>.unmodifiable(terms),
    );
  }

  GradeBook parseGradeSheetHtml(
    String rawHtml, {
    required String? studentId,
    required DateTime fetchedAt,
    bool allowEmptyTerms = false,
  }) {
    final document = html_parser.parse(rawHtml);
    final bodyStatistics = _parseStatisticsFromSummaryText(
      document.body?.text ?? '',
    );
    final scriptStatistics = _parseStatisticsFromGpaScript(rawHtml);
    final statistics =
        bodyStatistics?.fillMissingFrom(
          scriptStatistics ?? const GradeStatistics(),
        ) ??
        scriptStatistics;
    final semesterIdByName = _parseSemesterIdByName(rawHtml);
    final semesterNameById = {
      for (final entry in semesterIdByName.entries) entry.value: entry.key,
    };
    final termStatisticsById = _parseTermStatisticsFromGpaScript(
      rawHtml,
      rankTotalFallback: statistics?.rankTotal,
    );
    final orderedTermStatistics = termStatisticsById.values.toList(
      growable: false,
    );
    final terms = <GradeTerm>[];
    final headings = document.querySelectorAll('h3.semesterName');
    for (var index = 0; index < headings.length; index += 1) {
      final heading = headings[index];
      final semesterName = _text(heading.text) ?? '';
      if (semesterName.isEmpty) {
        continue;
      }
      final table = _findGradeTableForHeading(heading);
      if (table == null) {
        continue;
      }
      final records = _parseHtmlGradeTable(table);
      final remoteSemesterId = semesterIdByName[semesterName] ?? semesterName;
      terms.add(
        GradeTerm(
          remoteSemesterId: remoteSemesterId,
          semesterName: semesterName,
          statistics:
              termStatisticsById[remoteSemesterId] ??
              (orderedTermStatistics.length == headings.length
                  ? orderedTermStatistics[index]
                  : null),
          records: records,
        ),
      );
    }

    if (terms.isEmpty && allowEmptyTerms) {
      for (final entry in termStatisticsById.entries) {
        terms.add(
          GradeTerm(
            remoteSemesterId: entry.key,
            semesterName: semesterNameById[entry.key] ?? entry.key,
            statistics: entry.value,
            records: const <GradeRecord>[],
          ),
        );
      }
    }

    if (terms.isEmpty && (!allowEmptyTerms || statistics == null)) {
      throw ScheduleParseException('成绩页面未找到可解析的学期成绩。');
    }

    return GradeBook(
      studentId: studentId,
      fetchedAt: fetchedAt,
      statistics: statistics,
      terms: List<GradeTerm>.unmodifiable(terms),
    );
  }

  GradeBook mergeGradeBooks({
    required GradeBook primary,
    required GradeBook? metadataFallback,
  }) {
    if (metadataFallback == null) {
      return primary;
    }
    final fallbackTermsById = {
      for (final term in metadataFallback.terms) term.remoteSemesterId: term,
    };
    return GradeBook(
      studentId: primary.studentId ?? metadataFallback.studentId,
      fetchedAt: primary.fetchedAt,
      statistics:
          metadataFallback.statistics?.fillMissingFrom(
            primary.statistics ?? const GradeStatistics(),
          ) ??
          primary.statistics,
      terms: primary.terms
          .map((term) {
            final fallback = fallbackTermsById[term.remoteSemesterId];
            return GradeTerm(
              remoteSemesterId: term.remoteSemesterId,
              semesterName: term.semesterName,
              schoolYear: term.schoolYear,
              term: term.term,
              statistics: term.statistics ?? fallback?.statistics,
              records: term.records,
            );
          })
          .toList(growable: false),
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

  html_dom.Element? _findGradeTableForHeading(html_dom.Element heading) {
    html_dom.Element? scope = heading.parent;
    for (var depth = 0; depth < 3 && scope != null; depth += 1) {
      final table = scope.querySelector('table.student-grade-table, table');
      if (table != null) {
        return table;
      }
      scope = scope.parent;
    }
    return null;
  }

  List<GradeRecord> _parseHtmlGradeTable(html_dom.Element table) {
    final records = <GradeRecord>[];
    final rows = table.querySelectorAll('tr');
    for (final row in rows) {
      final cells = row.children
          .where((cell) => cell.localName == 'td' || cell.localName == 'th')
          .map((cell) => _text(cell.text) ?? '')
          .toList(growable: false);
      if (cells.length < 4 || cells.first == '课程名称') {
        continue;
      }
      final courseParts = _parseHtmlCourseCell(cells[0]);
      if (courseParts.name.isEmpty) {
        continue;
      }
      records.add(
        GradeRecord(
          courseCode: courseParts.code,
          courseName: courseParts.name,
          credits: _doubleOrNull(cells[1]),
          gp: _doubleOrNull(cells[2]),
          grade: _emptyDashAsNull(cells[3]),
          gradeDetail: cells.length > 4 ? _emptyDashAsNull(cells[4]) : null,
          courseType: courseParts.courseType,
          courseProperty: courseParts.courseProperty,
        ),
      );
    }
    return List<GradeRecord>.unmodifiable(records);
  }

  _HtmlCourseParts _parseHtmlCourseCell(String rawText) {
    final parts = rawText
        .split('|')
        .map((part) => _text(part) ?? '')
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final nameAndCode = parts.isEmpty ? rawText : parts.first;
    final match = RegExp(
      r'^(.*?)\s+([A-Za-z]{1,8}[A-Za-z0-9-]{2,})$',
    ).firstMatch(nameAndCode);
    final name = _text(match?.group(1) ?? nameAndCode) ?? '';
    return _HtmlCourseParts(
      name: name,
      code: _text(match?.group(2)) ?? '',
      courseType: parts.length > 1 ? parts[1] : null,
      courseProperty: parts.length > 2 ? parts[2] : null,
    );
  }

  GradeStatistics? _parseStatisticsModel(Object? value) {
    if (value is! Map) {
      return null;
    }
    final json = Map<String, dynamic>.from(value);
    final stats = GradeStatistics(
      gpa: _doubleOrNull(json['gpa']),
      rank: _intOrNull(json['majorRank'] ?? json['rank']),
      rankTotal: _intOrNull(json['majorHeadCount'] ?? json['rankTotal']),
      totalCredits: _doubleOrNull(json['totalCredits']),
      inPlanCredits: _doubleOrNull(json['inPlanCredits']),
      outPlanCredits: _doubleOrNull(json['outPlanCredits']),
      updatedAtText: _text(json['updatedDateTimeStr'] ?? json['updatedAtText']),
    );
    return stats.isEmpty ? null : stats;
  }

  Map<String, GradeStatistics> _parseTermStatisticsById(
    Object? value, {
    int? rankTotalFallback,
  }) {
    if (value is! Map) {
      return const <String, GradeStatistics>{};
    }
    final rawSubStats = value['gpaSemesterSubStr'] ?? value['gpaSemesterSubs'];
    return _parseTermStatisticsList(
      rawSubStats,
      rankTotalFallback: rankTotalFallback,
    );
  }

  GradeStatistics? _parseStatisticsFromGpaScript(String rawHtml) {
    final modelFragment = _gpaSemesterModelFragment(rawHtml);
    final stats = GradeStatistics(
      gpa: _numberFromScript(modelFragment, 'gpa'),
      rank: _intFromScript(modelFragment, 'majorRank'),
      rankTotal: _intFromScript(modelFragment, 'majorHeadCount'),
      totalCredits: _numberFromScript(modelFragment, 'totalCredits'),
      inPlanCredits: _numberFromScript(modelFragment, 'inPlanCredits'),
      outPlanCredits: _numberFromScript(modelFragment, 'outPlanCredits'),
      updatedAtText: _stringFromScript(modelFragment, 'updatedDateTimeStr'),
    );
    return stats.isEmpty ? null : stats;
  }

  Map<String, GradeStatistics> _parseTermStatisticsFromGpaScript(
    String rawHtml, {
    int? rankTotalFallback,
  }) {
    final encoded = _stringFromScript(rawHtml, 'gpaSemesterSubStr');
    return _parseTermStatisticsList(
      encoded,
      rankTotalFallback: rankTotalFallback,
    );
  }

  Map<String, GradeStatistics> _parseTermStatisticsList(
    Object? rawValue, {
    int? rankTotalFallback,
  }) {
    Object? decoded = rawValue;
    if (rawValue is String) {
      try {
        decoded = jsonDecode(rawValue);
      } catch (_) {
        decoded = null;
      }
    }
    if (decoded is! List) {
      return const <String, GradeStatistics>{};
    }
    final result = <String, GradeStatistics>{};
    for (final item in decoded.whereType<Map>()) {
      final json = Map<String, dynamic>.from(item);
      final semesterId = _text(json['semesterId']);
      if (semesterId == null) {
        continue;
      }
      final stats = GradeStatistics(
        gpa: _doubleOrNull(json['gpa']),
        rank: _intOrNull(json['majorRank'] ?? json['rank']),
        rankTotal:
            _intOrNull(json['majorHeadCount'] ?? json['rankTotal']) ??
            rankTotalFallback,
        totalCredits: _doubleOrNull(json['totalCredits']),
        inPlanCredits: _doubleOrNull(json['inPlanCredits']),
        outPlanCredits: _doubleOrNull(json['outPlanCredits']),
      );
      if (!stats.isEmpty) {
        result[semesterId] = stats;
      }
    }
    return Map<String, GradeStatistics>.unmodifiable(result);
  }

  GradeStatistics? _parseStatisticsFromSummaryText(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');
    final stats = GradeStatistics(
      gpa: _firstNumberAfter(normalized, 'GPA'),
      rank: _rankMatch(normalized)?.rank,
      rankTotal: _rankMatch(normalized)?.total,
      totalCredits: _firstNumberAfter(normalized, '全程总学分'),
      inPlanCredits: _firstNumberAfter(normalized, '计划内学分'),
      outPlanCredits: _firstNumberAfter(normalized, '计划外学分'),
      updatedAtText: RegExp(
        r'统计时间[:：]\s*([0-9]{4}-[0-9]{1,2}-[0-9]{1,2}\s+[0-9]{1,2}:[0-9]{1,2})',
      ).firstMatch(normalized)?.group(1),
    );
    return stats.isEmpty ? null : stats;
  }

  Map<String, String> _parseSemesterIdByName(String rawHtml) {
    final encoded = RegExp(
      r'''var\s+semesters\s*=\s*JSON\.parse\('((?:\\.|[^'])*)'\)''',
      dotAll: true,
    ).firstMatch(rawHtml)?.group(1);
    if (encoded == null) {
      return const <String, String>{};
    }
    Object? decoded;
    try {
      decoded = jsonDecode(_decodeJavaScriptString(encoded));
    } catch (_) {
      return const <String, String>{};
    }
    if (decoded is! List) {
      return const <String, String>{};
    }
    final result = <String, String>{};
    for (final item in decoded.whereType<Map>()) {
      final json = Map<String, dynamic>.from(item);
      final id = _text(json['id']);
      final name = _text(json['nameZh'] ?? json['name']);
      if (id != null && name != null) {
        result[name] = id;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }

  double? _numberFromScript(String rawHtml, String key) {
    final rawValue = _rawValueFromScript(rawHtml, key);
    return _doubleOrNull(rawValue);
  }

  int? _intFromScript(String rawHtml, String key) {
    final rawValue = _rawValueFromScript(rawHtml, key);
    return _intOrNull(rawValue);
  }

  String? _stringFromScript(String rawHtml, String key) {
    final rawValue = _rawValueFromScript(rawHtml, key);
    if (rawValue == null) {
      return null;
    }
    final text = _text(rawValue);
    return text == null ? null : _decodeJavaScriptString(text);
  }

  String? _rawValueFromScript(String rawHtml, String key) {
    final match = RegExp(
      '''['"]$key['"]\\s*:\\s*(?:'((?:\\\\.|[^'])*)'|"((?:\\\\.|[^"])*)"|([^,}\\n]+))''',
      dotAll: true,
    ).firstMatch(rawHtml);
    return match?.group(1) ?? match?.group(2) ?? match?.group(3);
  }

  String _gpaSemesterModelFragment(String rawHtml) {
    final start = rawHtml.indexOf('gpaSemesterModel');
    if (start < 0) {
      return rawHtml;
    }
    final objectStart = rawHtml.indexOf('{', start);
    if (objectStart < 0) {
      final end = (start + 5000).clamp(0, rawHtml.length);
      return rawHtml.substring(start, end);
    }
    final objectEnd = _matchingObjectEnd(rawHtml, objectStart);
    final fragment = objectEnd == null
        ? rawHtml.substring(
            objectStart,
            (objectStart + 5000).clamp(0, rawHtml.length),
          )
        : rawHtml.substring(objectStart, objectEnd + 1);
    return fragment.replaceAll(
      RegExp(
        r'''['"]?gpaSemesterSubStr['"]?\s*:\s*(?:'((?:\\.|[^'])*)'|"((?:\\.|[^"])*)")\s*,?''',
        dotAll: true,
      ),
      '',
    );
  }

  int? _matchingObjectEnd(String source, int objectStart) {
    var depth = 0;
    String? quote;
    var escaped = false;
    for (var index = objectStart; index < source.length; index += 1) {
      final char = source[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == quote) {
          quote = null;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '{') {
        depth += 1;
      } else if (char == '}') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }
    return null;
  }

  String _decodeJavaScriptString(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', r'\');
  }

  double? _firstNumberAfter(String text, String label) {
    final index = text.indexOf(label);
    if (index < 0) {
      return null;
    }
    final match = RegExp(
      r'([0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(text.substring(index + label.length));
    return _doubleOrNull(match?.group(1));
  }

  _RankParts? _rankMatch(String text) {
    final match = RegExp(r'排名[:：]?\s*([0-9]+)\s*/\s*([0-9]+)').firstMatch(text);
    if (match == null) {
      return null;
    }
    return _RankParts(
      rank: _intOrNull(match.group(1)),
      total: _intOrNull(match.group(2)),
    );
  }

  String? _emptyDashAsNull(String value) {
    final text = _text(value);
    if (text == null || text == '--' || text == '-') {
      return null;
    }
    return text;
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

  int? _intOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('${value ?? ''}'.trim());
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

class _HtmlCourseParts {
  const _HtmlCourseParts({
    required this.name,
    required this.code,
    this.courseType,
    this.courseProperty,
  });

  final String name;
  final String code;
  final String? courseType;
  final String? courseProperty;
}

class _RankParts {
  const _RankParts({required this.rank, required this.total});

  final int? rank;
  final int? total;
}
