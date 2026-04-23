import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/event.dart';

import '../services/storage_service.dart';

class CourseProvider extends ChangeNotifier {
  CourseProvider({required StorageService storageService})
    : _storageService = storageService,
      _courses = storageService.loadCourses(),
      _events = storageService.loadEvents();

  final StorageService _storageService;
  final List<Course> _courses;
  final List<Event> _events;
  Future<void> Function()? _reminderScheduler;

  UnmodifiableListView<Course> get courses => UnmodifiableListView(_courses);
  UnmodifiableListView<Event> get events => UnmodifiableListView(_events);
  List<Course> get sortedUniqueCourses {
    final byName = <String, Course>{};
    for (final course in _courses) {
      final key = course.name.trim().toLowerCase();
      if (key.isEmpty || byName.containsKey(key)) {
        continue;
      }
      byName[key] = course;
    }

    final result = byName.values.toList()
      ..sort(
        (a, b) =>
            a.name.trim().toUpperCase().compareTo(b.name.trim().toUpperCase()),
      );
    return result;
  }

  void bindReminderScheduler(Future<void> Function() callback) {
    _reminderScheduler = callback;
  }

  Future<void> reloadForCurrentSemester({bool refreshReminders = true}) async {
    _courses
      ..clear()
      ..addAll(_storageService.loadCourses());
    _events
      ..clear()
      ..addAll(_storageService.loadEvents());
    notifyListeners();
    if (refreshReminders) {
      await _refreshReminders();
    }
  }

  Future<bool> addCourse(Course course) async {
    final semesterCourse = course.copyWith(
      semesterId: _storageService.currentSemesterId,
    );
    if (_containsDuplicate(semesterCourse)) {
      return false;
    }

    _courses.add(semesterCourse);
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
    return true;
  }

  Future<int> addCourses(List<Course> courses) async {
    if (courses.isEmpty) {
      return 0;
    }

    final acceptedCourses = <Course>[];
    for (final course in courses) {
      final semesterCourse = course.copyWith(
        semesterId: _storageService.currentSemesterId,
      );
      if (_containsDuplicate(semesterCourse, pendingCourses: acceptedCourses)) {
        continue;
      }
      acceptedCourses.add(semesterCourse);
    }

    if (acceptedCourses.isEmpty) {
      return 0;
    }

    _courses.addAll(acceptedCourses);
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
    return acceptedCourses.length;
  }

  Future<int> mergeImportedCourses(List<Course> courses) async {
    if (courses.isEmpty) {
      return 0;
    }

    final uniqueImported = <String, Course>{};
    for (final course in courses) {
      final sanitizedCourse = course.copyWith(
        clearRescheduleSource: true,
        semesterId: _storageService.currentSemesterId,
      );
      uniqueImported.putIfAbsent(
        _exactCourseKey(sanitizedCourse),
        () => sanitizedCourse,
      );
    }

    final existingExactKeys = _courses.map(_exactCourseKey).toSet();
    final changedImportedCourses = uniqueImported.values
        .where((course) => !existingExactKeys.contains(_exactCourseKey(course)))
        .toList();

    if (changedImportedCourses.isEmpty) {
      return 0;
    }

    final remainingCourses = _courses
        .where(
          (existingCourse) => !changedImportedCourses.any(
            (importedCourse) =>
                _shouldReplaceWithImported(existingCourse, importedCourse),
          ),
        )
        .toList();

    _courses
      ..clear()
      ..addAll(remainingCourses)
      ..addAll(changedImportedCourses);

    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
    return changedImportedCourses.length;
  }

  Future<void> removeCourse(Course course) async {
    _courses.removeWhere((item) => item.id == course.id);
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<bool> updateCourse({
    required Course originalCourse,
    required Course updatedCourse,
  }) async {
    final index = _courses.indexWhere(
      (course) => course.id == originalCourse.id,
    );
    if (index == -1) {
      return false;
    }

    if (_containsDuplicate(updatedCourse, ignoredCourseId: originalCourse.id)) {
      return false;
    }

    _courses[index] = updatedCourse.copyWith(
      semesterId: _storageService.currentSemesterId,
    );
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
    return true;
  }

  Future<bool> rescheduleCourseOccurrence({
    required Course originalCourse,
    required int sourceWeek,
    required int targetWeek,
    required int targetWeekday,
    required int targetStartPeriod,
  }) async {
    final index = _courses.indexWhere(
      (course) => course.id == originalCourse.id,
    );
    if (index == -1) {
      return false;
    }

    final storedCourse = _courses[index];
    if (!storedCourse.weeks.contains(sourceWeek)) {
      return false;
    }

    final targetSpan = storedCourse.endPeriod - storedCourse.startPeriod;
    final targetEndPeriod = targetStartPeriod + targetSpan;
    if (targetStartPeriod < 1 ||
        targetWeekday < 1 ||
        targetWeekday > 7 ||
        targetEndPeriod < targetStartPeriod) {
      return false;
    }

    final remainingWeeks =
        storedCourse.weeks.where((week) => week != sourceWeek).toList()..sort();
    final remainingCourse = remainingWeeks.isEmpty
        ? null
        : storedCourse.copyWith(weeks: remainingWeeks);
    final rescheduledCourse = storedCourse.copyWith(
      id: Course.createId(),
      weekday: targetWeekday,
      weeks: <int>[targetWeek],
      startPeriod: targetStartPeriod,
      endPeriod: targetEndPeriod,
      rescheduledFromSessionKey: storedCourse.sessionKey,
      rescheduledFromWeek: sourceWeek,
    );

    if (_containsDuplicate(
      rescheduledCourse,
      ignoredCourseId: originalCourse.id,
      pendingCourses: [?remainingCourse],
    )) {
      return false;
    }

    if (remainingWeeks.isEmpty) {
      _courses.removeAt(index);
    } else {
      _courses[index] = remainingCourse!;
    }

    _courses.add(rescheduledCourse);

    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
    return true;
  }

  Future<void> clearAllCourses() async {
    _courses.clear();
    notifyListeners();
    await _storageService.clearCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> clearAllData() async {
    _courses.clear();
    _events.clear();
    notifyListeners();
    await _storageService.clearAllTimetableData();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> addEvent(Event event) async {
    _events.add(event.copyWith(semesterId: _storageService.currentSemesterId));
    notifyListeners();
    await _persistEvents();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> deleteEvent(String eventId) async {
    _events.removeWhere((event) => event.id == eventId);
    notifyListeners();
    await _persistEvents();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> updateEvent(Event updatedEvent) async {
    final index = _events.indexWhere((event) => event.id == updatedEvent.id);
    if (index == -1) {
      return;
    }

    _events[index] = updatedEvent.copyWith(
      semesterId: _storageService.currentSemesterId,
    );
    notifyListeners();
    await _persistEvents();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> _persistCourses() async {
    await _storageService.saveCourses(_courses);
  }

  Future<void> _persistEvents() async {
    await _storageService.saveEvents(_events);
  }

  Future<void> _refreshReminders() async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) {
      return;
    }

    await scheduler();
  }

  Future<void> _syncBackgroundRuntimeIfEnabled() async {
    // Background service is now replaced by SystemScheduleManager
  }

  bool _containsDuplicate(
    Course candidate, {
    String? ignoredCourseId,
    List<Course> pendingCourses = const <Course>[],
  }) {
    for (final existingCourse in _courses) {
      if (existingCourse.id == ignoredCourseId) {
        continue;
      }
      if (_isDuplicateCourse(existingCourse, candidate)) {
        return true;
      }
    }

    for (final pendingCourse in pendingCourses) {
      if (_isDuplicateCourse(pendingCourse, candidate)) {
        return true;
      }
    }

    return false;
  }

  bool _isDuplicateCourse(Course left, Course right) {
    if (!_hasSameCourseIdentity(left, right) || left.weekday != right.weekday) {
      return false;
    }

    return _hasOverlappingWeeks(left.weeks, right.weeks) &&
        _hasOverlappingPeriods(
          leftStart: left.startPeriod,
          leftEnd: left.endPeriod,
          rightStart: right.startPeriod,
          rightEnd: right.endPeriod,
        );
  }

  String _normalizeCourseText(String value) {
    return value.trim().toLowerCase();
  }

  bool _hasSameCourseIdentity(Course left, Course right) {
    return _normalizeCourseText(left.name) ==
            _normalizeCourseText(right.name) &&
        _normalizeCourseText(left.location) ==
            _normalizeCourseText(right.location) &&
        _normalizeCourseText(left.teacher) ==
            _normalizeCourseText(right.teacher);
  }

  bool _hasOverlappingWeeks(List<int> leftWeeks, List<int> rightWeeks) {
    final leftSet = leftWeeks.toSet();
    return rightWeeks.any(leftSet.contains);
  }

  bool _hasOverlappingPeriods({
    required int leftStart,
    required int leftEnd,
    required int rightStart,
    required int rightEnd,
  }) {
    return leftStart <= rightEnd && rightStart <= leftEnd;
  }

  String _exactCourseKey(Course course) {
    final sortedWeeks = course.weeks.toList()..sort();
    return [course.sessionKey, sortedWeeks.join(',')].join('|');
  }

  bool _shouldReplaceWithImported(
    Course existingCourse,
    Course importedCourse,
  ) {
    if (_exactCourseKey(existingCourse) == _exactCourseKey(importedCourse)) {
      return false;
    }

    if (_matchesImportedSession(existingCourse, importedCourse)) {
      return true;
    }

    if (_matchesRescheduledImportSource(existingCourse, importedCourse)) {
      return true;
    }

    return _isLikelyRescheduledOccurrence(existingCourse, importedCourse);
  }

  bool _matchesImportedSession(Course existingCourse, Course importedCourse) {
    return existingCourse.sessionKey == importedCourse.sessionKey &&
        _hasOverlappingWeeks(existingCourse.weeks, importedCourse.weeks);
  }

  bool _matchesRescheduledImportSource(
    Course existingCourse,
    Course importedCourse,
  ) {
    return existingCourse.rescheduledFromSessionKey ==
            importedCourse.sessionKey &&
        existingCourse.rescheduledFromWeek != null &&
        importedCourse.weeks.contains(existingCourse.rescheduledFromWeek);
  }

  bool _isLikelyRescheduledOccurrence(
    Course existingCourse,
    Course importedCourse,
  ) {
    if (existingCourse.rescheduledFromSessionKey != null ||
        existingCourse.weeks.length != 1 ||
        !_hasSameCourseIdentity(existingCourse, importedCourse) ||
        existingCourse.sessionKey == importedCourse.sessionKey) {
      return false;
    }

    final overlappingWeek = existingCourse.weeks.first;
    if (!importedCourse.weeks.contains(overlappingWeek)) {
      return false;
    }

    return _courses.any(
      (course) =>
          course.id != existingCourse.id &&
          course.sessionKey == importedCourse.sessionKey &&
          _hasOverlappingWeeks(course.weeks, importedCourse.weeks),
    );
  }
}
