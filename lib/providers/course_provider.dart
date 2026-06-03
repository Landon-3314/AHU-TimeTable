import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/event.dart';

import '../services/course_conflict_policy.dart';
import '../services/storage_service.dart';

class CourseGroup {
  CourseGroup({required this.name, required List<Course> courses})
    : courses = List<Course>.unmodifiable(courses);

  final String name;
  final List<Course> courses;

  int get recordCount => courses.length;
}

class CourseProvider extends ChangeNotifier {
  static const String academicTimetableImportSource = 'academic.timetable';
  static const String academicExamImportSource = 'academic.exam';
  static const CourseConflictPolicy _conflictPolicy = CourseConflictPolicy();

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
  bool get hasImportedTimetableCourses => _courses.any(
    (course) => course.importSource == academicTimetableImportSource,
  );

  List<CourseGroup> get sortedCourseGroups {
    final byName = <String, List<Course>>{};
    for (final course in _courses) {
      final key = course.name.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      byName.putIfAbsent(key, () => <Course>[]).add(course);
    }

    final groups = byName.values.map((records) {
      final sortedRecords = records.toList()..sort(_compareCourseRecords);
      return CourseGroup(name: records.first.name, courses: sortedRecords);
    }).toList();

    groups.sort(
      (a, b) =>
          a.name.trim().toUpperCase().compareTo(b.name.trim().toUpperCase()),
    );
    return groups;
  }

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

  List<CourseConflict> findCourseConflicts(
    Iterable<Course> candidates, {
    String? ignoredCourseId,
  }) {
    return _conflictPolicy.findConflicts(
      candidates: candidates,
      existingCourses: _courses,
      ignoredCourseId: ignoredCourseId,
    );
  }

  List<CourseConflict> findImportedCourseConflicts(Iterable<Course> courses) {
    return _conflictPolicy.findConflicts(
      candidates: courses,
      existingCourses: _courses.where(
        (course) => course.importSource != academicTimetableImportSource,
      ),
    );
  }

  List<CourseConflict> findRescheduleCourseConflicts({
    required Course originalCourse,
    required int sourceWeek,
    required int targetWeek,
    required int targetWeekday,
    required int targetStartPeriod,
  }) {
    final index = _courses.indexWhere(
      (course) => course.id == originalCourse.id,
    );
    if (index == -1) {
      return const <CourseConflict>[];
    }
    final candidate = _buildRescheduledCourseOccurrence(
      storedCourse: _courses[index],
      sourceWeek: sourceWeek,
      targetWeek: targetWeek,
      targetWeekday: targetWeekday,
      targetStartPeriod: targetStartPeriod,
    );
    if (candidate == null) {
      return const <CourseConflict>[];
    }
    return findCourseConflicts([candidate], ignoredCourseId: originalCourse.id);
  }

  int _compareCourseRecords(Course left, Course right) {
    final weekdayOrder = left.weekday.compareTo(right.weekday);
    if (weekdayOrder != 0) {
      return weekdayOrder;
    }

    final startOrder = left.startPeriod.compareTo(right.startPeriod);
    if (startOrder != 0) {
      return startOrder;
    }

    final endOrder = left.endPeriod.compareTo(right.endPeriod);
    if (endOrder != 0) {
      return endOrder;
    }

    return _compareIntLists(left.weeks, right.weeks);
  }

  int _compareIntLists(List<int> left, List<int> right) {
    final length = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final order = left[index].compareTo(right[index]);
      if (order != 0) {
        return order;
      }
    }
    return left.length.compareTo(right.length);
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

  Future<bool> addCourse(Course course, {bool allowConflicts = false}) async {
    final semesterCourse = course.copyWith(
      semesterId: _storageService.currentSemesterId,
    );
    if (_containsDuplicate(semesterCourse)) {
      return false;
    }
    if (!allowConflicts && findCourseConflicts([semesterCourse]).isNotEmpty) {
      return false;
    }

    _courses.add(semesterCourse);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
    return true;
  }

  Future<int> addCourses(
    List<Course> courses, {
    bool allowConflicts = false,
  }) async {
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
    if (!allowConflicts && findCourseConflicts(acceptedCourses).isNotEmpty) {
      return 0;
    }

    _courses.addAll(acceptedCourses);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
    return acceptedCourses.length;
  }

  Future<int> mergeImportedCourses(
    List<Course> courses, {
    bool allowConflicts = false,
  }) async {
    final importBatchId = _createImportBatchId(academicTimetableImportSource);
    final uniqueImported = <String, Course>{};
    for (final course in courses) {
      final sanitizedCourse = course.copyWith(
        clearRescheduleSource: true,
        semesterId: _storageService.currentSemesterId,
        importSource: academicTimetableImportSource,
        importBatchId: importBatchId,
      );
      uniqueImported.putIfAbsent(
        _exactCourseKey(sanitizedCourse),
        () => sanitizedCourse,
      );
    }

    final previousImportedKeys = _courses
        .where((course) => course.importSource == academicTimetableImportSource)
        .map(_exactCourseKey)
        .toSet();
    final nextImportedKeys = uniqueImported.keys.toSet();
    if (_haveSameKeys(previousImportedKeys, nextImportedKeys)) {
      return 0;
    }

    final remainingCourses = _courses
        .where((course) => course.importSource != academicTimetableImportSource)
        .toList();
    if (!allowConflicts &&
        _conflictPolicy
            .findConflicts(
              candidates: uniqueImported.values,
              existingCourses: remainingCourses,
            )
            .isNotEmpty) {
      return 0;
    }

    _courses
      ..clear()
      ..addAll(remainingCourses)
      ..addAll(uniqueImported.values);

    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
    return uniqueImported.length;
  }

  Future<Course?> removeCourse(Course course) async {
    final index = _courses.indexWhere((item) => item.id == course.id);
    if (index == -1) {
      return null;
    }
    final removed = _courses.removeAt(index);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
    return removed;
  }

  Future<void> restoreCourse(Course course) async {
    if (_courses.any((item) => item.id == course.id)) {
      return;
    }
    _courses.add(course);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
  }

  Future<bool> updateCourse({
    required Course originalCourse,
    required Course updatedCourse,
    bool allowConflicts = false,
  }) async {
    final index = _courses.indexWhere(
      (course) => course.id == originalCourse.id,
    );
    if (index == -1) {
      return false;
    }

    final semesterCourse = updatedCourse.copyWith(
      semesterId: _storageService.currentSemesterId,
    );
    if (_containsDuplicate(
      semesterCourse,
      ignoredCourseId: originalCourse.id,
    )) {
      return false;
    }
    if (!allowConflicts &&
        findCourseConflicts([
          semesterCourse,
        ], ignoredCourseId: originalCourse.id).isNotEmpty) {
      return false;
    }

    _courses[index] = semesterCourse;
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
    return true;
  }

  Future<bool> rescheduleCourseOccurrence({
    required Course originalCourse,
    required int sourceWeek,
    required int targetWeek,
    required int targetWeekday,
    required int targetStartPeriod,
    bool allowConflicts = false,
  }) async {
    final index = _courses.indexWhere(
      (course) => course.id == originalCourse.id,
    );
    if (index == -1) {
      return false;
    }

    final storedCourse = _courses[index];
    final rescheduledCourse = _buildRescheduledCourseOccurrence(
      storedCourse: storedCourse,
      sourceWeek: sourceWeek,
      targetWeek: targetWeek,
      targetWeekday: targetWeekday,
      targetStartPeriod: targetStartPeriod,
    );
    if (rescheduledCourse == null) {
      return false;
    }

    final remainingWeeks =
        storedCourse.weeks.where((week) => week != sourceWeek).toList()..sort();
    final remainingCourse = remainingWeeks.isEmpty
        ? null
        : storedCourse.copyWith(weeks: remainingWeeks);

    if (_containsDuplicate(
      rescheduledCourse,
      ignoredCourseId: originalCourse.id,
      pendingCourses: [?remainingCourse],
    )) {
      return false;
    }
    if (!allowConflicts &&
        findCourseConflicts([
          rescheduledCourse,
        ], ignoredCourseId: originalCourse.id).isNotEmpty) {
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
    await _refreshReminders();
    return true;
  }

  Future<void> clearAllCourses() async {
    _courses.clear();
    notifyListeners();
    await _storageService.clearCourses();
    await _refreshReminders();
  }

  Future<void> clearAllData() async {
    _courses.clear();
    _events.clear();
    notifyListeners();
    await _storageService.clearAllTimetableData();
    await _refreshReminders();
  }

  Future<void> addEvent(Event event) async {
    _events.add(event.copyWith(semesterId: _storageService.currentSemesterId));
    notifyListeners();
    await _persistEvents();
    await _refreshReminders();
  }

  Future<int> mergeImportedEvents(List<Event> events) async {
    final importBatchId = _createImportBatchId(academicExamImportSource);
    final importedAt = DateTime.now();
    final uniqueImported = <String, Event>{};
    for (final event in events) {
      final sanitizedEvent = event.copyWith(
        semesterId: _storageService.currentSemesterId,
        importSource: academicExamImportSource,
        importBatchId: importBatchId,
        importedAt: importedAt,
      );
      uniqueImported.putIfAbsent(
        _exactEventKey(sanitizedEvent),
        () => sanitizedEvent,
      );
    }

    final previousImportedKeys = _events
        .where((event) => event.importSource == academicExamImportSource)
        .map(_exactEventKey)
        .toSet();
    final nextImportedKeys = uniqueImported.keys.toSet();
    if (_haveSameKeys(previousImportedKeys, nextImportedKeys)) {
      return 0;
    }

    final remainingEvents = _events
        .where((event) => event.importSource != academicExamImportSource)
        .toList();
    _events
      ..clear()
      ..addAll(remainingEvents)
      ..addAll(uniqueImported.values);
    notifyListeners();
    await _persistEvents();
    await _refreshReminders();
    return uniqueImported.length;
  }

  Future<Event?> deleteEvent(String eventId) async {
    final index = _events.indexWhere((event) => event.id == eventId);
    if (index == -1) {
      return null;
    }
    final removed = _events.removeAt(index);
    notifyListeners();
    await _persistEvents();
    await _refreshReminders();
    return removed;
  }

  Future<void> restoreEvent(Event event) async {
    if (_events.any((item) => item.id == event.id)) {
      return;
    }
    _events.add(event);
    notifyListeners();
    await _persistEvents();
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

  Course? _buildRescheduledCourseOccurrence({
    required Course storedCourse,
    required int sourceWeek,
    required int targetWeek,
    required int targetWeekday,
    required int targetStartPeriod,
  }) {
    if (!storedCourse.weeks.contains(sourceWeek)) {
      return null;
    }

    final targetSpan = storedCourse.endPeriod - storedCourse.startPeriod;
    final targetEndPeriod = targetStartPeriod + targetSpan;
    if (targetStartPeriod < 1 ||
        targetWeekday < 1 ||
        targetWeekday > 7 ||
        targetEndPeriod < targetStartPeriod) {
      return null;
    }

    return storedCourse.copyWith(
      id: Course.createId(),
      weekday: targetWeekday,
      weeks: <int>[targetWeek],
      startPeriod: targetStartPeriod,
      endPeriod: targetEndPeriod,
      rescheduledFromSessionKey: storedCourse.sessionKey,
      rescheduledFromWeek: sourceWeek,
    );
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

  String _exactEventKey(Event event) {
    return [
      event.name.trim().toLowerCase(),
      event.location.trim().toLowerCase(),
      event.note.trim().toLowerCase(),
      event.dateTime.toIso8601String(),
    ].join('|');
  }

  bool _haveSameKeys(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  String _createImportBatchId(String source) {
    return '$source-${DateTime.now().microsecondsSinceEpoch}';
  }
}
