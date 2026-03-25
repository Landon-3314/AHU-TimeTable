import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

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

  void bindReminderScheduler(Future<void> Function() callback) {
    _reminderScheduler = callback;
  }

  Future<void> addCourse(Course course) async {
    _courses.add(course);
    notifyListeners();
    await _persistCourses();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'addCourse',
    );
    await _refreshReminders();
  }

  Future<void> addCourses(List<Course> courses) async {
    if (courses.isEmpty) {
      return;
    }

    _courses.addAll(courses);
    notifyListeners();
    await _persistCourses();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'addCourses',
    );
    await _refreshReminders();
  }

  Future<void> removeCourse(Course course) async {
    _courses.removeWhere((item) => item.id == course.id);
    notifyListeners();
    await _persistCourses();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'removeCourse',
    );
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
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'updateCourse',
    );
    await _refreshReminders();
  }

  Future<void> clearAllCourses() async {
    _courses.clear();
    notifyListeners();
    await _storageService.clearCourses();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'clearAllCourses',
    );
    await _refreshReminders();
  }

  Future<void> clearAllData() async {
    _courses.clear();
    _events.clear();
    notifyListeners();
    await _storageService.clearAllTimetableData();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'clearAllData',
    );
    await _refreshReminders();
  }

  Future<void> addEvent(Event event) async {
    _events.add(event);
    notifyListeners();
    await _persistEvents();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'addEvent',
    );
    await _refreshReminders();
  }

  Future<void> deleteEvent(String eventId) async {
    _events.removeWhere((event) => event.id == eventId);
    notifyListeners();
    await _persistEvents();
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'deleteEvent',
    );
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
    await _wakeBackgroundServiceIfNeeded(
      shouldStart: _shouldKeepBackgroundServiceAlive(),
      reason: 'updateEvent',
    );
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
      print('[CourseProvider] _refreshReminders skipped: scheduler is null');
      return;
    }

    print(
      '[CourseProvider] _refreshReminders called: '
      'courses=${_courses.length}, events=${_events.length}',
    );
    await scheduler();
  }

  Future<void> _wakeBackgroundServiceIfNeeded({
    required bool shouldStart,
    required String reason,
  }) async {
    if (!shouldStart || !Platform.isAndroid) {
      return;
    }

    final service = FlutterBackgroundService();
    print('[CourseProvider] startService requested from $reason');
    await service.startService();
  }

  bool _shouldKeepBackgroundServiceAlive() {
    final autoMuteEnabled = _storageService.readAutoMuteEnabled(
      fallback: false,
    );
    final reminderEnabled =
        _storageService.readReminderAdvanceMinutes(fallback: 0) > 0 &&
        _courses.isNotEmpty;
    final eventReminderEnabled =
        _storageService.readEventReminderAdvanceMinutes(fallback: 0) > 0 &&
        _events.any((event) => event.enableAlarm);
    return autoMuteEnabled || reminderEnabled || eventReminderEnabled;
  }
}
