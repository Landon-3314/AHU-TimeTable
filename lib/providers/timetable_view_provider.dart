import 'package:flutter/material.dart';

class TimetableViewProvider extends ChangeNotifier {
  int _currentWeek = 1;
  int _currentWeekday = 1;
  bool _hasInitializedRealDate = false;

  int get currentWeek => _currentWeek;
  int get currentWeekday => _currentWeekday;

  void initializeRealDate({required int week, required int weekday}) {
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

  void setCurrentWeekAndWeekday({required int week, required int weekday}) {
    final safeWeek = week.clamp(1, 30).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    if (safeWeek == _currentWeek && safeWeekday == _currentWeekday) {
      return;
    }

    _currentWeek = safeWeek;
    _currentWeekday = safeWeekday;
    notifyListeners();
  }
}
