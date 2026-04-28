import '../models/clock_time.dart';
import '../models/time_slot.dart';

class ScheduleCalculator {
  const ScheduleCalculator();

  int computeCurrentWeek({
    required DateTime semesterStartDate,
    required int totalWeeks,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final diffDays = today.difference(semesterStartDate).inDays;
    final week = (diffDays ~/ 7) + 1;
    return week.clamp(1, totalWeeks).toInt();
  }

  int computeCurrentWeekday({DateTime? now}) {
    return (now ?? DateTime.now()).weekday.clamp(1, 7).toInt();
  }

  DateTime getDateFor({
    required DateTime semesterStartDate,
    required int totalWeeks,
    required int week,
    required int weekday,
  }) {
    final safeWeek = week.clamp(1, totalWeeks).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    return semesterStartDate.add(
      Duration(days: (safeWeek - 1) * 7 + (safeWeekday - 1)),
    );
  }

  List<TimeSlot> generateTimeSlots({
    required int classDuration,
    required List<ClockTime> morningStartTimes,
    required List<ClockTime> afternoonStartTimes,
    required List<ClockTime> eveningStartTimes,
  }) {
    final slots = <TimeSlot>[];
    var periodNumber = 1;

    periodNumber = _appendSessionSlots(
      slots: slots,
      startTimes: morningStartTimes,
      classDuration: classDuration,
      periodNumber: periodNumber,
      label: 'Morning',
    );
    periodNumber = _appendSessionSlots(
      slots: slots,
      startTimes: afternoonStartTimes,
      classDuration: classDuration,
      periodNumber: periodNumber,
      label: 'Afternoon',
    );
    _appendSessionSlots(
      slots: slots,
      startTimes: eveningStartTimes,
      classDuration: classDuration,
      periodNumber: periodNumber,
      label: 'Evening',
    );

    return slots;
  }

  DateTime alignToMonday(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  DateTime defaultSemesterStartDate({DateTime? now}) {
    return alignToMonday(now ?? DateTime.now());
  }

  int _appendSessionSlots({
    required List<TimeSlot> slots,
    required List<ClockTime> startTimes,
    required int classDuration,
    required int periodNumber,
    required String label,
  }) {
    for (final startTime in startTimes) {
      final classStartMinutes = startTime.toMinutes();
      final classEndMinutes = classStartMinutes + classDuration;

      slots.add(
        TimeSlot(
          periodNumber: periodNumber,
          startTime: ClockTime.fromMinutes(classStartMinutes),
          endTime: ClockTime.fromMinutes(classEndMinutes),
          label: label,
        ),
      );

      periodNumber += 1;
    }

    return periodNumber;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
