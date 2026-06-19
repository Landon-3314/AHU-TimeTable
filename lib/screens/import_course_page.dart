import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/app_colors.dart';
import '../models/academic_credential.dart';
import '../models/academic_import.dart';
import '../models/course.dart';
import '../models/event.dart';
import '../models/grade.dart';
import '../providers/course_provider.dart';
import '../providers/grade_provider.dart';
import '../providers/settings_provider.dart';
import '../services/academic_api_endpoints.dart';
import '../services/academic_auto_login_service.dart';
import '../services/academic_course_api_parser.dart';
import '../services/academic_credential_service.dart';
import '../services/academic_exam_diagnostics.dart';
import '../services/academic_exam_api_parser.dart';
import '../services/academic_webview_fetch_client.dart';
import '../services/academic_week_sync_service.dart';
import '../services/grade_parser_service.dart';
import '../services/schedule_html_extractor.dart';
import '../services/schedule_parser_service.dart';
import '../widgets/academic_import/academic_credential_panel.dart';
import '../widgets/academic_import/academic_import_conflict_confirmation.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/guided_tour_overlay.dart';

enum _ImportAction { timetable, exam, grade }

class AcademicImportPopGuard extends StatelessWidget {
  const AcademicImportPopGuard({
    super.key,
    required this.canLeave,
    required this.child,
  });

  final bool canLeave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: canLeave, child: child);
  }
}

void _logAcademicAutoImport(String message) {
  if (kDebugMode) {
    debugPrint(
      '[AcademicAutoImport] ${DateTime.now().toIso8601String()} $message',
    );
  }
}

class ImportCoursePage extends StatefulWidget {
  const ImportCoursePage({
    super.key,
    this.initialAutoAction,
    this.showWebView = true,
    this.showCredentialPanel = false,
    this.onImportResult,
    this.onImportError,
    this.confirmTimetableConflicts = true,
  });

  final AcademicAutoAction? initialAutoAction;
  final bool showWebView;
  final bool showCredentialPanel;
  final ValueChanged<AcademicImportResult>? onImportResult;
  final ValueChanged<String>? onImportError;
  final bool confirmTimetableConflicts;

  @override
  State<ImportCoursePage> createState() => _ImportCoursePageState();
}

class _ImportCoursePageState extends State<ImportCoursePage> {
  static const ScheduleParserService _parserService = ScheduleParserService();
  static const AcademicCourseApiParser _courseApiParser =
      AcademicCourseApiParser();
  static const AcademicExamApiParser _examApiParser = AcademicExamApiParser();
  static const GradeParserService _gradeParser = GradeParserService();
  static const AcademicWeekSyncService _weekSyncService =
      AcademicWeekSyncService();
  static const AcademicCredentialService _credentialService =
      AcademicCredentialService();
  static const Duration _extractScriptSettleDelay = Duration(milliseconds: 350);
  static const Duration _examExtractScriptSettleDelay = Duration(seconds: 5);
  static const Duration _autoStepDelay = Duration(milliseconds: 700);
  static const Duration _autoRetryDelay = Duration(seconds: 1);
  static const Duration _autoImportTimeout = Duration(seconds: 30);
  static const Duration _autoExamImportTimeout = Duration(seconds: 70);
  static const Duration _autoGradeImportTimeout = Duration(seconds: 50);
  static const Duration _teachWeekSyncTimeout = Duration(seconds: 3);
  static const int _maxAutoImportRecoverableRetries = 1;
  static const int _maxPortalLoginSubmissions = 2;
  static const String _extractExamInfoVmsScript = '''
(function() {
  const readFrom = function(targetWindow) {
    try {
      if (typeof targetWindow.studentExamInfoVms !== 'undefined') {
        return JSON.stringify(targetWindow.studentExamInfoVms);
      }
      for (let i = 0; i < targetWindow.frames.length; i += 1) {
        const nested = readFrom(targetWindow.frames[i]);
        if (nested) {
          return nested;
        }
      }
    } catch (error) {
      return '';
    }
    return '';
  };
  return readFrom(window);
})();
''';
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _webViewGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  late final WebViewController _controller;
  late final Future<void> _controllerReady;
  AcademicWebViewFetchClient? _fetchClient;
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  _ImportAction? _activeAction;
  AcademicCredential? _storedCredential;
  final GlobalKey _webViewGuideKey = GlobalKey();
  final GlobalKey _examGuideKey = GlobalKey();
  final GlobalKey _timetableGuideKey = GlobalKey();
  int _pageLoadProgress = 100;
  bool _autoLoginEnabled = false;
  bool _isCredentialLoading = true;
  bool _isImportGuideShowing = false;
  String? _autoImportStatus;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _controllerReady = _initializeController();
    unawaited(_loadCredential().then((_) => _runInitialAutoActionIfNeeded()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.showWebView) {
        return;
      }
      _showImportWebViewGuideIfNeeded();
    });
  }

  @override
  void dispose() {
    _fetchClient?.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final activeAction = _activeAction;
    final isExtracting = activeAction != null || _autoImportStatus != null;
    return AcademicImportPopGuard(
      canLeave: !isExtracting,
      child: Scaffold(
        appBar: AppBar(
          title: Text(settingsProvider.t('academic_import')),
          automaticallyImplyLeading: !isExtracting,
        ),
        body: Column(
          children: [
            _buildPageLoadProgress(),
            if (widget.showCredentialPanel)
              _buildCredentialPanel(settingsProvider, isExtracting),
            Expanded(
              child: widget.showWebView
                  ? KeyedSubtree(key: _webViewGuideKey, child: _buildWebView())
                  : _buildHiddenAutoImportBody(settingsProvider),
            ),
          ],
        ),
        floatingActionButton: widget.showWebView
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    key: _examGuideKey,
                    heroTag: 'extract_exam',
                    onPressed: isExtracting ? null : _runExamExtractScript,
                    icon: const Icon(Icons.assignment_outlined),
                    label: Text(
                      activeAction == _ImportAction.exam
                          ? settingsProvider.t('extracting_exam')
                          : settingsProvider.t('extract_exam'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    key: _timetableGuideKey,
                    heroTag: 'extract_timetable',
                    onPressed: isExtracting ? null : _runTimetableExtractScript,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(
                      activeAction == _ImportAction.timetable
                          ? settingsProvider.t('extracting')
                          : settingsProvider.t('extract_timetable'),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildHiddenAutoImportBody(SettingsProvider settingsProvider) {
    final status =
        _autoImportStatus ??
        (widget.initialAutoAction == null
            ? settingsProvider.t('auto_import_waiting_page')
            : settingsProvider.t('auto_import_preparing'));
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  settingsProvider.t('auto_import_hidden_webview_notice'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: -2,
          top: -2,
          width: 1,
          height: 1,
          child: Opacity(opacity: 0.01, child: _buildWebView()),
        ),
      ],
    );
  }

  Widget _buildCredentialPanel(SettingsProvider settingsProvider, bool isBusy) {
    return AcademicCredentialPanel(
      settingsProvider: settingsProvider,
      studentIdController: _studentIdController,
      passwordController: _passwordController,
      isBusy: isBusy,
      isCredentialLoading: _isCredentialLoading,
      autoLoginEnabled: _autoLoginEnabled,
      storedCredential: _storedCredential,
      status: _autoImportStatus,
      onAutoLoginChanged: (value) {
        setState(() {
          _autoLoginEnabled = value;
        });
      },
      onSaveCredential: _saveCredentialFromInput,
      onClearCredential: _clearCredential,
      onRunTimetableImport: _runAutoTimetableImport,
      onRunExamImport: _runAutoExamImport,
    );
  }

  Widget _buildWebView() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return WebViewWidget(controller: _controller);
    }

    return WebViewWidget.fromPlatformCreationParams(
      params: AndroidWebViewWidgetCreationParams(
        controller: _controller.platform,
        gestureRecognizers: _webViewGestureRecognizers,
      ),
    );
  }

  Widget _buildPageLoadProgress() {
    if (_pageLoadProgress >= 100) {
      return const SizedBox.shrink();
    }

    return LinearProgressIndicator(
      minHeight: 3,
      value: _pageLoadProgress / 100,
    );
  }

  Future<void> _initializeController() async {
    await _controller.enableZoom(true);

    if (_controller.platform is AndroidWebViewController) {
      final androidController =
          _controller.platform as AndroidWebViewController;
      await androidController.setUseWideViewPort(true);
    }

    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    _fetchClient = AcademicWebViewFetchClient(controller: _controller);
    await _controller.addJavaScriptChannel(
      AcademicWebViewFetchClient.channelName,
      onMessageReceived: (message) {
        _fetchClient?.handleMessage(message.message);
      },
    );
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _pageLoadProgress = progress.clamp(0, 100).toInt();
          });
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || !_isAllowedAcademicUri(uri)) {
            _showBlockedNavigationMessage(request.url);
            _logAcademicAutoImport('blocked navigation url=${request.url}');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            _logAcademicAutoImport(
              'main frame load error code=${error.errorCode} '
              'type=${error.errorType} url=${error.url} '
              'description=${error.description}',
            );
          }
        },
      ),
    );
    await _controller.loadRequest(
      Uri.parse(ScheduleHtmlExtractor.academicTimetableUrl),
    );
  }

  Future<void> _runInitialAutoActionIfNeeded() async {
    final action = widget.initialAutoAction;
    if (action == null) {
      return;
    }

    await _controllerReady;
    if (!mounted) {
      return;
    }

    switch (action) {
      case AcademicAutoAction.timetable:
        await _runAutoTimetableImport();
      case AcademicAutoAction.exam:
        await _runAutoExamImport();
      case AcademicAutoAction.grade:
        await _runAutoGradeImport();
    }
  }

  Future<void> _loadCredential() async {
    final credential = await _credentialService.load();
    if (!mounted) {
      return;
    }

    if (credential != null) {
      _studentIdController.text = credential.studentId;
      _passwordController.text = credential.password;
    }
    setState(() {
      _storedCredential = credential;
      _autoLoginEnabled = credential?.autoLoginEnabled ?? false;
      _isCredentialLoading = false;
    });
  }

  AcademicCredential? _credentialFromInput() {
    final studentId = _studentIdController.text.trim();
    final password = _passwordController.text;
    if (studentId.isEmpty || password.isEmpty) {
      return null;
    }
    return AcademicCredential(
      studentId: studentId,
      password: password,
      autoLoginEnabled: _autoLoginEnabled,
    );
  }

  Future<void> _saveCredentialFromInput() async {
    final settingsProvider = context.read<SettingsProvider>();
    final credential = _credentialFromInput();
    if (credential == null) {
      _finishImportWithMessage(
        settingsProvider.t('academic_credentials_empty'),
      );
      return;
    }

    await _credentialService.save(credential);
    if (!mounted) {
      return;
    }
    setState(() {
      _storedCredential = credential;
    });
    showAppSnackBar(
      context,
      SnackBar(content: Text(settingsProvider.t('academic_credentials_saved'))),
    );
  }

  Future<void> _clearCredential() async {
    final clearedMessage = context.read<SettingsProvider>().t(
      'academic_credentials_cleared',
    );
    await _credentialService.clear();
    if (!mounted) {
      return;
    }
    _studentIdController.clear();
    _passwordController.clear();
    setState(() {
      _storedCredential = null;
      _autoLoginEnabled = false;
    });
    showAppSnackBar(context, SnackBar(content: Text(clearedMessage)));
  }

  Future<void> _runAutoTimetableImport() async {
    await _runAutoAcademicImport(
      kind: _ImportAction.timetable,
      targetUrl: ScheduleHtmlExtractor.academicTimetableUrl,
      readyScript: AcademicAutoLoginService.timetableReadyScript,
      timeout: _autoImportTimeout,
      openingMessageKey: 'auto_import_opening',
      waitingMessageKey: 'auto_import_waiting_table',
      extractingMessageKey: 'auto_import_extracting',
      extract: _runTimetableExtractScript,
    );
  }

  Future<void> _runAutoExamImport() async {
    await _runAutoAcademicImport(
      kind: _ImportAction.exam,
      targetUrl: ScheduleHtmlExtractor.academicExamUrl,
      readyScript: AcademicAutoLoginService.examReadyScript,
      timeout: _autoExamImportTimeout,
      openingMessageKey: 'auto_exam_import_opening',
      waitingMessageKey: 'auto_exam_import_waiting_table',
      extractingMessageKey: 'auto_exam_import_extracting',
      refreshBeforeWaitingScript: AcademicAutoLoginService.examRefreshScript,
      extract: _runExamExtractScript,
    );
  }

  Future<void> _runAutoGradeImport() async {
    await _runAutoAcademicImport(
      kind: _ImportAction.grade,
      targetUrl: ScheduleHtmlExtractor.academicGradeUrl,
      readyScript: AcademicAutoLoginService.gradeReadyScript,
      timeout: _autoGradeImportTimeout,
      openingMessageKey: 'auto_grade_import_opening',
      waitingMessageKey: 'auto_grade_import_waiting_table',
      extractingMessageKey: 'auto_grade_import_extracting',
      extract: _runGradeExtractScript,
    );
  }

  Future<void> _runAutoAcademicImport({
    required _ImportAction kind,
    required String targetUrl,
    required String readyScript,
    required Duration timeout,
    required String openingMessageKey,
    required String waitingMessageKey,
    required String extractingMessageKey,
    required Future<void> Function() extract,
    String? refreshBeforeWaitingScript,
  }) async {
    await _controllerReady;
    if (!await _ensureSemesterInitializedForImport(kind)) {
      return;
    }
    if (!mounted) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    final credential = _credentialFromInput() ?? _storedCredential;
    if (credential == null) {
      _finishImportWithMessage(
        settingsProvider.t('academic_credentials_empty'),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await _credentialService.save(credential);
    if (!mounted) {
      return;
    }

    setState(() {
      _storedCredential = credential;
      _autoImportStatus = settingsProvider.t(openingMessageKey);
    });

    var attempt = 0;
    try {
      while (mounted) {
        try {
          if (attempt > 0) {
            _setAutoImportStatus(settingsProvider.t('auto_import_retrying'));
            await Future<void>.delayed(_autoRetryDelay);
          }
          _logAcademicAutoImport(
            'attempt=${attempt + 1} action=${kind.name} target=$targetUrl',
          );
          await _controller.loadRequest(Uri.parse(targetUrl));
          await _waitForAutoPageReady(
            credential: credential,
            targetUrl: targetUrl,
            readyScript: readyScript,
            timeout: timeout,
            openingMessageKey: openingMessageKey,
            waitingMessageKey: waitingMessageKey,
            refreshBeforeWaitingScript: refreshBeforeWaitingScript,
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _activeAction = kind;
            _autoImportStatus = settingsProvider.t(extractingMessageKey);
          });
          await extract();
          return;
        } catch (error) {
          final reason = error.toString();
          final canRetry =
              attempt < _maxAutoImportRecoverableRetries &&
              isRecoverableAcademicAutoImportError(reason);
          _logAcademicAutoImport(
            'attempt=${attempt + 1} failed recoverable=$canRetry reason=$reason',
          );
          if (canRetry) {
            attempt += 1;
            continue;
          }

          final message = settingsProvider
              .t('auto_import_failed')
              .replaceAll('{reason}', reason);
          _finishImportWithMessage(message);
          if (!widget.showWebView && widget.onImportError == null) {
            setState(() {
              _autoImportStatus = message;
            });
            await Future<void>.delayed(const Duration(seconds: 2));
            if (mounted) {
              await Navigator.of(context).maybePop();
            }
          }
          return;
        }
      }
    } finally {
      if (mounted && widget.showWebView) {
        setState(() {
          _autoImportStatus = null;
        });
      }
    }
  }

  Future<void> _waitForAutoPageReady({
    required AcademicCredential credential,
    required String targetUrl,
    required String readyScript,
    required Duration timeout,
    required String openingMessageKey,
    required String waitingMessageKey,
    String? refreshBeforeWaitingScript,
  }) async {
    final settingsProvider = context.read<SettingsProvider>();
    final deadline = DateTime.now().add(timeout);
    var redirectedFromHome = false;
    var refreshAttempted = false;
    var portalLoginSubmissionCount = 0;
    String? lastLoggedUrl;
    AcademicPageKind? lastLoggedPageKind;

    while (DateTime.now().isBefore(deadline)) {
      final currentUrl = await _controller.currentUrl();
      final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
      final pageKind = AcademicAutoLoginService.classifyUrl(uri);
      if (currentUrl != lastLoggedUrl || pageKind != lastLoggedPageKind) {
        lastLoggedUrl = currentUrl;
        lastLoggedPageKind = pageKind;
        _logAcademicAutoImport('page kind=$pageKind url=$currentUrl');
      }
      if (!refreshAttempted &&
          refreshBeforeWaitingScript != null &&
          pageKind == AcademicPageKind.exam) {
        refreshAttempted = true;
        _setAutoImportStatus(settingsProvider.t(waitingMessageKey));
        await _runOptionalRefreshScript(refreshBeforeWaitingScript);
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }

      final pageReady = await _isPageReady(readyScript);
      if (pageReady) {
        return;
      }

      switch (pageKind) {
        case AcademicPageKind.casLogin:
          if (portalLoginSubmissionCount >= _maxPortalLoginSubmissions) {
            _setAutoImportStatus(settingsProvider.t('auto_import_logging_in'));
            break;
          }
          final loginResult = await _runUnifiedPortalLoginScript(credential);
          _logAcademicAutoImport(
            'portal login result=$loginResult '
            'submissionCount=$portalLoginSubmissionCount',
          );
          if (loginResult == 'CHALLENGE_REQUIRED') {
            throw settingsProvider.t('auto_import_challenge_required');
          }
          if (loginResult.startsWith('JS_ERROR:')) {
            throw loginResult.replaceFirst('JS_ERROR:', '').trim();
          }
          if (loginResult == 'SUBMITTED') {
            portalLoginSubmissionCount += 1;
            _setAutoImportStatus(settingsProvider.t('auto_import_logging_in'));
          } else if (loginResult == 'MISSING_FORM') {
            _setAutoImportStatus(
              settingsProvider.t('auto_import_waiting_unified_login'),
            );
          } else if (loginResult == 'MISSING_SUBMIT') {
            _setAutoImportStatus(
              settingsProvider.t('auto_import_waiting_unified_login'),
            );
          }
        case AcademicPageKind.jwLogin:
          _setAutoImportStatus(
            settingsProvider.t('auto_import_redirecting_portal'),
          );
          await _controller.loadRequest(
            Uri.parse(ScheduleHtmlExtractor.academicCasLoginUrl),
          );
        case AcademicPageKind.jwSsoLogin:
          _setAutoImportStatus(settingsProvider.t('auto_import_waiting_page'));
        case AcademicPageKind.studentHome:
          if (!redirectedFromHome) {
            redirectedFromHome = true;
            _setAutoImportStatus(settingsProvider.t(openingMessageKey));
            await _controller.loadRequest(Uri.parse(targetUrl));
          }
        case AcademicPageKind.timetable:
        case AcademicPageKind.exam:
        case AcademicPageKind.grade:
          _setAutoImportStatus(settingsProvider.t(waitingMessageKey));
        case AcademicPageKind.other:
          _setAutoImportStatus(settingsProvider.t('auto_import_waiting_page'));
      }

      await Future<void>.delayed(_autoStepDelay);
    }

    throw settingsProvider.t('auto_import_timeout');
  }

  Future<String> _runUnifiedPortalLoginScript(
    AcademicCredential credential,
  ) async {
    final rawResult = await _controller.runJavaScriptReturningResult(
      AcademicAutoLoginService.buildUnifiedPortalLoginScript(credential),
    );
    return _normalizeJavaScriptResult(rawResult);
  }

  Future<bool> _isPageReady(String readyScript) async {
    try {
      final rawResult = await _controller.runJavaScriptReturningResult(
        readyScript,
      );
      return _normalizeJavaScriptResult(rawResult) == 'READY';
    } catch (_) {
      return false;
    }
  }

  Future<void> _runOptionalRefreshScript(String script) async {
    try {
      await _controller.runJavaScriptReturningResult(script);
    } catch (error) {
      debugPrint('[AcademicAutoImport] optional refresh script failed: $error');
    }
  }

  void _setAutoImportStatus(String message) {
    if (!mounted || _autoImportStatus == message) {
      return;
    }
    setState(() {
      _autoImportStatus = message;
    });
  }

  Future<void> _showImportWebViewGuideIfNeeded() async {
    if (_isImportGuideShowing || !mounted) {
      return;
    }

    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.shouldShowImportWebViewGuide) {
      return;
    }

    _isImportGuideShowing = true;
    await showGuidedTourOverlay(
      context: context,
      steps: [
        GuidedTourStep(
          targetKey: _webViewGuideKey,
          title: settingsProvider.t('guide_import_webview_title'),
          body: settingsProvider.t('guide_import_webview_body'),
        ),
        GuidedTourStep(
          targetKey: _examGuideKey,
          title: settingsProvider.t('guide_import_exam_title'),
          body: settingsProvider.t('guide_import_exam_body'),
        ),
        GuidedTourStep(
          targetKey: _timetableGuideKey,
          title: settingsProvider.t('guide_import_timetable_title'),
          body: settingsProvider.t('guide_import_timetable_body'),
        ),
      ],
      nextLabel: settingsProvider.t('guide_next'),
      doneLabel: settingsProvider.t('guide_done'),
      stepLabelBuilder: (currentStep, totalSteps) {
        return settingsProvider
            .t('guide_step_counter')
            .replaceAll('{current}', currentStep.toString())
            .replaceAll('{total}', totalSteps.toString());
      },
    );

    if (!mounted) {
      return;
    }

    await context.read<SettingsProvider>().confirmImportWebViewGuide();
    _isImportGuideShowing = false;
  }

  Future<bool> _ensureSemesterInitializedForImport(_ImportAction action) async {
    final settingsProvider = context.read<SettingsProvider>();
    final blockedMessage = buildUninitializedAcademicImportMessage(
      kind: switch (action) {
        _ImportAction.timetable => AcademicImportKind.timetable,
        _ImportAction.exam => AcademicImportKind.exam,
        _ImportAction.grade => AcademicImportKind.grade,
      },
      isCurrentSemesterInitialized:
          settingsProvider.isCurrentSemesterInitialized,
    );
    if (blockedMessage == null) {
      return true;
    }

    _finishImportWithMessage(blockedMessage);
    return false;
  }

  Future<void> _runTimetableExtractScript() async {
    if (!await _ensureSemesterInitializedForImport(_ImportAction.timetable)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _activeAction = _ImportAction.timetable;
    });

    try {
      if (await _tryImportTimetableViaApi()) {
        return;
      }
      final rawHtml = await _runJavaScriptExtraction(
        ScheduleHtmlExtractor.extractTimetableHtmlScript,
      );
      await _handleTimetableHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('课表提取失败：$error');
    }
  }

  Future<void> _runExamExtractScript() async {
    if (!await _ensureSemesterInitializedForImport(_ImportAction.exam)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _activeAction = _ImportAction.exam;
    });

    try {
      await _prepareExamPageForExtraction();
      if (await _tryImportExamViaApi()) {
        return;
      }
      final rawHtml = await _runJavaScriptExtraction(
        ScheduleHtmlExtractor.extractExamHtmlScript,
        settleDelay: Duration.zero,
      );
      await _handleExamHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('考试提取失败：$error');
    }
  }

  Future<void> _runGradeExtractScript() async {
    if (!await _ensureSemesterInitializedForImport(_ImportAction.grade)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _activeAction = _ImportAction.grade;
    });

    try {
      if (await _tryImportGradesViaApi()) {
        return;
      }
      final rawHtml = await _runJavaScriptExtraction(
        'document.documentElement.outerHTML',
        settleDelay: Duration.zero,
      );
      await _handleGradeHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('成绩提取失败：$error');
    }
  }

  Future<String> _runJavaScriptExtraction(
    String script, {
    Duration settleDelay = _extractScriptSettleDelay,
  }) async {
    await Future<void>.delayed(settleDelay);
    await _ensureCurrentPageCanBeExtracted();
    final rawResult = await _controller.runJavaScriptReturningResult(script);
    return _normalizeJavaScriptResult(rawResult);
  }

  Future<void> _prepareExamPageForExtraction() async {
    await _installExamDiagnosticProbe();
    await _logExamDiagnosticSnapshot('before-refresh');
    await _runOptionalRefreshScript(AcademicAutoLoginService.examRefreshScript);
    await Future<void>.delayed(_examExtractScriptSettleDelay);
    await _logExamDiagnosticSnapshot('after-refresh');
  }

  Future<bool> _tryImportTimetableViaApi() async {
    var handled = false;
    try {
      await _ensureCurrentPageCanBeExtracted();
      final pageHtml = await _runJavaScriptExtraction(
        'document.documentElement.outerHTML',
      );
      final semesterId = _courseApiParser.extractCurrentSemesterId(pageHtml);
      if (semesterId == null) {
        _logAcademicAutoImport(
          'course api skipped: currentSemester.id not found',
        );
        return false;
      }
      _logAcademicAutoImport('course api semesterId=$semesterId');

      final response = await _requireFetchClient().fetch(
        AcademicApiEndpoints.timetablePrintData(semesterId),
      );
      final report = _courseApiParser.parsePrintData(response.body);
      _logAcademicAutoImport(
        'course api parsed courses=${report.items.length} skipped=${report.skippedReasons.length}',
      );
      if (report.items.isEmpty) {
        _logAcademicAutoImport(
          'course api returned empty activities bodyLength=${response.body.length}',
        );
        return false;
      }
      await _initializeSemesterFromTimetablePageIfNeeded();
      if (!mounted) {
        handled = true;
        return true;
      }
      await _importTimetableReport(report);
      handled = true;
      return true;
    } catch (error) {
      if (_shouldSurfaceApiError(error)) {
        rethrow;
      }
      _logAcademicAutoImport('course api fallback to html: $error');
      return false;
    } finally {
      if (handled && mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }

  Future<bool> _tryImportExamViaApi() async {
    var handled = false;
    try {
      await _ensureCurrentPageCanBeExtracted();
      var rawExamInfo = await _runJavaScriptExtraction(
        _extractExamInfoVmsScript,
        settleDelay: Duration.zero,
      );
      if (rawExamInfo.isNotEmpty && rawExamInfo != 'null') {
        _logAcademicAutoImport('exam api studentExamInfoVms found in page');
      }
      if (rawExamInfo.isEmpty || rawExamInfo == 'null') {
        final urls = <Uri>[];
        final currentUrl = await _controller.currentUrl();
        final currentUri = currentUrl == null ? null : Uri.tryParse(currentUrl);
        if (currentUri != null && _isAllowedAcademicUri(currentUri)) {
          urls.add(currentUri);
        }
        final examArrangeUri = AcademicApiEndpoints.examArrange();
        if (!urls.any((uri) => uri.toString() == examArrangeUri.toString())) {
          urls.add(examArrangeUri);
        }
        for (final url in urls) {
          final response = await _requireFetchClient().fetch(
            url,
            accept: 'text/html,application/xhtml+xml,*/*',
          );
          _logExamHtmlFetchDiagnostic(url, response);
          rawExamInfo =
              _examApiParser.extractStudentExamInfoVms(response.body) ?? '';
          if (rawExamInfo.isNotEmpty && rawExamInfo != 'null') {
            _logAcademicAutoImport(
              'exam api studentExamInfoVms extracted from html url=$url',
            );
            break;
          }
          if (_containsExamTableHtml(response.body)) {
            final importedEvents = _parserService.parseExams(response.body);
            _logAcademicAutoImport(
              'exam api parsed events=${importedEvents.length} source=html-fetch url=$url',
            );
            await _importExamEvents(importedEvents);
            handled = true;
            return true;
          }
        }
      }
      if (rawExamInfo.isEmpty || rawExamInfo == 'null') {
        _logAcademicAutoImport('exam api skipped: studentExamInfoVms missing');
        return false;
      }

      final importedEvents = _examApiParser.parseStudentExamInfoVms(
        rawExamInfo,
      );
      _logAcademicAutoImport('exam api parsed events=${importedEvents.length}');
      await _importExamEvents(importedEvents);
      handled = true;
      return true;
    } catch (error) {
      if (_shouldSurfaceApiError(error)) {
        rethrow;
      }
      _logAcademicAutoImport('exam api fallback to html: $error');
      return false;
    } finally {
      if (handled && mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }

  Future<bool> _tryImportGradesViaApi() async {
    var handled = false;
    try {
      await _ensureCurrentPageCanBeExtracted();
      final currentUrl = await _controller.currentUrl();
      final pageHtml = await _runJavaScriptExtraction(
        'document.documentElement.outerHTML',
        settleDelay: Duration.zero,
      );
      final studentId = _gradeParser.extractStudentIdFromGradeSheetUrl(
        currentUrl ?? '',
      );
      if (studentId == null) {
        _logAcademicAutoImport(
          'grade api skipped: student id missing url=$currentUrl',
        );
        return false;
      }
      _logAcademicAutoImport('grade api id=$studentId pageUrl=$currentUrl');

      final pageBook = _tryParseGradeSheetHtml(pageHtml, studentId: studentId);
      final response = await _requireFetchClient().fetch(
        AcademicApiEndpoints.gradeInfo(studentId),
      );
      final apiBook = _gradeParser.parseGradeInfo(
        response.body,
        studentId: studentId,
        fetchedAt: DateTime.now(),
      );
      final book = _gradeParser.mergeGradeBooks(
        primary: apiBook,
        metadataFallback: pageBook,
      );
      final statsState = book.statistics == null ? 'none' : 'found';
      _logAcademicAutoImport(
        'grade api parsed terms=${book.terms.length} records=${book.recordCount} '
        'source=json-fetch stats=$statsState',
      );
      if (book.recordCount == 0) {
        _logAcademicAutoImport(
          'grade api returned empty bodyLength=${response.body.length}',
        );
        return false;
      }
      await _saveGradeBook(book);
      handled = true;
      return true;
    } catch (error) {
      if (_shouldSurfaceApiError(error)) {
        rethrow;
      }
      _logAcademicAutoImport('grade api fallback to html: $error');
      return false;
    } finally {
      if (handled && mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }

  GradeBook? _tryParseGradeSheetHtml(
    String rawHtml, {
    required String? studentId,
  }) {
    try {
      return _gradeParser.parseGradeSheetHtml(
        rawHtml,
        studentId: studentId,
        fetchedAt: DateTime.now(),
        allowEmptyTerms: true,
      );
    } catch (error) {
      _logAcademicAutoImport('grade html metadata parse skipped: $error');
      return null;
    }
  }

  bool _containsExamTableHtml(String html) {
    final lowerHtml = html.toLowerCase();
    return lowerHtml.contains('id="exams"') ||
        lowerHtml.contains("id='exams'") ||
        lowerHtml.contains('exam-table');
  }

  Future<void> _installExamDiagnosticProbe() async {
    if (!kDebugMode) {
      return;
    }
    try {
      await _ensureCurrentPageCanBeExtracted();
      final rawResult = await _controller.runJavaScriptReturningResult(
        AcademicExamDiagnostics.installNetworkProbeScript,
      );
      _logAcademicAutoImport(
        'exam diag probe ${_normalizeJavaScriptResult(rawResult)}',
      );
    } catch (error) {
      _logAcademicAutoImport('exam diag probe failed: $error');
    }
  }

  Future<void> _logExamDiagnosticSnapshot(String stage) async {
    if (!kDebugMode) {
      return;
    }
    try {
      final rawSnapshot = await _runJavaScriptExtraction(
        AcademicExamDiagnostics.collectSnapshotScript,
        settleDelay: Duration.zero,
      );
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is! Map) {
        _logAcademicAutoImport('exam diag $stage malformed snapshot');
        return;
      }
      final lines = AcademicExamDiagnostics.summarizeSnapshot(
        Map<String, dynamic>.from(decoded),
        stage: stage,
      );
      for (final line in lines) {
        _logAcademicAutoImport(line);
      }
    } catch (error) {
      _logAcademicAutoImport('exam diag $stage failed: $error');
    }
  }

  void _logExamHtmlFetchDiagnostic(
    Uri requestedUrl,
    AcademicFetchResponse response,
  ) {
    if (!kDebugMode) {
      return;
    }
    final body = response.body;
    final lowerBody = body.toLowerCase();
    _logAcademicAutoImport(
      'exam html fetch requested=$requestedUrl '
      'status=${response.status} finalUrl=${response.url} '
      'contentType=${response.contentType} bodyLength=${body.length} '
      'containsStudentExamInfoVms=${body.contains('studentExamInfoVms')} '
      'containsExam=${lowerBody.contains('exam') || body.contains('考试')} '
      'containsArrange=${lowerBody.contains('arrange')} '
      'containsRefresh=${body.contains('刷新')} '
      'containsTable=${lowerBody.contains('<table')} '
      'head=${_logSnippet(body)} tail=${_logSnippet(body, tail: true)}',
    );
  }

  String _logSnippet(String value, {bool tail = false}) {
    const limit = 240;
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= limit) {
      return jsonEncode(normalized);
    }
    final snippet = tail
        ? normalized.substring(normalized.length - limit)
        : normalized.substring(0, limit);
    return jsonEncode(snippet);
  }

  AcademicWebViewFetchClient _requireFetchClient() {
    final client = _fetchClient;
    if (client == null) {
      throw ScheduleParseException('教务 WebView 同源请求通道尚未初始化。');
    }
    return client;
  }

  bool _shouldSurfaceApiError(Object error) {
    return error is AcademicFetchException &&
        error.code == AcademicFetchErrorCode.loginExpired;
  }

  Future<void> _ensureCurrentPageCanBeExtracted() async {
    final currentUrl = await _controller.currentUrl();
    final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    if (uri == null || !_isAllowedAcademicUri(uri)) {
      throw ScheduleParseException('当前页面不属于允许导入的教务系统域名，请返回安徽大学教务页面后重试。');
    }
  }

  bool _isAllowedAcademicUri(Uri uri) {
    return AcademicAutoLoginService.isAllowedAcademicUri(uri);
  }

  void _showBlockedNavigationMessage(String url) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(
      context,
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text('已阻止跳转到非教务系统页面：$url'),
      ),
    );
  }

  Future<void> _handleTimetableHtml(String rawMessage) async {
    try {
      if (rawMessage.startsWith('JS_ERROR:')) {
        throw ScheduleParseException('教务系统连接失败，请检查网络或重新登录后重试。');
      }

      if (rawMessage.startsWith('ERROR:')) {
        throw ScheduleParseException(
          rawMessage.replaceFirst('ERROR:', '').trim(),
        );
      }

      final parseReport = _parserService.parseTimetableReport(rawMessage);
      await _initializeSemesterFromTimetablePageIfNeeded();
      await _importTimetableReport(parseReport);
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('课表导入失败：${error.message}');
    } catch (error) {
      _finishImportWithMessage('课表导入失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _importTimetableReport(
    ScheduleParseReport<Course> parseReport,
  ) async {
    if (!mounted) {
      return;
    }

    final courseProvider = context.read<CourseProvider>();
    final importedCount = await importTimetableCoursesWithConflictConfirmation(
      context: context,
      courseProvider: courseProvider,
      courses: parseReport.items,
      confirmConflicts: widget.confirmTimetableConflicts,
    );

    if (!mounted || importedCount == null) {
      return;
    }
    _completeImport(
      AcademicImportResult(
        kind: AcademicImportKind.timetable,
        importedCount: importedCount,
        skippedReasons: parseReport.skippedReasons,
      ),
    );
  }

  Future<void> _initializeSemesterFromTimetablePageIfNeeded() async {
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.isCurrentSemesterInitialized) {
      _logAcademicAutoImport(
        'teach week sync skipped: semester already initialized',
      );
      return;
    }

    await _syncTeachWeekForTimetableImportIfPossible();
    if (!mounted ||
        context.read<SettingsProvider>().isCurrentSemesterInitialized) {
      return;
    }

    final rawStartDate = await _runJavaScriptExtraction(
      ScheduleHtmlExtractor.extractSemesterStartDateScript,
    );
    if (rawStartDate.startsWith('JS_ERROR:')) {
      throw ScheduleParseException('教务系统连接失败，请检查网络或重新登录后重试。');
    }
    if (rawStartDate.startsWith('ERROR:')) {
      throw ScheduleParseException('未在课表页面找到学期起始日期，请确认已打开课表页面后重试。');
    }

    final startDate = ScheduleHtmlExtractor.parseSemesterStartDate(
      rawStartDate,
    );
    if (startDate == null) {
      throw ScheduleParseException('学期起始日期格式无效，请确认课表页面显示正确后重试。');
    }
    await settingsProvider.initializeCurrentSemesterFromAcademicImport(
      startDate,
    );
  }

  Future<bool> _syncTeachWeekForTimetableImportIfPossible() async {
    final client = _fetchClient;
    if (client == null || !mounted) {
      return false;
    }
    try {
      final settingsProvider = context.read<SettingsProvider>();
      final response = await client.fetch(
        AcademicApiEndpoints.teachWeek(),
        timeout: _teachWeekSyncTimeout,
      );
      final snapshot = _weekSyncService.parseSnapshot(response.body);
      final result = _weekSyncService.buildCalibration(
        snapshot: snapshot,
        now: DateTime.now(),
        localSemesterStartDate: settingsProvider.semesterStartDate,
        totalWeeks: settingsProvider.totalWeeks,
        isCurrentSemesterInitialized:
            settingsProvider.isCurrentSemesterInitialized,
      );
      if (result.shouldInitializeCurrentSemester &&
          result.remoteSemesterStartDate != null) {
        if (!mounted) {
          return false;
        }
        await settingsProvider.initializeCurrentSemesterFromAcademicImport(
          result.remoteSemesterStartDate!,
        );
        _logAcademicAutoImport(
          'teach week initialized semester start=${result.remoteSemesterStartDate}',
        );
        return true;
      }
      if (result.requiresUserConfirmation) {
        _logAcademicAutoImport(
          'teach week calibration suggested remoteWeek=${result.remoteWeekIndex} '
          'localWeek=${result.localWeekIndex} start=${result.remoteSemesterStartDate}',
        );
      }
    } catch (error) {
      _logAcademicAutoImport('teach week sync skipped: $error');
    }
    return false;
  }

  Future<void> _handleExamHtml(String rawMessage) async {
    try {
      if (rawMessage.startsWith('JS_ERROR:')) {
        throw ScheduleParseException('教务系统连接失败，请检查网络或重新登录后重试。');
      }

      if (rawMessage.startsWith('ERROR:')) {
        throw ScheduleParseException(
          rawMessage.replaceFirst('ERROR:', '').trim(),
        );
      }

      final importedEvents = _parserService.parseExams(rawMessage);
      await _importExamEvents(importedEvents);
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('考试导入失败：${error.message}');
    } catch (error) {
      _finishImportWithMessage('考试导入失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _handleGradeHtml(String rawMessage) async {
    try {
      if (rawMessage.startsWith('JS_ERROR:')) {
        throw ScheduleParseException('教务系统连接失败，请检查网络或重新登录后重试。');
      }

      if (rawMessage.startsWith('ERROR:')) {
        throw ScheduleParseException(
          rawMessage.replaceFirst('ERROR:', '').trim(),
        );
      }

      final currentUrl = await _controller.currentUrl();
      final studentId = _gradeParser.extractStudentIdFromGradeSheetUrl(
        currentUrl ?? '',
      );
      final book = _gradeParser.parseGradeSheetHtml(
        rawMessage,
        studentId: studentId,
        fetchedAt: DateTime.now(),
      );
      final statsState = book.statistics == null ? 'none' : 'found';
      _logAcademicAutoImport(
        'grade api parsed terms=${book.terms.length} records=${book.recordCount} '
        'source=html-dom stats=$statsState',
      );
      await _saveGradeBook(book);
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('成绩提取失败：${error.message}');
    } catch (error) {
      _finishImportWithMessage('成绩提取失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }

  Future<void> _importExamEvents(List<Event> importedEvents) async {
    final settingsProvider = context.read<SettingsProvider>();
    final courseProvider = context.read<CourseProvider>();
    final emptyMessage = settingsProvider.t('exam_import_empty');
    final duplicatedMessage = settingsProvider.t('exam_import_duplicated');
    final importedCount = await courseProvider.mergeImportedEvents(
      importedEvents,
    );
    if (!mounted) {
      return;
    }
    final result = buildExamImportResult(
      hasParsedEvents: importedEvents.isNotEmpty,
      importedCount: importedCount,
      emptyMessage: emptyMessage,
      duplicatedMessage: duplicatedMessage,
    );
    if (result.importedCount == 0 &&
        widget.onImportResult == null &&
        widget.showWebView) {
      _finishImportWithNeutralMessage(result.skippedReasons.first);
      return;
    }

    _completeImport(result);
  }

  Future<void> _saveGradeBook(GradeBook book) async {
    await context.read<GradeProvider>().replaceWithFetched(book);
    if (!mounted) {
      return;
    }
    _completeImport(
      AcademicImportResult(
        kind: AcademicImportKind.grade,
        importedCount: book.recordCount,
      ),
    );
  }

  void _completeImport(AcademicImportResult result) {
    final onImportResult = widget.onImportResult;
    if (onImportResult != null) {
      onImportResult(result);
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(result);
  }

  void _finishImportWithNeutralMessage(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeAction = null;
    });

    showAppSnackBar(context, SnackBar(content: Text(message)));
  }

  void _finishImportWithMessage(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _activeAction = null;
    });

    final onImportError = widget.onImportError;
    if (onImportError != null) {
      onImportError(message);
      return;
    }

    showAppSnackBar(
      context,
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
  }

  String _normalizeJavaScriptResult(Object rawResult) {
    if (rawResult is String) {
      final trimmed = rawResult.trim();
      if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
        return '';
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded;
        }
      } catch (_) {
        return trimmed;
      }
      return trimmed;
    }
    return rawResult.toString();
  }
}
