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
    this.semesterId,
    this.rescheduledFromSessionKey,
    this.rescheduledFromWeek,
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
  final String? semesterId;
  final String? rescheduledFromSessionKey;
  final int? rescheduledFromWeek;

  String get sessionKey => buildSessionKey(
    name: name,
    location: location,
    teacher: teacher,
    weekday: weekday,
    startPeriod: startPeriod,
    endPeriod: endPeriod,
  );

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
    String? semesterId,
    String? rescheduledFromSessionKey,
    int? rescheduledFromWeek,
    bool clearRescheduleSource = false,
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
      semesterId: semesterId ?? this.semesterId,
      rescheduledFromSessionKey: clearRescheduleSource
          ? null
          : (rescheduledFromSessionKey ?? this.rescheduledFromSessionKey),
      rescheduledFromWeek: clearRescheduleSource
          ? null
          : (rescheduledFromWeek ?? this.rescheduledFromWeek),
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
      'semesterId': semesterId,
      'rescheduledFromSessionKey': rescheduledFromSessionKey,
      'rescheduledFromWeek': rescheduledFromWeek,
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
    final semesterId = map['semesterId'] as String?;
    final rescheduledFromSessionKey =
        map['rescheduledFromSessionKey'] as String?;
    final rescheduledFromWeek = map['rescheduledFromWeek'] as int?;

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
      semesterId: semesterId,
      rescheduledFromSessionKey: rescheduledFromSessionKey,
      rescheduledFromWeek: rescheduledFromWeek,
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

  static String buildSessionKey({
    required String name,
    required String location,
    required String teacher,
    required int weekday,
    required int startPeriod,
    required int endPeriod,
  }) {
    return [
      name.trim().toLowerCase(),
      location.trim().toLowerCase(),
      teacher.trim().toLowerCase(),
      weekday,
      startPeriod,
      endPeriod,
    ].join('|');
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
    var hash = 0x811c9dc5;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}
