import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_constants.dart';
import '../models/grade.dart';
import '../providers/grade_provider.dart';
import '../services/academic_api_endpoints.dart';
import '../services/academic_auto_login_service.dart';
import '../services/academic_webview_fetch_client.dart';
import '../services/grade_parser_service.dart';
import '../widgets/common/app_ui.dart';

class GradeOverviewPage extends StatefulWidget {
  const GradeOverviewPage({super.key});

  @override
  State<GradeOverviewPage> createState() => _GradeOverviewPageState();
}

class _GradeOverviewPageState extends State<GradeOverviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(context.read<GradeProvider>().loadCached());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradeProvider = context.watch<GradeProvider>();
    final book = gradeProvider.gradeBook;
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务成绩'),
        actions: [
          IconButton(
            tooltip: '刷新成绩',
            onPressed: () => _openRefreshPage(context),
            icon: const Icon(Icons.refresh_outlined),
          ),
          IconButton(
            tooltip: '清除缓存',
            onPressed: book == null ? null : () => _clearCache(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: book == null || book.isEmpty
          ? AppEmptyState(
              icon: Icons.school_outlined,
              title: '暂无成绩缓存',
              subtitle: '登录教务并刷新后，会按学期展示已发布的课程成绩。',
              action: FilledButton.icon(
                onPressed: () => _openRefreshPage(context),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: const Text('刷新成绩'),
              ),
            )
          : ListView(
              padding: AppSpacing.pagePadding,
              children: [
                _GradeSummary(book: book),
                const SizedBox(height: AppSpacing.lg),
                for (final term in book.terms) ...[
                  _GradeTermSection(term: term),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
    );
  }

  Future<void> _openRefreshPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const GradeRefreshPage()));
  }

  Future<void> _clearCache(BuildContext context) async {
    await context.read<GradeProvider>().clearCache();
    if (!context.mounted) {
      return;
    }
    showAppSnackBar(context, const SnackBar(content: Text('成绩缓存已清除')));
  }
}

class _GradeSummary extends StatelessWidget {
  const _GradeSummary({required this.book});

  final GradeBook book;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近刷新：${DateFormat('yyyy/MM/dd HH:mm').format(book.fetchedAt)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (book.studentId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('学号：${book.studentId}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradeTermSection extends StatelessWidget {
  const _GradeTermSection({required this.term});

  final GradeTerm term;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.semesterName.isEmpty
                  ? '学期 ${term.remoteSemesterId}'
                  : term.semesterName,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final record in term.records) _GradeRecordRow(record: record),
          ],
        ),
      ),
    );
  }
}

class _GradeRecordRow extends StatelessWidget {
  const _GradeRecordRow({required this.record});

  final GradeRecord record;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (record.credits != null) '${record.credits!.toStringAsFixed(1)} 学分',
      if (record.gp != null) '绩点 ${record.gp!.toStringAsFixed(2)}',
      if (record.courseType != null) record.courseType!,
      if (record.passed != null) record.passed! ? '已通过' : '未通过',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.courseName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(meta),
                ],
                if (record.courseProperty != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(record.courseProperty!),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            record.grade ?? '未发布',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class GradeRefreshPage extends StatefulWidget {
  const GradeRefreshPage({super.key});

  @override
  State<GradeRefreshPage> createState() => _GradeRefreshPageState();
}

class _GradeRefreshPageState extends State<GradeRefreshPage> {
  static const GradeParserService _gradeParser = GradeParserService();

  late final WebViewController _controller;
  late final AcademicWebViewFetchClient _fetchClient;
  var _progress = 0;
  var _isRefreshing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _fetchClient = AcademicWebViewFetchClient(controller: _controller);
    unawaited(_initializeController());
  }

  @override
  void dispose() {
    _fetchClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('刷新成绩'),
        actions: [
          IconButton(
            tooltip: '保存成绩',
            onPressed: _isRefreshing ? null : _refreshGrades,
            icon: const Icon(Icons.save_alt_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(value: _progress.clamp(0, 100) / 100),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(_status!, textAlign: TextAlign.center),
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }

  Future<void> _initializeController() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.addJavaScriptChannel(
      AcademicWebViewFetchClient.channelName,
      onMessageReceived: (message) {
        _fetchClient.handleMessage(message.message);
      },
    );
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress.clamp(0, 100).toInt();
            });
          }
        },
        onPageFinished: (url) {
          _updateRefreshReadiness(url);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null ||
              !AcademicAutoLoginService.isAllowedAcademicUri(uri)) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );
    await _controller.loadRequest(AcademicApiEndpoints.gradeSheet());
  }

  Future<void> _updateRefreshReadiness([String? url]) async {
    final currentUrl = url ?? await _controller.currentUrl();
    if (!mounted) {
      return;
    }
    final uri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    final pageKind = AcademicAutoLoginService.classifyUrl(uri);
    final studentId = _gradeParser.extractStudentIdFromGradeSheetUrl(
      currentUrl ?? '',
    );
    final readyPath =
        uri?.host == AcademicApiEndpoints.academicHost &&
        uri?.path.startsWith('/student/for-std/grade/sheet') == true;
    setState(() {
      if (studentId != null || readyPath) {
        _status = '已可刷新成绩。';
      } else if (pageKind == AcademicPageKind.casLogin ||
          pageKind == AcademicPageKind.jwLogin ||
          pageKind == AcademicPageKind.jwSsoLogin ||
          pageKind == AcademicPageKind.other) {
        _status = '请先登录教务系统。';
      } else {
        _status = '请先登录教务系统。';
      }
    });
  }

  Future<void> _refreshGrades() async {
    setState(() {
      _isRefreshing = true;
      _status = '正在读取教务成绩...';
    });
    final success = await context.read<GradeProvider>().refreshViaWebView(
      () async {
        final sheetResponse = await _fetchClient.fetch(
          AcademicApiEndpoints.gradeSheet(),
          accept: 'text/html,application/xhtml+xml,*/*',
        );
        final currentUrl = await _controller.currentUrl();
        final studentId =
            _gradeParser.extractStudentIdFromGradeSheetUrl(sheetResponse.url) ??
            _gradeParser.extractStudentIdFromGradeSheetUrl(currentUrl ?? '');
        if (studentId == null) {
          throw StateError('未能识别学生编号，请确认已登录并停留在成绩页面。');
        }
        final gradeResponse = await _fetchClient.fetch(
          AcademicApiEndpoints.gradeInfo(studentId),
        );
        return _gradeParser.parseGradeInfo(
          gradeResponse.body,
          studentId: studentId,
          fetchedAt: DateTime.now(),
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isRefreshing = false;
      _status = success ? '成绩已刷新。' : context.read<GradeProvider>().lastError;
    });
    if (success) {
      showAppSnackBar(context, const SnackBar(content: Text('成绩已刷新')));
      Navigator.of(context).maybePop();
    } else {
      showAppSnackBar(
        context,
        SnackBar(
          content: Text(_status ?? '成绩刷新失败'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}
