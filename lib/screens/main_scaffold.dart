import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../providers/settings_provider.dart';
import '../providers/timetable_view_provider.dart';
import '../services/app_update_platform.dart';
import '../services/update_check_service.dart';
import '../services/update_download_service.dart';
import '../widgets/semester_start_date_dialog.dart';
import '../widgets/update_prompt.dart';
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
  bool _hasCheckedForAppUpdate = false;
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
    await _showInitialSemesterStartDatePrompt();
    if (!mounted) {
      return;
    }
    await _checkForAppUpdate();
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

  Future<void> _checkForAppUpdate() async {
    if (_hasCheckedForAppUpdate) {
      return;
    }
    _hasCheckedForAppUpdate = true;

    const platform = AppUpdatePlatform();
    if (!platform.isSupported) {
      return;
    }

    await platform.cleanupDownloadedApks();
    final service = UpdateCheckService.githubManifest(platform: platform);
    final update = await service.checkForUpdate();
    if (!mounted || update == null) {
      return;
    }

    final action = await showUpdatePrompt(context: context, update: update);
    if (!mounted || action == null || action == UpdatePromptAction.later) {
      return;
    }

    if (action == UpdatePromptAction.ignore) {
      await service.ignoreUpdate(update);
      return;
    }

    await _downloadAndInstallUpdate(update);
  }

  Future<void> _downloadAndInstallUpdate(AvailableUpdate update) async {
    final result = await showDialog<UpdateDownloadResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return UpdateDownloadTaskDialog(
          update: update,
          downloadService: const UpdateDownloadService(),
        );
      },
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.error != null || result.file == null) {
      _showUpdateSnackBar('更新下载失败，请稍后重试');
      return;
    }

    final installStarted = await const UpdateDownloadService().install(
      result.file!,
    );
    if (!mounted) {
      return;
    }
    _showUpdateSnackBar(
      installStarted
          ? '已打开系统安装器，请确认安装'
          : '无法打开安装器，请允许安装未知应用后重试',
    );
  }

  void _showUpdateSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
