import 'dart:collection';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/event.dart';
import '../services/background_service_manager.dart';
import '../services/storage_service.dart';

class CourseProvider extends ChangeNotifier {
  CourseProvider({
    required StorageService storageService,
    BackgroundServiceManager? backgroundServiceManager,
  })
    : _storageService = storageService,
      _backgroundServiceManager =
          backgroundServiceManager ?? const BackgroundServiceManager(),
      _courses = storageService.loadCourses(),
      _events = storageService.loadEvents();

  final StorageService _storageService;
  final BackgroundServiceManager _backgroundServiceManager;
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
        (a, b) => a.name.trim().toUpperCase().compareTo(
          b.name.trim().toUpperCase(),
        ),
      );
    return result;
  }

  void bindReminderScheduler(Future<void> Function() callback) {
    _reminderScheduler = callback;
  }

  Future<void> addCourse(Course course) async {
    _courses.add(course);
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> addCourses(List<Course> courses) async {
    if (courses.isEmpty) {
      return;
    }

    _courses.addAll(courses);
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> removeCourse(Course course) async {
    _courses.removeWhere((item) => item.id == course.id);
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
  }

  Future<void> updateCourse({
    required Course originalCourse,
    required Course updatedCourse,
  }) async {
    final index = _courses.indexWhere(
      (course) => course.id == originalCourse.id,
    );
    if (index == -1) {
      return;
    }

    _courses[index] = updatedCourse;
    notifyListeners();
    await _persistCourses();
    await _syncBackgroundRuntimeIfEnabled();
    await _refreshReminders();
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
    _events.add(event);
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

    _events[index] = updatedEvent;
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
    if (!_shouldKeepBackgroundServiceAlive()) {
      return;
    }
    await _backgroundServiceManager.syncIfRunning();
  }

  bool _shouldKeepBackgroundServiceAlive() {
    return _storageService.readBackgroundServiceEnabled(fallback: false);
  }
}
