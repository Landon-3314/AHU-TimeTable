import 'package:flutter/material.dart';

import '../core/app_constants.dart';
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
    if (nextMode == TimetableMode.day &&
        _selectedWeekForWeekView == holidayWeekIndex) {
      _selectedWeekForWeekView = _currentWeek;
    }
    _mode = nextMode;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mode != nextMode) {
        return;
      }
      _alignControllersToCurrentState();
    });
  }

  Future<void> jumpToWeek(int selectedWeek) async {
    if (selectedWeek == holidayWeekIndex) {
      _mode = TimetableMode.week;
      _selectedWeekForWeekView = holidayWeekIndex;
      notifyListeners();
      _scheduleControllerAlignment();
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
      await _moveToPageSmart(_weekPageController, targetWeek - 1);
      await _moveToPageSmart(
        _dayPageController,
        (targetWeek - 1) * 7 + (targetWeekday - 1),
      );
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
      await _moveToPageSmart(_weekPageController, targetWeek - 1);
      await _moveToPageSmart(
        _dayPageController,
        (targetWeek - 1) * 7 + (targetWeekday - 1),
      );
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
      await _moveToPageSmart(
        _dayPageController,
        (targetWeek - 1) * 7 + (targetWeekday - 1),
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
      _moveToPageSmart(_weekPageController, targetWeek - 1);
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
        _moveToPageSmart(_dayPageController, targetDayIndex);
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
        _moveToPageSmart(
          _weekPageController,
          safeWeek - 1,
          forceJump: !animateWeek,
          animationDuration: AppDurations.pageSync,
          animationCurve: Curves.easeOutCubic,
        );
      }

      if (_dayPageController.hasClients) {
        _moveToPageSmart(
          _dayPageController,
          dayIndex,
          forceJump: !animateDay,
          animationDuration: AppDurations.pageSync,
          animationCurve: Curves.easeOutCubic,
        );
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

  void _setCurrentWeekAndWeekday({required int week, required int weekday}) {
    final safeWeek = week.clamp(1, _settingsProvider.totalWeeks).toInt();
    final safeWeekday = weekday.clamp(1, 7).toInt();
    _currentWeek = safeWeek;
    _currentWeekday = safeWeekday;
    _timetableViewProvider.setCurrentWeekAndWeekday(
      week: safeWeek,
      weekday: safeWeekday,
    );
  }

  void _alignControllersToCurrentState() {
    if (_selectedWeekForWeekView == holidayWeekIndex) {
      _moveToPageSmart(_weekPageController, holidayPagePageIndex);
      return;
    }

    _syncToWeekAndWeekday(
      week: _currentWeek,
      weekday: _currentWeekday,
      animateWeek: false,
      animateDay: false,
    );
  }

  void _scheduleControllerAlignment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_weekPageController.hasClients && !_dayPageController.hasClients) {
        return;
      }
      _alignControllersToCurrentState();
    });
  }

  Future<void> _moveToPageSmart(
    PageController controller,
    int targetPage, {
    bool forceJump = false,
    Duration animationDuration = AppDurations.pageJump,
    Curve animationCurve = Curves.easeInOut,
  }) async {
    if (!controller.hasClients) {
      return;
    }

    final currentPage = (controller.page ?? controller.initialPage.toDouble())
        .round();
    final delta = (targetPage - currentPage).abs();
    final shouldAnimate = !forceJump && delta == 1;

    if (shouldAnimate) {
      await controller.animateToPage(
        targetPage,
        duration: animationDuration,
        curve: animationCurve,
      );
      return;
    }

    controller.jumpToPage(targetPage);
  }
}
