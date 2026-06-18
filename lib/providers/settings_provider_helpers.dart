part of 'settings_provider.dart';

List<String> _restoreSessionStartTimesFromStorage(
  StorageService storageService,
  ClassDayPeriod period,
) {
  final morningClasses = storageService.readMorningClasses(
    fallback: SettingsProvider._defaultMorningClasses,
  );
  final afternoonClasses = storageService.readAfternoonClasses(
    fallback: SettingsProvider._defaultAfternoonClasses,
  );
  final eveningClasses = storageService.readEveningClasses(
    fallback: SettingsProvider._defaultEveningClasses,
  );
  final totalClassPeriods = morningClasses + afternoonClasses + eveningClasses;
  final bigBreakAfterPeriods = _restoreBigBreakAfterPeriodsFromStorage(
    storageService,
  );

  return _restoreSessionStartTimes(
    storedValues: switch (period) {
      ClassDayPeriod.morning => storageService.readMorningPeriodStartTimes(),
      ClassDayPeriod.afternoon =>
        storageService.readAfternoonPeriodStartTimes(),
      ClassDayPeriod.evening => storageService.readEveningPeriodStartTimes(),
    },
    fallbackStartTime: switch (period) {
      ClassDayPeriod.morning => storageService.readMorningStartTime(
        fallback: SettingsProvider._defaultMorningStartTime,
      ),
      ClassDayPeriod.afternoon => storageService.readAfternoonStartTime(
        fallback: SettingsProvider._defaultAfternoonStartTime,
      ),
      ClassDayPeriod.evening => storageService.readEveningStartTime(
        fallback: SettingsProvider._defaultEveningStartTime,
      ),
    },
    count: switch (period) {
      ClassDayPeriod.morning => morningClasses,
      ClassDayPeriod.afternoon => afternoonClasses,
      ClassDayPeriod.evening => eveningClasses,
    },
    firstPeriodNumber: _firstPeriodNumberForCounts(
      period,
      morningClasses: morningClasses,
      afternoonClasses: afternoonClasses,
    ),
    classDuration: storageService.readClassDuration(
      fallback: SettingsProvider._defaultClassDuration,
    ),
    shortBreak: storageService.readShortBreak(
      fallback: SettingsProvider._defaultShortBreak,
    ),
    bigBreakEnabled: storageService.readBigBreakEnabled(
      fallback: SettingsProvider._defaultBigBreakEnabled,
    ),
    bigBreak: storageService.readBigBreak(
      fallback: SettingsProvider._defaultBigBreak,
    ),
    bigBreakAfterPeriods: _sanitizeBigBreakAfterPeriods(
      bigBreakAfterPeriods,
      totalClassPeriods,
    ),
  );
}

List<String> _restoreSessionStartTimes({
  required List<String>? storedValues,
  required String fallbackStartTime,
  required int count,
  required int firstPeriodNumber,
  required int classDuration,
  required int shortBreak,
  required bool bigBreakEnabled,
  required int bigBreak,
  required Iterable<int> bigBreakAfterPeriods,
}) {
  final safeCount = count.clamp(0, 12).toInt();
  if (safeCount == 0) {
    return <String>[];
  }

  final values = (storedValues ?? <String>[])
      .where(_isValidStoredTimeString)
      .toList();
  if (values.isEmpty) {
    values.add(
      _isValidStoredTimeString(fallbackStartTime)
          ? fallbackStartTime
          : SettingsProvider._defaultMorningStartTime,
    );
  }

  while (values.length < safeCount) {
    values.add(
      _nextStoredStartTime(
        values.last,
        firstPeriodNumber: firstPeriodNumber,
        previousIndex: values.length - 1,
        classDuration: classDuration,
        shortBreak: shortBreak,
        bigBreakEnabled: bigBreakEnabled,
        bigBreak: bigBreak,
        bigBreakAfterPeriods: bigBreakAfterPeriods,
      ),
    );
  }
  if (values.length > safeCount) {
    return values.take(safeCount).toList();
  }
  return values;
}

String _nextStoredStartTime(
  String previousStartTime, {
  required int firstPeriodNumber,
  required int previousIndex,
  required int classDuration,
  required int shortBreak,
  required bool bigBreakEnabled,
  required int bigBreak,
  required Iterable<int> bigBreakAfterPeriods,
}) {
  final previous = ClockTime.fromString(previousStartTime);
  final previousPeriodNumber = firstPeriodNumber + previousIndex;
  final nextMinutes =
      previous.toMinutes() +
      classDuration +
      _breakAfterPeriod(
        previousPeriodNumber: previousPeriodNumber,
        shortBreak: shortBreak,
        bigBreakEnabled: bigBreakEnabled,
        bigBreak: bigBreak,
        bigBreakAfterPeriods: bigBreakAfterPeriods,
      );
  return ClockTime.fromMinutes(nextMinutes).format24Hour();
}

int _breakAfterPeriod({
  required int previousPeriodNumber,
  required int shortBreak,
  required bool bigBreakEnabled,
  required int bigBreak,
  required Iterable<int> bigBreakAfterPeriods,
}) {
  final usesBigBreak =
      bigBreakEnabled && bigBreakAfterPeriods.contains(previousPeriodNumber);
  return usesBigBreak ? bigBreak : shortBreak;
}

int _firstPeriodNumberForCounts(
  ClassDayPeriod period, {
  required int morningClasses,
  required int afternoonClasses,
}) {
  switch (period) {
    case ClassDayPeriod.morning:
      return 1;
    case ClassDayPeriod.afternoon:
      return morningClasses + 1;
    case ClassDayPeriod.evening:
      return morningClasses + afternoonClasses + 1;
  }
}

List<int> _restoreBigBreakAfterPeriodsFromStorage(
  StorageService storageService,
) {
  final morningClasses = storageService.readMorningClasses(
    fallback: SettingsProvider._defaultMorningClasses,
  );
  final afternoonClasses = storageService.readAfternoonClasses(
    fallback: SettingsProvider._defaultAfternoonClasses,
  );
  final eveningClasses = storageService.readEveningClasses(
    fallback: SettingsProvider._defaultEveningClasses,
  );
  final totalClassPeriods = morningClasses + afternoonClasses + eveningClasses;
  return _sanitizeBigBreakAfterPeriods(
    storageService.readBigBreakAfterPeriods() ??
        _defaultBigBreakAfterPeriods(
          morningClasses: morningClasses,
          afternoonClasses: afternoonClasses,
          totalClassPeriods: totalClassPeriods,
        ),
    totalClassPeriods,
  );
}

List<int> _defaultBigBreakAfterPeriods({
  required int morningClasses,
  required int afternoonClasses,
  required int totalClassPeriods,
}) {
  final values = <int>[];
  if (morningClasses >= 3) {
    values.add(2);
  }
  if (afternoonClasses >= 3) {
    values.add(morningClasses + 2);
  }
  return _sanitizeBigBreakAfterPeriods(values, totalClassPeriods);
}

List<int> _sanitizeBigBreakAfterPeriods(
  Iterable<int> values,
  int totalClassPeriods,
) {
  final maxPeriod = totalClassPeriods - 1;
  if (maxPeriod < 1) {
    return <int>[];
  }
  final unique =
      values.where((value) => value >= 1 && value <= maxPeriod).toSet().toList()
        ..sort();
  return unique;
}

bool _listEquals(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _isValidStoredTimeString(String value) {
  final parts = value.split(':');
  if (parts.length != 2) {
    return false;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  return hour != null &&
      minute != null &&
      hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59;
}

DateTime _restoreSemesterStartDate({
  required StorageService storageService,
  required ScheduleCalculator scheduleCalculator,
}) {
  final storedValue = storageService.readSemesterStartDate();
  if (storedValue == null) {
    return scheduleCalculator.defaultSemesterStartDate();
  }
  return scheduleCalculator.alignToMonday(storedValue);
}

class _ThemeSettingsSnapshot {
  const _ThemeSettingsSnapshot({
    required this.appThemeMode,
    required this.themePaletteId,
    required this.customThemePrimaryValue,
    required this.customThemeAccentValue,
  });

  final AppThemeMode appThemeMode;
  final String themePaletteId;
  final int customThemePrimaryValue;
  final int customThemeAccentValue;
}

class _PeriodSettingsSnapshot {
  const _PeriodSettingsSnapshot({
    required this.classDuration,
    required this.shortBreak,
    required this.bigBreakEnabled,
    required this.bigBreak,
    required this.bigBreakAfterPeriods,
    required this.morningStartTime,
    required this.morningClasses,
    required this.afternoonStartTime,
    required this.afternoonClasses,
    required this.eveningStartTime,
    required this.eveningClasses,
    required this.morningPeriodStartTimes,
    required this.afternoonPeriodStartTimes,
    required this.eveningPeriodStartTimes,
  });

  final int classDuration;
  final int shortBreak;
  final bool bigBreakEnabled;
  final int bigBreak;
  final List<int> bigBreakAfterPeriods;
  final String morningStartTime;
  final int morningClasses;
  final String afternoonStartTime;
  final int afternoonClasses;
  final String eveningStartTime;
  final int eveningClasses;
  final List<String> morningPeriodStartTimes;
  final List<String> afternoonPeriodStartTimes;
  final List<String> eveningPeriodStartTimes;
}

class _ReminderSettingsSnapshot {
  const _ReminderSettingsSnapshot({
    required this.reminderAdvanceMinutes,
    required this.eventReminderAdvanceMinutes,
    required this.autoMuteEnabled,
    required this.courseReminderPersistentDisplayEnabled,
  });

  final int reminderAdvanceMinutes;
  final int eventReminderAdvanceMinutes;
  final bool autoMuteEnabled;
  final bool courseReminderPersistentDisplayEnabled;
}
