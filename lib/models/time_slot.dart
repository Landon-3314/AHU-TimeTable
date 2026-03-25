import 'clock_time.dart';

class TimeSlot {
  const TimeSlot({
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.label,
  });

  final int periodNumber;
  final ClockTime startTime;
  final ClockTime endTime;
  final String label;
}
