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
    required int shortBreak,
    required int bigBreak,
    required ClockTime morningStartTime,
    required int morningClasses,
    required ClockTime afternoonStartTime,
    required int afternoonClasses,
    required ClockTime eveningStartTime,
    required int eveningClasses,
  }) {
    final slots = <TimeSlot>[];
    var periodNumber = 1;

    periodNumber = _appendSessionSlots(
      slots: slots,
      startTime: morningStartTime,
      count: morningClasses,
      classDuration: classDuration,
      shortBreak: shortBreak,
      bigBreak: bigBreak,
      periodNumber: periodNumber,
      label: 'Morning',
      hasBigBreak: true,
    );
    periodNumber = _appendSessionSlots(
      slots: slots,
      startTime: afternoonStartTime,
      count: afternoonClasses,
      classDuration: classDuration,
      shortBreak: shortBreak,
      bigBreak: bigBreak,
      periodNumber: periodNumber,
      label: 'Afternoon',
      hasBigBreak: true,
    );
    _appendSessionSlots(
      slots: slots,
      startTime: eveningStartTime,
      count: eveningClasses,
      classDuration: classDuration,
      shortBreak: shortBreak,
      bigBreak: bigBreak,
      periodNumber: periodNumber,
      label: 'Evening',
      hasBigBreak: false,
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
    required ClockTime startTime,
    required int count,
    required int classDuration,
    required int shortBreak,
    required int bigBreak,
    required int periodNumber,
    required String label,
    required bool hasBigBreak,
  }) {
    var currentStartMinutes = startTime.toMinutes();

    for (var index = 1; index <= count; index += 1) {
      final classStartMinutes = currentStartMinutes;
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
      currentStartMinutes = classEndMinutes;

      if (index == count) {
        continue;
      }

      currentStartMinutes += hasBigBreak && index == 2 ? bigBreak : shortBreak;
    }

    return periodNumber;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
