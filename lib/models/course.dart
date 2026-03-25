class Course {
  Course({
    String? id,
    required this.name,
    required this.location,
    required this.teacher,
    required this.weekday,
    required List<int> weeks,
    required this.startPeriod,
    required this.endPeriod,
    required this.colorValue,
  }) : id = id ?? createId(),
       weeks = List<int>.unmodifiable(weeks);

  final String id;
  final String name;
  final String location;
  final String teacher;
  final int weekday;
  final List<int> weeks;
  final int startPeriod;
  final int endPeriod;
  final int colorValue;

  Course copyWith({
    String? id,
    String? name,
    String? location,
    String? teacher,
    int? weekday,
    List<int>? weeks,
    int? startPeriod,
    int? endPeriod,
    int? colorValue,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      teacher: teacher ?? this.teacher,
      weekday: weekday ?? this.weekday,
      weeks: weeks ?? this.weeks,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'teacher': teacher,
      'weekday': weekday,
      'weeks': weeks,
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
      'colorValue': colorValue,
    };
  }

  factory Course.fromJson(Map<String, dynamic> map) {
    final weeks = _parseWeeks(map['weeks']);
    final name = (map['name'] as String?) ?? 'Untitled Course';
    final location = (map['location'] as String?) ?? '';
    final teacher = (map['teacher'] as String?) ?? '';
    final weekday = (map['weekday'] as int?) ?? 1;
    final startPeriod = (map['startPeriod'] as int?) ?? 1;
    final endPeriod = (map['endPeriod'] as int?) ?? 2;
    final colorValue = (map['colorValue'] as int?) ?? 0xFF7C9AF2;

    return Course(
      id:
          (map['id'] as String?) ??
          createLegacyId(
            name: name,
            location: location,
            teacher: teacher,
            weekday: weekday,
            weeks: weeks,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            colorValue: colorValue,
          ),
      name: name,
      location: location,
      teacher: teacher,
      weekday: weekday,
      weeks: weeks,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      colorValue: colorValue,
    );
  }

  static String createId() {
    return 'course-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String createLegacyId({
    required String name,
    required String location,
    required String teacher,
    required int weekday,
    required List<int> weeks,
    required int startPeriod,
    required int endPeriod,
    required int colorValue,
  }) {
    final source = [
      name.trim(),
      location.trim(),
      teacher.trim(),
      weekday,
      weeks.join(','),
      startPeriod,
      endPeriod,
      colorValue,
    ].join('|');
    return 'course-${_stableHash(source)}';
  }

  static List<int> _parseWeeks(Object? rawWeeks) {
    if (rawWeeks is! List) {
      return const <int>[1];
    }

    return rawWeeks
        .map((item) {
          if (item is int) {
            return item;
          }
          if (item is num) {
            return item.toInt();
          }
          return int.tryParse(item.toString());
        })
        .whereType<int>()
        .toList();
  }

  static String _stableHash(String source) {
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
