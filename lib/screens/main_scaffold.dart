import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../providers/settings_provider.dart';
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
  Timer? _devTapTimer;

  static const List<Widget> _pages = [TimetablePage(), SettingsPage()];

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
