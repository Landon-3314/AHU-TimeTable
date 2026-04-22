import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_colors.dart';
import '../providers/course_provider.dart';
import '../providers/settings_provider.dart';
import '../services/schedule_html_extractor.dart';
import '../services/schedule_parser_service.dart';

class ImportCoursePage extends StatefulWidget {
  const ImportCoursePage({super.key});

  @override
  State<ImportCoursePage> createState() => _ImportCoursePageState();
}

class _ImportCoursePageState extends State<ImportCoursePage> {
  static const ScheduleParserService _parserService = ScheduleParserService();
  static const Duration _extractScriptSettleDelay = Duration(milliseconds: 350);

  late final WebViewController _controller;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(ScheduleHtmlExtractor.academicLoginUrl));
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(settingsProvider.t('academic_import'))),
      body: WebViewWidget(controller: _controller),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isImporting ? null : _runExtractScript,
        icon: const Icon(Icons.download_for_offline_outlined),
        label: Text(
          _isImporting
              ? settingsProvider.t('extracting')
              : settingsProvider.t('extract_timetable'),
        ),
      ),
    );
  }

  Future<void> _runExtractScript() async {
    setState(() {
      _isImporting = true;
    });

    try {
      await Future<void>.delayed(_extractScriptSettleDelay);
      final rawResult = await _controller.runJavaScriptReturningResult(
        ScheduleHtmlExtractor.extractTimetableHtmlScript,
      );
      final rawHtml = _normalizeJavaScriptResult(rawResult);
      await _handleImportedHtml(rawHtml);
    } catch (error) {
      _finishImportWithMessage('Timetable extraction failed: $error');
    }
  }

  Future<void> _handleImportedHtml(String rawMessage) async {
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
      final importedCount = await context.read<CourseProvider>()
          .mergeImportedCourses(importedCourses);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(importedCount);
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('Import failed: ${error.message}');
    } catch (error) {
      _finishImportWithMessage('Import failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _finishImportWithMessage(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isImporting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
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
