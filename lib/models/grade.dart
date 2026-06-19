class GradeBook {
  const GradeBook({
    this.studentId,
    required this.fetchedAt,
    required this.terms,
  });

  final String? studentId;
  final DateTime fetchedAt;
  final List<GradeTerm> terms;

  bool get isEmpty => terms.every((term) => term.records.isEmpty);

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'fetchedAt': fetchedAt.toIso8601String(),
      'terms': terms.map((term) => term.toJson()).toList(growable: false),
    };
  }

  factory GradeBook.fromJson(Map<String, dynamic> json) {
    return GradeBook(
      studentId: _stringOrNull(json['studentId']),
      fetchedAt:
          DateTime.tryParse('${json['fetchedAt'] ?? ''}') ?? DateTime(1970),
      terms: _mapList(json['terms'], GradeTerm.fromJson),
    );
  }
}

class GradeTerm {
  const GradeTerm({
    required this.remoteSemesterId,
    required this.semesterName,
    this.schoolYear,
    this.term,
    required this.records,
  });

  final String remoteSemesterId;
  final String semesterName;
  final String? schoolYear;
  final String? term;
  final List<GradeRecord> records;

  Map<String, dynamic> toJson() {
    return {
      'remoteSemesterId': remoteSemesterId,
      'semesterName': semesterName,
      'schoolYear': schoolYear,
      'term': term,
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
