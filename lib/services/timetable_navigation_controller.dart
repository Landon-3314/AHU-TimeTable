import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import '../providers/timetable_view_provider.dart';

enum TimetableMode { day, week }

class TimetableNavigationState {
  const TimetableNavigationState({
    required this.mode,
    required this.currentWeek,
    required this.currentWeekday,
    required this.selectedWeekForWeekView,
    required this.currentDisplayWeek,
    required this.currentDayPageIndex,
    required this.currentWeekPageIndex,
    required this.isHolidaySelected,
  });

  final TimetableMode mode;
  final int currentWeek;
  final int currentWeekday;
  final int selectedWeekForWeekView;
  final int currentDisplayWeek;
  final int currentDayPageIndex;
  final int currentWeekPageIndex;
  final bool isHolidaySelected;
}

class TimetableNavigationController extends ChangeNotifier {
  TimetableNavigationController({
    required SettingsProvider settingsProvider,
    required TimetableViewProvider timetableViewProvider,
    required this.holidayWeekIndex,
  }) : _settingsProvider = settingsProvider,
       _timetableViewProvider = timetableViewProvider {
    final initialWeek = _settingsProvider.currentRealWeek
        .clamp(1, _settingsProvider.totalWeeks)
        .toInt();
    final initialWeekday = _settingsProvider.currentRealWeekday
        .clamp(1, 7)
        .toInt();

    _currentWeek = initialWeek;
    _currentWeekday = initialWeekday;
    _selectedWeekForWeekView = initialWeek;
    _timetableViewProvider.setCurrentWeekAndWeekday(
      week: initialWeek,
      weekday: initialWeekday,
    );
    _weekPageController = PageController(initialPage: initialWeek - 1);
    _dayPageController = PageController(
      initialPage: (initialWeek - 1) * 7 + (initialWeekday - 1),
    );
  }

  final SettingsProvider _settingsProvider;
  final TimetableViewProvider _timetableViewProvider;
  final int holidayWeekIndex;

  late final PageController _dayPageController;
  late final PageController _weekPageController;
  int _currentWeek = 1;
  int _currentWeekday = 1;
  int _selectedWeekForWeekView = 1;
  TimetableMode _mode = TimetableMode.day;
  bool _isSyncingControllers = false;

  PageController get dayPageController => _dayPageController;
  PageController get weekPageController => _weekPageController;
  TimetableNavigationState get state => TimetableNavigationState(
    mode: _mode,
    currentWeek: _currentWeek,
    currentWeekday: _currentWeekday,
    selectedWeekForWeekView: _selectedWeekForWeekView,
    currentDisplayWeek: _mode == TimetableMode.week
        ? _selectedWeekForWeekView
        : _currentWeek,
    currentDayPageIndex: (_currentWeek - 1) * 7 + (_currentWeekday - 1),
    currentWeekPageIndex: _selectedWeekForWeekView == holidayWeekIndex
        ? holidayPagePageIndex
        : _selectedWeekForWeekView - 1,
    isHolidaySelected: _selectedWeekForWeekView == holidayWeekIndex,
  );

  int get holidayPagePageIndex => _settingsProvider.totalWeeks;

  void syncInitialPosition() {
    _syncToWeekAndWeekday(
      week: _currentWeek,
      weekday: _currentWeekday,
      animateWeek: false,
      animateDay: false,
    );
  }

  void setMode(TimetableMode nextMode) {
    if (_mode == nextMode) {
      return;
    }
    _mode = nextMode;
    notifyListeners();
  }

  Future<void> jumpToWeek(int selectedWeek) async {
    if (selectedWeek == holidayWeekIndex) {
      _mode = TimetableMode.week;
      _selectedWeekForWeekView = holidayWeekIndex;
      notifyListeners();

      if (_weekPageController.hasClients) {
        await _weekPageController.animateToPage(
          holidayPagePageIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    final targetWeek = selectedWeek
        .clamp(1, _settingsProvider.totalWeeks)
        .toInt();
    final targetWeekday = _currentWeekday.clamp(1, 7).toInt();
    _selectedWeekForWeekView = targetWeek;
    _setCurrentWeek(targetWeek);
    notifyListeners();

    _isSyncingControllers = true;
    try {
      if (_weekPageController.hasClients) {
        _weekPageController.jumpToPage(targetWeek - 1);
      }

      if (_dayPageController.hasClients) {
        _dayPageController.jumpToPage(
          (targetWeek - 1) * 7 + (targetWeekday - 1),
        );
      }
    } finally {
      _isSyncingControllers = false;
    }
  }

  Future<void> jumpToToday() async {
    final targetWeek = _settingsProvider.currentRealWeek
        .clamp(1, _settingsProvider.totalWeeks)
        .toInt();
    final targetWeekday = _settingsProvider.currentRealWeekday
        .clamp(1, 7)
        .toInt();

    _selectedWeekForWeekView = targetWeek;
    _setCurrentWeekAndWeekday(week: targetWeek, weekday: targetWeekday);
    notifyListeners();

    _isSyncingControllers = true;
    try {
      if (_weekPageController.hasClients) {
        _weekPageController.jumpToPage(targetWeek - 1);
      }

      if (_dayPageController.hasClients) {
        _dayPageController.jumpToPage(
          (targetWeek - 1) * 7 + (targetWeekday - 1),
        );
      }
    } finally {
      _isSyncingControllers = false;
    }
  }

  Future<void> jumpToDay({required int week, required int weekday}) async {
    final targetWeek = week.clamp(1, _settingsProvider.totalWeeks).toInt();
    final targetWeekday = weekday.clamp(1, 7).toInt();

    _selectedWeekForWeekView = targetWeek;
    _setCurrentWeekAndWeekday(week: targetWeek, weekday: targetWeekday);
    notifyListeners();

    if (_dayPageController.hasClients) {
      await _dayPageController.animateToPage(
        (targetWeek - 1) * 7 + (targetWeekday - 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void handleDayPageChanged(int index) {
    final targetWeek = ((index ~/ 7) + 1)
        .clamp(1, _settingsProvider.totalWeeks)
        .toInt();
    final targetWeekday = ((index % 7) + 1).clamp(1, 7).toInt();

    _setCurrentWeekAndWeekday(week: targetWeek, weekday: targetWeekday);
    _selectedWeekForWeekView = targetWeek;
    notifyListeners();

    if (_isSyncingControllers) {
      return;
    }

    if (_weekPageController.hasClients &&
        _weekPageController.page?.round() != targetWeek - 1) {
      _isSyncingControllers = true;
      _weekPageController.jumpToPage(targetWeek - 1);
      _isSyncingControllers = false;
    }
  }

  void handleWeekPageChanged(int pageIndex) {
    final isHoliday = pageIndex == holidayPagePageIndex;
    final week = isHoliday ? holidayWeekIndex : pageIndex + 1;
    final targetWeek = isHoliday
        ? holidayWeekIndex
        : week.clamp(1, _settingsProvider.totalWeeks).toInt();
    final currentWeekday = _currentWeekday.clamp(1, 7).toInt();

    _selectedWeekForWeekView = targetWeek;
    if (!isHoliday) {
      _setCurrentWeek(targetWeek);
    }
    notifyListeners();

    if (_isSyncingControllers) {
      return;
    }

    if (!isHoliday && _dayPageController.hasClients) {
      final targetDayIndex = (targetWeek - 1) * 7 + (currentWeekday - 1);
      if (_dayPageController.page?.round() != targetDayIndex) {
        _isSyncingControllers = true;
        _dayPageController.jumpToPage(targetDayIndex);
        _isSyncingControllers = false;
      }
    }
  }

  @override
  void dispose() {
    _dayPageController.dispose();
    _weekPageController.dispose();
    super.dispose();
  }

  void _syncToWeekAndWeekday({
    required int week,
    required int weekday,
    required bool animateWeek,
    required bool animateDay,
  }) {
    final safeWeek = week.clamp(1, _settingsProvider.totalWeeks).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    final dayIndex = (safeWeek - 1) * 7 + (safeWeekday - 1);

    _isSyncingControllers = true;
    try {
      if (_weekPageController.hasClients) {
        if (animateWeek) {
          _weekPageController.animateToPage(
            safeWeek - 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _weekPageController.jumpToPage(safeWeek - 1);
        }
      }

      if (_dayPageController.hasClients) {
        if (animateDay) {
          _dayPageController.animateToPage(
            dayIndex,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          );
        } else {
          _dayPageController.jumpToPage(dayIndex);
        }
      }
    } finally {
      _isSyncingControllers = false;
    }
  }

  void _setCurrentWeek(int value) {
    final safeValue = value.clamp(1, _settingsProvider.totalWeeks).toInt();
    _currentWeek = safeValue;
    _timetableViewProvider.setCurrentWeek(safeValue);
  }

  void _setCurrentWeekAndWeekday({
    required int week,
    required int weekday,
  }) {
    final safeWeek = week.clamp(1, _settingsProvider.totalWeeks).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    _currentWeek = safeWeek;
    _currentWeekday = safeWeekday;
    _timetableViewProvider.setCurrentWeekAndWeekday(
      week: safeWeek,
      weekday: safeWeekday,
    );
  }
}
