import 'dart:async';

import 'package:flutter/material.dart';

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
    this.retryDelays = _defaultRetryDelays,
  });

  static const List<Duration> _defaultRetryDelays = <Duration>[
    Duration(minutes: 10),
    Duration(minutes: 30),
  ];

  final Widget child;
  final AcademicDailyAutoImportService dailyAutoImportService;
  final DailyAcademicSilentAutoImportBuilder? silentAutoImportBuilder;
  final List<Duration> retryDelays;

  @override
  State<DailyAcademicAutoImportHost> createState() =>
      _DailyAcademicAutoImportHostState();
}

class _DailyAcademicAutoImportHostState
    extends State<DailyAcademicAutoImportHost>
    with WidgetsBindingObserver {
  AcademicAutoAction? _runningAction;
  Timer? _retryTimer;
  bool _isChecking = false;
  int _retryDelayIndex = 0;
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
    _retryTimer?.cancel();
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
    if (!mounted ||
        _isChecking ||
        _runningAction != null ||
        _retryTimer != null) {
      return;
    }

    _isChecking = true;
    try {
      final shouldRun = await widget.dailyAutoImportService
          .shouldRunDailyTimetableImport();
      if (!mounted || !shouldRun) {
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
    unawaited(_finishSuccessfulRunSilently());
  }

  void _handleSilentAutoImportError(String message) {
    final retryDelay = _nextRetryDelay();
    _finishRunSilently(resetRetryState: retryDelay == null);
    if (retryDelay != null) {
      _scheduleRetry(retryDelay);
    }
  }

  Future<void> _finishSuccessfulRunSilently() async {
    try {
      await widget.dailyAutoImportService.markDailyTimetableImportCompleted();
    } finally {
      _finishRunSilently(resetRetryState: true);
    }
  }

  Duration? _nextRetryDelay() {
    if (_retryDelayIndex >= widget.retryDelays.length) {
      return null;
    }
    return widget.retryDelays[_retryDelayIndex++];
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(_checkAndRunDailyTimetableImport());
    });
  }

  void _finishRunSilently({required bool resetRetryState}) {
    if (!mounted) {
      return;
    }
    if (resetRetryState) {
      _retryDelayIndex = 0;
    }
    setState(() {
      _runningAction = null;
    });
  }
}
