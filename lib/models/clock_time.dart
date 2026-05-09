class ClockTime {
  const ClockTime({required this.hour, required this.minute});

  static const int minutesPerDay = 24 * 60;

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
    final normalizedMinutes = totalMinutes.remainder(minutesPerDay);
    final safeMinutes = normalizedMinutes < 0
        ? normalizedMinutes + minutesPerDay
        : normalizedMinutes;
    return ClockTime(hour: safeMinutes ~/ 60, minute: safeMinutes % 60);
  }

  bool get isValid24Hour =>
      hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;

  int toMinutes() => hour * 60 + minute;

  String format24Hour() {
    final normalized = ClockTime.fromMinutes(toMinutes());
    final formattedHour = normalized.hour.toString().padLeft(2, '0');
    final formattedMinute = normalized.minute.toString().padLeft(2, '0');
    return '$formattedHour:$formattedMinute';
  }
}
