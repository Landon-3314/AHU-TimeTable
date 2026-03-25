class Event {
  Event({
    String? id,
    required this.name,
    required this.location,
    required this.dateTime,
    required this.enableAlarm,
  }) : id = id ?? createId();

  final String id;
  final String name;
  final String location;
  final DateTime dateTime;
  final bool enableAlarm;

  Event copyWith({
    String? id,
    String? name,
    String? location,
    DateTime? dateTime,
    bool? enableAlarm,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      dateTime: dateTime ?? this.dateTime,
      enableAlarm: enableAlarm ?? this.enableAlarm,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'dateTime': dateTime.toIso8601String(),
      'enableAlarm': enableAlarm,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? 'Untitled Event';
    final location = (json['location'] as String?) ?? '';
    final dateTime =
        DateTime.tryParse((json['dateTime'] as String?) ?? '') ??
        DateTime.now();
    final enableAlarm = (json['enableAlarm'] as bool?) ?? false;

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
      dateTime: dateTime,
      enableAlarm: enableAlarm,
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
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in source.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
