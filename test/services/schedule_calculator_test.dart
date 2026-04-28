import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/models/clock_time.dart';
import 'package:timetable/services/schedule_calculator.dart';

void main() {
  test('generates slots from explicit session start times', () {
    final slots = const ScheduleCalculator().generateTimeSlots(
      classDuration: 45,
      morningStartTimes: const [
        ClockTime(hour: 8, minute: 0),
        ClockTime(hour: 8, minute: 55),
      ],
      afternoonStartTimes: const [ClockTime(hour: 14, minute: 0)],
      eveningStartTimes: const [ClockTime(hour: 19, minute: 0)],
    );

    expect(slots, hasLength(4));
    expect(slots[0].periodNumber, 1);
    expect(slots[0].startTime.format24Hour(), '08:00');
    expect(slots[0].endTime.format24Hour(), '08:45');
    expect(slots[0].label, 'Morning');
    expect(slots[1].periodNumber, 2);
    expect(slots[1].startTime.format24Hour(), '08:55');
    expect(slots[2].periodNumber, 3);
    expect(slots[2].label, 'Afternoon');
    expect(slots[3].periodNumber, 4);
    expect(slots[3].label, 'Evening');
  });
}
