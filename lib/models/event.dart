class Event {
  Event({
    String? id,
    required this.name,
    required this.location,
    this.note = '',
    required this.dateTime,
    required this.enableAlarm,
    this.semesterId,
  }) : id = id ?? createId();

  final String id;
  final String name;
  final String location;
  final String note;
  final DateTime dateTime;
  final bool enableAlarm;
  final String? semesterId;

  Event copyWith({
    String? id,
    String? name,
    String? location,
    String? note,
    DateTime? dateTime,
    bool? enableAlarm,
    String? semesterId,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      note: note ?? this.note,
      dateTime: dateTime ?? this.dateTime,
      enableAlarm: enableAlarm ?? this.enableAlarm,
      semesterId: semesterId ?? this.semesterId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'note': note,
      'dateTime': dateTime.toIso8601String(),
      'enableAlarm': enableAlarm,
      'semesterId': semesterId,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? 'Untitled Event';
    final location = (json['location'] as String?) ?? '';
    final note = (json['note'] as String?) ?? '';
    final dateTime =
        DateTime.tryParse((json['dateTime'] as String?) ?? '') ??
        DateTime.now();
    final enableAlarm = (json['enableAlarm'] as bool?) ?? false;
    final semesterId = json['semesterId'] as String?;

    return Event(
      id:
          (json['id'] as String?) ??
          createLegacyId(
            name: name,
            location: location,
            dateTime: dateTime,
            enableAlarm: enableAlarm,
          ),
      name: name,
      location: location,
      note: note,
      dateTime: dateTime,
      enableAlarm: enableAlarm,
      semesterId: semesterId,
    );
  }

  static String createId() {
    return 'event-${DateTime.now().microsecondsSinceEpoch}';
  }

  static String createLegacyId({
    required String name,
    required String location,
    required DateTime dateTime,
    required bool enableAlarm,
  }) {
    final source = [
      name.trim(),
      location.trim(),
      dateTime.toIso8601String(),
      enableAlarm,
    ].join('|');
    return 'event-${_stableHash(source)}';
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
