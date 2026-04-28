import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/providers/settings_provider.dart';
import 'package:timetable/services/storage_service.dart';

Future<SettingsProvider> _buildSettingsProvider({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final preferences = await SharedPreferences.getInstance();
  final storage = StorageService(sharedPreferences: preferences);
  await storage.ensureSemesterMigration();
  return SettingsProvider(storageService: storage);
}

void main() {
  test('restores default period start times from session defaults', () async {
    final settings = await _buildSettingsProvider();

    expect(
      settings.morningPeriodStartTimes.first,
      const TimeOfDay(hour: 8, minute: 0),
    );
    expect(
      settings.afternoonPeriodStartTimes.first,
      const TimeOfDay(hour: 14, minute: 0),
    );
    expect(
      settings.eveningPeriodStartTimes.first,
      const TimeOfDay(hour: 19, minute: 0),
    );
    expect(settings.totalClassPeriods, 13);
  });

  test(
    'changing a period start time only shifts the same session tail',
    () async {
      final settings = await _buildSettingsProvider();

      await settings.updatePeriodStartTime(
        ClassDayPeriod.morning,
        1,
        const TimeOfDay(hour: 9, minute: 10),
      );

      expect(
        settings.morningPeriodStartTimes[0],
        const TimeOfDay(hour: 8, minute: 0),
      );
      expect(
        settings.morningPeriodStartTimes[1],
        const TimeOfDay(hour: 9, minute: 10),
      );
      expect(
        settings.morningPeriodStartTimes[2],
        const TimeOfDay(hour: 10, minute: 0),
      );
      expect(
        settings.afternoonPeriodStartTimes.first,
        const TimeOfDay(hour: 14, minute: 0),
      );
      expect(
        settings.eveningPeriodStartTimes.first,
        const TimeOfDay(hour: 19, minute: 0),
      );
    },
  );

  test(
    'changing session class count appends and truncates start times',
    () async {
      final settings = await _buildSettingsProvider();

      await settings.updateSessionClassCount(ClassDayPeriod.evening, 4);
      expect(settings.eveningPeriodStartTimes, hasLength(4));
      expect(
        settings.eveningPeriodStartTimes.last,
        const TimeOfDay(hour: 21, minute: 30),
      );

      await settings.updateSessionClassCount(ClassDayPeriod.evening, 2);
      expect(settings.eveningPeriodStartTimes, hasLength(2));
      expect(
        settings.eveningPeriodStartTimes.last,
        const TimeOfDay(hour: 19, minute: 50),
      );
    },
  );

  test(
    'changing short break reflows each session from its first start',
    () async {
      final settings = await _buildSettingsProvider();

      await settings.updatePeriodStartTime(
        ClassDayPeriod.afternoon,
        0,
        const TimeOfDay(hour: 14, minute: 10),
      );
      await settings.updateShortBreak(10);

      expect(
        settings.morningPeriodStartTimes[1],
        const TimeOfDay(hour: 8, minute: 55),
      );
      expect(
        settings.afternoonPeriodStartTimes[0],
        const TimeOfDay(hour: 14, minute: 10),
      );
      expect(
        settings.afternoonPeriodStartTimes[1],
        const TimeOfDay(hour: 15, minute: 5),
      );
      expect(
        settings.eveningPeriodStartTimes[1],
        const TimeOfDay(hour: 19, minute: 55),
      );
    },
  );
}
