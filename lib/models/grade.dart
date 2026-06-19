class GradeBook {
  const GradeBook({
    this.studentId,
    required this.fetchedAt,
    this.statistics,
    required this.terms,
  });

  final String? studentId;
  final DateTime fetchedAt;
  final GradeStatistics? statistics;
  final List<GradeTerm> terms;

  bool get isEmpty => terms.every((term) => term.records.isEmpty);
  int get recordCount =>
      terms.fold<int>(0, (total, term) => total + term.records.length);

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'fetchedAt': fetchedAt.toIso8601String(),
      'statistics': statistics?.toJson(),
      'terms': terms.map((term) => term.toJson()).toList(growable: false),
    };
  }

  factory GradeBook.fromJson(Map<String, dynamic> json) {
    return GradeBook(
      studentId: _stringOrNull(json['studentId']),
      fetchedAt:
          DateTime.tryParse('${json['fetchedAt'] ?? ''}') ?? DateTime(1970),
      statistics: _mapOrNull(json['statistics'], GradeStatistics.fromJson),
      terms: _mapList(json['terms'], GradeTerm.fromJson),
    );
  }
}

class GradeStatistics {
  const GradeStatistics({
    this.gpa,
    this.rank,
    this.rankTotal,
    this.totalCredits,
    this.inPlanCredits,
    this.outPlanCredits,
    this.updatedAtText,
  });

  final double? gpa;
  final int? rank;
  final int? rankTotal;
  final double? totalCredits;
  final double? inPlanCredits;
  final double? outPlanCredits;
  final String? updatedAtText;

  bool get isEmpty =>
      gpa == null &&
      rank == null &&
      rankTotal == null &&
      totalCredits == null &&
      inPlanCredits == null &&
      outPlanCredits == null &&
      updatedAtText == null;

  GradeStatistics fillMissingFrom(GradeStatistics fallback) {
    return GradeStatistics(
      gpa: gpa ?? fallback.gpa,
      rank: rank ?? fallback.rank,
      rankTotal: rankTotal ?? fallback.rankTotal,
      totalCredits: totalCredits ?? fallback.totalCredits,
      inPlanCredits: inPlanCredits ?? fallback.inPlanCredits,
      outPlanCredits: outPlanCredits ?? fallback.outPlanCredits,
      updatedAtText: updatedAtText ?? fallback.updatedAtText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gpa': gpa,
      'rank': rank,
      'rankTotal': rankTotal,
      'totalCredits': totalCredits,
      'inPlanCredits': inPlanCredits,
      'outPlanCredits': outPlanCredits,
      'updatedAtText': updatedAtText,
    };
  }

  factory GradeStatistics.fromJson(Map<String, dynamic> json) {
    return GradeStatistics(
      gpa: _doubleOrNull(json['gpa']),
      rank: _intOrNull(json['rank']),
      rankTotal: _intOrNull(json['rankTotal']),
      totalCredits: _doubleOrNull(json['totalCredits']),
      inPlanCredits: _doubleOrNull(json['inPlanCredits']),
      outPlanCredits: _doubleOrNull(json['outPlanCredits']),
      updatedAtText: _stringOrNull(json['updatedAtText']),
    );
  }
}

class GradeTerm {
  const GradeTerm({
    required this.remoteSemesterId,
    required this.semesterName,
    this.schoolYear,
    this.term,
    this.statistics,
    required this.records,
  });

  final String remoteSemesterId;
  final String semesterName;
  final String? schoolYear;
  final String? term;
  final GradeStatistics? statistics;
  final List<GradeRecord> records;

  Map<String, dynamic> toJson() {
    return {
      'remoteSemesterId': remoteSemesterId,
      'semesterName': semesterName,
      'schoolYear': schoolYear,
      'term': term,
      'statistics': statistics?.toJson(),
      'records': records
          .map((record) => record.toJson())
          .toList(growable: false),
    };
  }

  factory GradeTerm.fromJson(Map<String, dynamic> json) {
    return GradeTerm(
      remoteSemesterId: _stringOrEmpty(json['remoteSemesterId']),
      semesterName: _stringOrEmpty(json['semesterName']),
      schoolYear: _stringOrNull(json['schoolYear']),
      term: _stringOrNull(json['term']),
      statistics: _mapOrNull(json['statistics'], GradeStatistics.fromJson),
      records: _mapList(json['records'], GradeRecord.fromJson),
    );
  }
}

class GradeRecord {
  const GradeRecord({
    required this.courseCode,
    required this.courseName,
    this.credits,
    this.grade,
    this.gp,
    this.courseType,
    this.courseProperty,
    this.passed,
    this.published,
    this.gradeDetail,
    this.lessonCode,
  });

  final String courseCode;
  final String courseName;
  final double? credits;
  final String? grade;
  final double? gp;
  final String? courseType;
  final String? courseProperty;
  final bool? passed;
  final bool? published;
  final String? gradeDetail;
  final String? lessonCode;

  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'courseName': courseName,
      'credits': credits,
      'grade': grade,
      'gp': gp,
      'courseType': courseType,
      'courseProperty': courseProperty,
      'passed': passed,
      'published': published,
      'gradeDetail': gradeDetail,
      'lessonCode': lessonCode,
    };
  }

  factory GradeRecord.fromJson(Map<String, dynamic> json) {
    return GradeRecord(
      courseCode: _stringOrEmpty(json['courseCode']),
      courseName: _stringOrEmpty(json['courseName']),
      credits: _doubleOrNull(json['credits']),
      grade: _stringOrNull(json['grade']),
      gp: _doubleOrNull(json['gp']),
      courseType: _stringOrNull(json['courseType']),
      courseProperty: _stringOrNull(json['courseProperty']),
      passed: _boolOrNull(json['passed']),
      published: _boolOrNull(json['published']),
      gradeDetail: _stringOrNull(json['gradeDetail']),
      lessonCode: _stringOrNull(json['lessonCode']),
    );
  }
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic> json) decode) {
  if (raw is! List) {
    return <T>[];
  }
  return raw
      .whereType<Map>()
      .map((item) => decode(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

T? _mapOrNull<T>(Object? raw, T Function(Map<String, dynamic> json) decode) {
  if (raw is! Map) {
    return null;
  }
  return decode(Map<String, dynamic>.from(raw));
}

String _stringOrEmpty(Object? value) => _stringOrNull(value) ?? '';

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

double? _doubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('${value ?? ''}');
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}');
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
