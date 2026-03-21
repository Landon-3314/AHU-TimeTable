class Event {
  const Event({
    required this.id,
    required this.name,
    required this.location,
    required this.dateTime,
    required this.enableAlarm,
  });

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
    return Event(
      id: (json['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Untitled Event',
      location: (json['location'] as String?) ?? '',
      dateTime: DateTime.tryParse((json['dateTime'] as String?) ?? '') ??
          DateTime.now(),
      enableAlarm: (json['enableAlarm'] as bool?) ?? false,
    );
  }
}
