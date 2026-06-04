import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../screens/import_course_page.dart';
import '../services/academic_daily_auto_import_service.dart';

typedef DailyAcademicSilentAutoImportBuilder =
    Widget Function(
      BuildContext context,
      AcademicAutoAction action,
      ValueChanged<AcademicImportResult> onResult,
      ValueChanged<String> onError,
    );

class DailyAcademicAutoImportHost extends StatefulWidget {
  const DailyAcademicAutoImportHost({
    super.key,
    required this.child,
    this.dailyAutoImportService = const AcademicDailyAutoImportService(),
    this.silentAutoImportBuilder,
  });

  final Widget child;
  final AcademicDailyAutoImportService dailyAutoImportService;
  final DailyAcademicSilentAutoImportBuilder? silentAutoImportBuilder;

  @override
  State<DailyAcademicAutoImportHost> createState() =>
      _DailyAcademicAutoImportHostState();
}

class _DailyAcademicAutoImportHostState
    extends State<DailyAcademicAutoImportHost>
    with WidgetsBindingObserver {
  AcademicAutoAction? _runningAction;
  bool _isChecking = false;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAndRunDailyTimetableImport());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAndRunDailyTimetableImport());
    }
  }

  @override
  Widget build(BuildContext context) {
    final runningAction = _runningAction;
    return Stack(
      children: [
        widget.child,
        if (runningAction != null)
          Positioned(
            left: -2,
            top: -2,
            width: 1,
            height: 1,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.01,
                child: KeyedSubtree(
                  key: ValueKey('daily-auto-import-$_runId'),
                  child: _buildSilentAutoImporter(runningAction),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _checkAndRunDailyTimetableImport() async {
    if (!mounted || _isChecking || _runningAction != null) {
      return;
    }

    if (!context.read<SettingsProvider>().isCurrentSemesterInitialized) {
      return;
    }

    _isChecking = true;
    try {
      final shouldRun = await widget.dailyAutoImportService
          .shouldRunDailyTimetableImport();
      if (!mounted || !shouldRun) {
        return;
      }

      await widget.dailyAutoImportService.markDailyTimetableImportAttempted();
      if (!mounted) {
        return;
      }

      setState(() {
        _runningAction = AcademicAutoAction.timetable;
        _runId += 1;
      });
    } finally {
      _isChecking = false;
    }
  }

  Widget _buildSilentAutoImporter(AcademicAutoAction action) {
    final builder =
        widget.silentAutoImportBuilder ?? _defaultSilentAutoImportBuilder;
    return builder(
      context,
      action,
      _handleSilentAutoImportResult,
      _handleSilentAutoImportError,
    );
  }

  Widget _defaultSilentAutoImportBuilder(
    BuildContext context,
    AcademicAutoAction action,
    ValueChanged<AcademicImportResult> onResult,
    ValueChanged<String> onError,
  ) {
    return ImportCoursePage(
      initialAutoAction: action,
      showWebView: false,
      confirmTimetableConflicts: false,
      onImportResult: onResult,
      onImportError: onError,
    );
  }

  void _handleSilentAutoImportResult(AcademicImportResult result) {
    _finishRunSilently();
  }

  void _handleSilentAutoImportError(String message) {
    _finishRunSilently();
  }

  void _finishRunSilently() {
    if (!mounted) {
      return;
    }
    setState(() {
      _runningAction = null;
    });
  }
}
