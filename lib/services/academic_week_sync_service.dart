import 'dart:convert';

import 'schedule_calculator.dart';
import 'schedule_parser_service.dart';

class AcademicTeachWeekSnapshot {
  const AcademicTeachWeekSnapshot({
    this.remoteSemesterId,
    this.dayIndex,
    required this.isInSemester,
    required this.weekIndex,
  });

  final int? remoteSemesterId;
  final int? dayIndex;
  final bool isInSemester;
  final int weekIndex;
}

class AcademicWeekCalibrationResult {
  const AcademicWeekCalibrationResult({
    required this.remoteWeekIndex,
    required this.localWeekIndex,
    required this.remoteSemesterStartDate,
    required this.shouldInitializeCurrentSemester,
    required this.requiresUserConfirmation,
    required this.message,
  });

  final int? remoteWeekIndex;
  final int? localWeekIndex;
  final DateTime? remoteSemesterStartDate;
  final bool shouldInitializeCurrentSemester;
  final bool requiresUserConfirmation;
  final String message;
}

class AcademicWeekSyncService {
  const AcademicWeekSyncService({
    ScheduleCalculator scheduleCalculator = const ScheduleCalculator(),
  }) : _scheduleCalculator = scheduleCalculator;

  final ScheduleCalculator _scheduleCalculator;

  AcademicTeachWeekSnapshot parseSnapshot(String rawBody) {
    final raw = rawBody.trim();
    if (raw.isEmpty) {
      throw ScheduleParseException('当前教学周接口返回为空。');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw ScheduleParseException('当前教学周接口结构异常。');
    }
    final root = Map<String, dynamic>.from(decoded);
    final currentSemester = root['currentSemester'];
    return AcademicTeachWeekSnapshot(
      remoteSemesterId: _parseRemoteSemesterId(currentSemester),
      dayIndex: _intOrNull(root['dayIndex']),
      isInSemester: _boolOrFalse(root['isInSemester']),
      weekIndex: _intOrNull(root['weekIndex']) ?? 0,
    );
  }

  int? _parseRemoteSemesterId(Object? currentSemester) {
    if (currentSemester is Map) {
      return _intOrNull(currentSemester['id']);
    }
    return _intOrNull(currentSemester);
  }

  AcademicWeekCalibrationResult buildCalibration({
    required AcademicTeachWeekSnapshot snapshot,
    required DateTime now,
    required DateTime localSemesterStartDate,
    required int totalWeeks,
    required bool isCurrentSemesterInitialized,
  }) {
    if (!snapshot.isInSemester || snapshot.weekIndex < 1) {
      return const AcademicWeekCalibrationResult(
        remoteWeekIndex: null,
        localWeekIndex: null,
        remoteSemesterStartDate: null,
        shouldInitializeCurrentSemester: false,
        requiresUserConfirmation: false,
        message: '教务当前不在教学周，已跳过周次校准。',
      );
    }

    final currentMonday = _scheduleCalculator.alignToMonday(now);
    final remoteStartDate = currentMonday.subtract(
      Duration(days: (snapshot.weekIndex - 1) * 7),
    );
    final localWeek = _scheduleCalculator.computeCurrentWeek(
      semesterStartDate: _scheduleCalculator.alignToMonday(
        localSemesterStartDate,
      ),
      totalWeeks: totalWeeks,
      now: now,
    );

    if (!isCurrentSemesterInitialized) {
      return AcademicWeekCalibrationResult(
        remoteWeekIndex: snapshot.weekIndex,
        localWeekIndex: localWeek,
        remoteSemesterStartDate: remoteStartDate,
        shouldInitializeCurrentSemester: true,
        requiresUserConfirmation: false,
        message: '可使用教务教学周初始化当前学期。',
      );
    }

    final requiresConfirmation =
        localWeek != snapshot.weekIndex ||
        !_isSameDate(
          _scheduleCalculator.alignToMonday(localSemesterStartDate),
          remoteStartDate,
        );
    return AcademicWeekCalibrationResult(
      remoteWeekIndex: snapshot.weekIndex,
      localWeekIndex: localWeek,
      remoteSemesterStartDate: remoteStartDate,
      shouldInitializeCurrentSemester: false,
      requiresUserConfirmation: requiresConfirmation,
      message: requiresConfirmation ? '教务周次与本地周次不一致，可手动确认后校准。' : '教务周次与本地设置一致。',
    );
  }

  int? _intOrNull(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('${value ?? ''}'.trim());
  }

  bool _boolOrFalse(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return '${value ?? ''}'.toLowerCase() == 'true';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
