import 'package:flutter/material.dart';

class Course {
  const Course({
    required this.name,
    required this.location,
    required this.teacher,
    required this.weekday,
    required this.weeks,
    required this.startPeriod,
    required this.endPeriod,
    required this.colorValue,
  });

  final String name;
  final String location;
  final String teacher;
  final int weekday;
  final List<int> weeks;
  final int startPeriod;
  final int endPeriod;
  final int colorValue;

  Color get color => Color(colorValue);

  Course copyWith({
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

  Map<String, dynamic> toMap() => toJson();

  factory Course.fromJson(Map<String, dynamic> map) {
    final dynamic rawWeeks = map['weeks'];
    final List<int> weeks = rawWeeks is List
        ? rawWeeks.map((item) => item as int).toList()
        : <int>[1];

    return Course(
      name: (map['name'] as String?) ?? 'Untitled Course',
      location: (map['location'] as String?) ?? '',
      teacher: (map['teacher'] as String?) ?? '',
      weekday: (map['weekday'] as int?) ?? 1,
      weeks: weeks,
      startPeriod: (map['startPeriod'] as int?) ?? 1,
      endPeriod: (map['endPeriod'] as int?) ?? 2,
      colorValue: (map['colorValue'] as int?) ?? 0xFF7C9AF2,
    );
  }

  factory Course.fromMap(Map<String, dynamic> map) => Course.fromJson(map);
}
