import 'dart:convert';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/event.dart';

class CourseProvider extends ChangeNotifier {
  static const String _coursesKey = 'courses.items';
  static const String _eventsKey = 'events.items';
  static const List<Course> _mockCourses = [
    Course(
      name: 'Advanced Math',
      location: 'Teaching Building A-201',
      teacher: 'Prof. Chen',
      weekday: 1,
      weeks: [1, 2, 3, 4, 5, 6, 7, 8],
      startPeriod: 1,
      endPeriod: 2,
      colorValue: 0xFF4F46E5,
    ),
    Course(
      name: 'Data Structures',
      location: 'Lab Building B-305',
      teacher: 'Dr. Lin',
      weekday: 3,
      weeks: [1, 2, 4, 6, 8, 10, 12, 14, 16],
      startPeriod: 6,
      endPeriod: 7,
      colorValue: 0xFF059669,
    ),
  ];

  CourseProvider({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences,
       _courses = _loadInitialCourses(sharedPreferences),
       _events = _loadInitialEvents(sharedPreferences);

  final SharedPreferences _sharedPreferences;
  final List<Course> _courses;
  final List<Event> _events;
  int _currentWeek = 1;
  int _currentWeekday = 1;
  bool _hasInitializedRealDate = false;
  Future<void> Function()? _reminderScheduler;

  UnmodifiableListView<Course> get courses => UnmodifiableListView(_courses);
  UnmodifiableListView<Event> get events => UnmodifiableListView(_events);
  int get currentWeek => _currentWeek;
  int get currentWeekday => _currentWeekday;

  void bindReminderScheduler(Future<void> Function() callback) {
    _reminderScheduler = callback;
  }

  Future<void> addCourse(Course course) async {
    _courses.add(course);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
  }

  Future<void> addCourses(List<Course> courses) async {
    if (courses.isEmpty) {
      return;
    }

    _courses.addAll(courses);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
  }

  Future<void> removeCourse(Course course) async {
    _courses.remove(course);
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
  }

  Future<void> updateCourse({
    required Course originalCourse,
    required Course updatedCourse,
  }) async {
    final index = _courses.indexOf(originalCourse);
    if (index == -1) {
      return;
    }

    _courses[index] = updatedCourse;
    notifyListeners();
    await _persistCourses();
    await _refreshReminders();
  }

  Future<void> clearAllCourses() async {
    _courses.clear();
    notifyListeners();
    await _sharedPreferences.remove(_coursesKey);
    await _refreshReminders();
  }

  Future<void> clearAllData() async {
    _courses.clear();
    _events.clear();
    notifyListeners();
    await _sharedPreferences.remove(_coursesKey);
    await _sharedPreferences.remove(_eventsKey);
    await _refreshReminders();
  }

  Future<void> addEvent(Event event) async {
    _events.add(event);
    notifyListeners();
    await _persistEvents();
    await _refreshReminders();
  }

  Future<void> deleteEvent(String eventId) async {
    _events.removeWhere((event) => event.id == eventId);
    notifyListeners();
    await _persistEvents();
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
    await _refreshReminders();
  }

  void initializeRealDate({
    required int week,
    required int weekday,
  }) {
    if (_hasInitializedRealDate) {
      return;
    }

    _currentWeek = week.clamp(1, 30).toInt();
    _currentWeekday = weekday.clamp(1, 7).toInt();
    _hasInitializedRealDate = true;
    notifyListeners();
  }

  void setCurrentWeek(int value) {
    final safeValue = value.clamp(1, 30).toInt();
    if (safeValue == _currentWeek) {
      return;
    }

    _currentWeek = safeValue;
    notifyListeners();
  }

  void setCurrentWeekday(int value) {
    final safeValue = value.clamp(1, 7).toInt();
    if (safeValue == _currentWeekday) {
      return;
    }

    _currentWeekday = safeValue;
    notifyListeners();
  }

  void setCurrentWeekAndWeekday({
    required int week,
    required int weekday,
  }) {
    final safeWeek = week.clamp(1, 30).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    if (safeWeek == _currentWeek && safeWeekday == _currentWeekday) {
      return;
    }

    _currentWeek = safeWeek;
    _currentWeekday = safeWeekday;
    notifyListeners();
  }

  static List<Course> _loadInitialCourses(SharedPreferences sharedPreferences) {
    final List<String>? rawCourses = sharedPreferences.getStringList(_coursesKey);

    if (rawCourses == null || rawCourses.isEmpty) {
      return List<Course>.from(_mockCourses);
    }

    return rawCourses.map((item) {
      final Map<String, dynamic> map = jsonDecode(item) as Map<String, dynamic>;
      return Course.fromJson(map);
    }).toList();
  }

  static List<Event> _loadInitialEvents(SharedPreferences sharedPreferences) {
    final rawEvents = sharedPreferences.getStringList(_eventsKey);
    if (rawEvents == null || rawEvents.isEmpty) {
      return <Event>[];
    }

    return rawEvents.map((item) {
      final map = jsonDecode(item) as Map<String, dynamic>;
      return Event.fromJson(map);
    }).toList();
  }

  Future<void> _persistCourses() async {
    final List<String> rawCourses = _courses
        .map((course) => jsonEncode(course.toJson()))
        .toList();
    await _sharedPreferences.setStringList(_coursesKey, rawCourses);
  }

  Future<void> _persistEvents() async {
    final rawEvents = _events.map((event) => jsonEncode(event.toJson())).toList();
    await _sharedPreferences.setStringList(_eventsKey, rawEvents);
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
}
