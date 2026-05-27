import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/app_colors.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/schedule_html_extractor.dart';
import '../services/schedule_parser_service.dart';
import '../widgets/common/app_ui.dart';
import '../widgets/common/guided_tour_overlay.dart';

enum _ImportAction { timetable, exam }

enum AcademicImportKind { timetable, exam }

class AcademicImportResult {
  const AcademicImportResult({required this.kind, required this.importedCount});

  final AcademicImportKind kind;
  final int importedCount;
}

class ImportCoursePage extends StatefulWidget {
  const ImportCoursePage({super.key});

  @override
  State<ImportCoursePage> createState() => _ImportCoursePageState();
}

class _ImportCoursePageState extends State<ImportCoursePage> {
  static const ScheduleParserService _parserService = ScheduleParserService();
  static const Duration _extractScriptSettleDelay = Duration(milliseconds: 350);
  static const Set<String> _allowedAcademicHosts = <String>{
    'wvpn.ahu.edu.cn',
    'ahu.edu.cn',
  };
  static final Set<Factory<OneSequenceGestureRecognizer>>
  _webViewGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  late final WebViewController _controller;
  _ImportAction? _activeAction;
  final GlobalKey _webViewGuideKey = GlobalKey();
  final GlobalKey _examGuideKey = GlobalKey();
  final GlobalKey _timetableGuideKey = GlobalKey();
  int _pageLoadProgress = 100;
  bool _isImportGuideShowing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_initializeController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showImportWebViewGuideIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final activeAction = _activeAction;
    final isExtracting = activeAction != null;
    return Scaffold(
      appBar: AppBar(title: Text(settingsProvider.t('academic_import'))),
      body: Column(
        children: [
          _buildPageLoadProgress(),
          Expanded(
            child: KeyedSubtree(key: _webViewGuideKey, child: _buildWebView()),
          ),
        ],
      ),
      floatingActionButton: Column(
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
      Uri.parse(ScheduleHtmlExtractor.academicLoginUrl),
    );
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
      _finishImportWithMessage('Timetable extraction failed: $error');
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
      final rawHtml = await _runJavaScriptExtraction(
        ScheduleHtmlExtractor.extractExamHtmlScript,
      );
      await _handleExamHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('Exam extraction failed: $error');
    }
  }

  Future<String> _runJavaScriptExtraction(String script) async {
    await Future<void>.delayed(_extractScriptSettleDelay);
    await _ensureCurrentPageCanBeExtracted();
    final rawResult = await _controller.runJavaScriptReturningResult(script);
    return _normalizeJavaScriptResult(rawResult);
  }

  Future<void> _ensureCurrentPageCanBeExtracted() async {
    final currentUrl = await _controller.currentUrl();
    final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    if (uri == null || !_isAllowedAcademicUri(uri)) {
      throw ScheduleParseException(
        'Current page is outside the allowed academic domains. Please return to the AHU academic page before importing.',
      );
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
        content: Text('Blocked non-academic navigation: $url'),
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

      final importedCourses = _parserService.parse(rawMessage);
      final importedCount = await context
          .read<CourseProvider>()
          .mergeImportedCourses(importedCourses);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        AcademicImportResult(
          kind: AcademicImportKind.timetable,
          importedCount: importedCount,
        ),
      );
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('Import failed: ${error.message}');
    } catch (error) {
      _finishImportWithMessage('Import failed: $error');
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
      if (importedEvents.isEmpty) {
        _finishImportWithNeutralMessage(
          context.read<SettingsProvider>().t('exam_import_empty'),
        );
        return;
      }

      final importedCount = await context
          .read<CourseProvider>()
          .mergeImportedEvents(importedEvents);

      if (!mounted) {
        return;
      }

      if (importedCount == 0) {
        _finishImportWithNeutralMessage(
          context.read<SettingsProvider>().t('exam_import_duplicated'),
        );
        return;
      }

      Navigator.of(context).pop(
        AcademicImportResult(
          kind: AcademicImportKind.exam,
          importedCount: importedCount,
        ),
      );
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('Exam import failed: ${error.message}');
    } catch (error) {
      _finishImportWithMessage('Exam import failed: $error');
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
