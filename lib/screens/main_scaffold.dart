import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../providers/settings_provider.dart';
import '../providers/timetable_view_provider.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/semester_start_date_dialog.dart';
import 'settings_page.dart';
import 'timetable_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  static const int _settingsTabIndex = 1;
  static const int _developerTapThreshold = 10;
  static const Duration _developerTapResetDelay = Duration(milliseconds: 1500);

  int _currentIndex = 0;
  int _devTapCount = 0;
  bool _hasHandledInitialSemesterPrompt = false;
  Timer? _devTapTimer;

  static const List<Widget> _pages = [TimetablePage(), SettingsPage()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_runStartupPrompts());
    });
  }

  @override
  void dispose() {
    _devTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _handleDeveloperTap(index);
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_view_week_outlined),
            activeIcon: const Icon(Icons.calendar_view_week),
            label: provider.t('timetable'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: provider.t('settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _runStartupPrompts() async {
    await _showCorruptRowNotice();
    await _showInitialSemesterStartDatePrompt();
  }

  Future<void> _showCorruptRowNotice() async {
    final count = await context
        .read<SettingsProvider>()
        .consumePendingCorruptRowNoticeCount();
    if (!mounted || count == 0) {
      return;
    }
    showAppSnackBar(context, SnackBar(content: Text('已跳过并保留 $count 条损坏日程记录')));
  }

  Future<void> _showInitialSemesterStartDatePrompt() async {
    if (_hasHandledInitialSemesterPrompt) {
      return;
    }

    final provider = context.read<SettingsProvider>();
    if (!provider.shouldShowSemesterStartDatePrompt) {
      return;
    }

    _hasHandledInitialSemesterPrompt = true;
    final selectedDate = await showSemesterStartDateDialog(
      context: context,
      initialDate: provider.semesterStartDate,
      canCancel: false,
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    await provider.completeInitialSemesterStartDate(selectedDate);
    if (!mounted) {
      return;
    }

    context.read<TimetableViewProvider>().setCurrentWeekAndWeekday(
      week: provider.currentRealWeek,
      weekday: provider.currentRealWeekday,
    );
  }

  void _handleDeveloperTap(int index) {
    if (index != _settingsTabIndex) {
      _resetDeveloperTapState();
      return;
    }

    _devTapTimer?.cancel();
    _devTapCount += 1;
    _devTapTimer = Timer(_developerTapResetDelay, _resetDeveloperTapState);

    if (_devTapCount < _developerTapThreshold) {
      return;
    }

    _resetDeveloperTapState();
    Navigator.of(context).pushNamed(AppRoutes.developerDiagnostics);
  }

  void _resetDeveloperTapState() {
    _devTapTimer?.cancel();
    _devTapTimer = null;
    _devTapCount = 0;
  }
}
