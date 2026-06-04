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
import '../models/course.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/academic_auto_login_service.dart';
import '../services/academic_credential_service.dart';
import '../services/schedule_html_extractor.dart';
import '../services/schedule_parser_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/guided_tour_overlay.dart';

enum _ImportAction { timetable, exam }

enum AcademicImportKind { timetable, exam }

enum AcademicAutoAction { timetable, exam }

class AcademicImportResult {
  const AcademicImportResult({
    required this.kind,
    required this.importedCount,
    this.skippedReasons = const <String>[],
  });

  final AcademicImportKind kind;
  final int importedCount;
  final List<String> skippedReasons;

  int get skippedCount => skippedReasons.length;
}

Future<int?> importTimetableCoursesWithConflictConfirmation({
  required BuildContext context,
  required CourseProvider courseProvider,
  required List<Course> courses,
}) async {
  final conflicts = courseProvider.findImportedCourseConflicts(courses);
  var allowConflicts = false;
  if (conflicts.isNotEmpty) {
    allowConflicts = await showCourseConflictConfirmDialog(
      context,
      conflicts: conflicts,
    );
    if (!context.mounted || !allowConflicts) {
      return null;
    }
  }
  return courseProvider.mergeImportedCourses(
    courses,
    allowConflicts: allowConflicts,
  );
}

class ImportCoursePage extends StatefulWidget {
  const ImportCoursePage({
    super.key,
    this.initialAutoAction,
    this.showWebView = true,
    this.showCredentialPanel = false,
  });

  final AcademicAutoAction? initialAutoAction;
  final bool showWebView;
  final bool showCredentialPanel;

  @override
  State<ImportCoursePage> createState() => _ImportCoursePageState();
}

class _ImportCoursePageState extends State<ImportCoursePage> {
  static const ScheduleParserService _parserService = ScheduleParserService();
  static const AcademicCredentialService _credentialService =
      AcademicCredentialService();
  static const Duration _extractScriptSettleDelay = Duration(milliseconds: 350);
  static const Duration _examExtractScriptSettleDelay = Duration(seconds: 5);
  static const Duration _autoStepDelay = Duration(milliseconds: 700);
  static const Duration _autoImportTimeout = Duration(seconds: 30);
  static const Duration _autoExamImportTimeout = Duration(seconds: 70);
  static const Set<String> _allowedAcademicHosts = <String>{
    'wvpn.ahu.edu.cn',
    'ahu.edu.cn',
  };
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _webViewGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  late final WebViewController _controller;
  late final Future<void> _controllerReady;
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
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final activeAction = _activeAction;
    final isExtracting = activeAction != null || _autoImportStatus != null;
    return Scaffold(
      appBar: AppBar(title: Text(settingsProvider.t('academic_import'))),
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
    final status = _autoImportStatus;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentIdController,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      labelText: settingsProvider.t('academic_student_id'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    enabled: !isBusy,
                    decoration: InputDecoration(
                      labelText: settingsProvider.t('academic_password'),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    autofillHints: const [AutofillHints.password],
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(settingsProvider.t('academic_auto_login_enabled')),
              subtitle: Text(settingsProvider.t('academic_credentials_notice')),
              value: _autoLoginEnabled,
              onChanged: isBusy || _isCredentialLoading
                  ? null
                  : (value) {
                      setState(() {
                        _autoLoginEnabled = value;
                      });
                    },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: isBusy || _isCredentialLoading
                      ? null
                      : _saveCredentialFromInput,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(settingsProvider.t('save_academic_credentials')),
                ),
                if (_storedCredential != null)
                  TextButton.icon(
                    onPressed: isBusy ? null : _clearCredential,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      settingsProvider.t('clear_academic_credentials'),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: isBusy || _isCredentialLoading
                      ? null
                      : _runAutoTimetableImport,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(settingsProvider.t('auto_login_extract')),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy || _isCredentialLoading
                      ? null
                      : _runAutoExamImport,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(settingsProvider.t('auto_login_extract_exam')),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                status,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
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
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
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
    if (!await _ensureSemesterInitializedForImport()) {
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

    try {
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
    } catch (error) {
      final message = settingsProvider
          .t('auto_import_failed')
          .replaceAll('{reason}', error.toString());
      _finishImportWithMessage(message);
      if (!widget.showWebView) {
        setState(() {
          _autoImportStatus = message;
        });
        await Future<void>.delayed(const Duration(seconds: 2));
        if (mounted) {
          await Navigator.of(context).maybePop();
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

    while (DateTime.now().isBefore(deadline)) {
      final currentUrl = await _controller.currentUrl();
      final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
      final pageKind = AcademicAutoLoginService.classifyUrl(uri);
      if (!refreshAttempted &&
          refreshBeforeWaitingScript != null &&
          pageKind == AcademicPageKind.exam) {
        refreshAttempted = true;
        _setAutoImportStatus(settingsProvider.t(waitingMessageKey));
        await _runOptionalRefreshScript(refreshBeforeWaitingScript);
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }

      if (await _isPageReady(readyScript)) {
        return;
      }

      switch (pageKind) {
        case AcademicPageKind.casLogin:
        case AcademicPageKind.jwLogin:
          final loginResult = await _runAutoLoginScript(credential);
          if (loginResult == 'CHALLENGE_REQUIRED') {
            throw settingsProvider.t('auto_import_challenge_required');
          }
          if (loginResult.startsWith('JS_ERROR:')) {
            throw loginResult.replaceFirst('JS_ERROR:', '').trim();
          }
          if (loginResult == 'SUBMITTED') {
            _setAutoImportStatus(settingsProvider.t('auto_import_logging_in'));
          }
        case AcademicPageKind.studentHome:
          if (!redirectedFromHome) {
            redirectedFromHome = true;
            _setAutoImportStatus(settingsProvider.t(openingMessageKey));
            await _controller.loadRequest(Uri.parse(targetUrl));
          }
        case AcademicPageKind.timetable:
        case AcademicPageKind.exam:
          _setAutoImportStatus(settingsProvider.t(waitingMessageKey));
        case AcademicPageKind.other:
          _setAutoImportStatus(settingsProvider.t('auto_import_waiting_page'));
      }

      await Future<void>.delayed(_autoStepDelay);
    }

    throw settingsProvider.t('auto_import_timeout');
  }

  Future<String> _runAutoLoginScript(AcademicCredential credential) async {
    final rawResult = await _controller.runJavaScriptReturningResult(
      AcademicAutoLoginService.buildLoginScript(credential),
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
    } catch (_) {}
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

  Future<bool> _ensureSemesterInitializedForImport() async {
    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.isCurrentSemesterInitialized) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('当前学期尚未初始化'),
            content: const Text('当前学期尚未初始化，请先完成学期开始日期设置后再导入课程。'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          );
        },
      );
      return false;
    }

    return true;
  }

  Future<void> _runTimetableExtractScript() async {
    if (!await _ensureSemesterInitializedForImport()) {
      return;
    }

    setState(() {
      _activeAction = _ImportAction.timetable;
    });

    try {
      final rawHtml = await _runJavaScriptExtraction(
        ScheduleHtmlExtractor.extractTimetableHtmlScript,
      );
      await _handleTimetableHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('课表提取失败：$error');
    }
  }

  Future<void> _runExamExtractScript() async {
    if (!await _ensureSemesterInitializedForImport()) {
      return;
    }

    setState(() {
      _activeAction = _ImportAction.exam;
    });

    try {
      await _prepareExamPageForExtraction();
      final rawHtml = await _runJavaScriptExtraction(
        ScheduleHtmlExtractor.extractExamHtmlScript,
        settleDelay: Duration.zero,
      );
      await _handleExamHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('考试提取失败：$error');
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
    await _runOptionalRefreshScript(AcademicAutoLoginService.examRefreshScript);
    await Future<void>.delayed(_examExtractScriptSettleDelay);
  }

  Future<void> _ensureCurrentPageCanBeExtracted() async {
    final currentUrl = await _controller.currentUrl();
    final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    if (uri == null || !_isAllowedAcademicUri(uri)) {
      throw ScheduleParseException('当前页面不属于允许导入的教务系统域名，请返回安徽大学教务页面后重试。');
    }
  }

  bool _isAllowedAcademicUri(Uri uri) {
    if (uri.scheme != 'https') {
      return false;
    }

    final host = uri.host.toLowerCase();
    return _allowedAcademicHosts.contains(host) || host.endsWith('.ahu.edu.cn');
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
      final importedCount =
          await importTimetableCoursesWithConflictConfirmation(
            context: context,
            courseProvider: context.read<CourseProvider>(),
            courses: parseReport.items,
          );

      if (!mounted || importedCount == null) {
        return;
      }
      Navigator.of(context).pop(
        AcademicImportResult(
          kind: AcademicImportKind.timetable,
          importedCount: importedCount,
          skippedReasons: parseReport.skippedReasons,
        ),
      );
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
      if (importedEvents.isEmpty) {
        _finishImportWithNeutralMessage(emptyMessage);
        return;
      }

      if (importedCount == 0) {
        _finishImportWithNeutralMessage(duplicatedMessage);
        return;
      }

      Navigator.of(context).pop(
        AcademicImportResult(
          kind: AcademicImportKind.exam,
          importedCount: importedCount,
        ),
      );
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
