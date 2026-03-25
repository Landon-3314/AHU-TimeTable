class ClockTime {
  const ClockTime({required this.hour, required this.minute});

  final int hour;
  final int minute;

  factory ClockTime.fromString(String value) {
    final parts = value.split(':');
    return ClockTime(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  factory ClockTime.fromMinutes(int totalMinutes) {
    return ClockTime(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
  }

  int toMinutes() => hour * 60 + minute;

  String format24Hour() {
    final normalizedHour = hour.toString().padLeft(2, '0');
    final normalizedMinute = minute.toString().padLeft(2, '0');
    return '$normalizedHour:$normalizedMinute';
  }
}
