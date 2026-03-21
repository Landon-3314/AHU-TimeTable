import 'package:flutter/material.dart';

class TimeSlot {
  const TimeSlot({
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.label,
  });

  final int periodNumber;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String label;
}
