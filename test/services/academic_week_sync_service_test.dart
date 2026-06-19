import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/services/academic_week_sync_service.dart';

void main() {
  const service = AcademicWeekSyncService();

  test('parses teach week snapshot and derives remote semester Monday', () {
    final snapshot = service.parseSnapshot(
      jsonEncode({
        'currentSemester': {'id': 202520261},
        'dayIndex': 3,
        'isInSemester': true,
        'weekIndex': 3,
      }),
    );

    final result = service.buildCalibration(
      snapshot: snapshot,
      now: DateTime(2026, 3, 18, 12),
      localSemesterStartDate: DateTime(2026, 3, 2),
      totalWeeks: 20,
      isCurrentSemesterInitialized: true,
    );

    expect(result.remoteSemesterStartDate, DateTime(2026, 3, 2));
    expect(result.remoteWeekIndex, 3);
    expect(result.localWeekIndex, 3);
    expect(result.requiresUserConfirmation, isFalse);
    expect(result.shouldInitializeCurrentSemester, isFalse);
  });

  test('parses string currentSemester without breaking week calibration', () {
    final snapshot = service.parseSnapshot(
      jsonEncode({
        'currentSemester': '202520261',
        'dayIndex': 1,
        'isInSemester': true,
        'weekIndex': 1,
      }),
    );

    expect(snapshot.remoteSemesterId, 202520261);
    expect(snapshot.weekIndex, 1);
  });

  test('does not suggest changes outside semester', () {
    final snapshot = service.parseSnapshot(
      jsonEncode({'isInSemester': false, 'weekIndex': 0}),
    );

    final result = service.buildCalibration(
      snapshot: snapshot,
      now: DateTime(2026, 3, 18),
      localSemesterStartDate: DateTime(2026, 3, 2),
      totalWeeks: 20,
      isCurrentSemesterInitialized: true,
    );

    expect(result.remoteSemesterStartDate, isNull);
    expect(result.requiresUserConfirmation, isFalse);
    expect(result.shouldInitializeCurrentSemester, isFalse);
    expect(result.message, contains('不在教学周'));
  });

  test(
    'initialized semester mismatch only creates a confirmation suggestion',
    () {
      final snapshot = service.parseSnapshot(
        jsonEncode({'isInSemester': true, 'weekIndex': 4}),
      );

      final result = service.buildCalibration(
        snapshot: snapshot,
        now: DateTime(2026, 3, 23),
        localSemesterStartDate: DateTime(2026, 3, 9),
        totalWeeks: 20,
        isCurrentSemesterInitialized: true,
      );

      expect(result.remoteSemesterStartDate, DateTime(2026, 3, 2));
      expect(result.localWeekIndex, 3);
      expect(result.remoteWeekIndex, 4);
      expect(result.requiresUserConfirmation, isTrue);
      expect(result.shouldInitializeCurrentSemester, isFalse);
    },
  );

  test(
    'uninitialized semester can use remote start date for initialization',
    () {
      final snapshot = service.parseSnapshot(
        jsonEncode({'isInSemester': true, 'weekIndex': 2}),
      );

      final result = service.buildCalibration(
        snapshot: snapshot,
        now: DateTime(2026, 3, 11),
        localSemesterStartDate: DateTime(2026, 3, 9),
        totalWeeks: 20,
        isCurrentSemesterInitialized: false,
      );

      expect(result.remoteSemesterStartDate, DateTime(2026, 3, 2));
      expect(result.shouldInitializeCurrentSemester, isTrue);
      expect(result.requiresUserConfirmation, isFalse);
    },
  );
}
