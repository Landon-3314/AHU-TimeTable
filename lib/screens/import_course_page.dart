import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      ..addJavaScriptChannel(
        'CourseDataChannel',
        onMessageReceived: (message) async {
          await _handleImportedHtml(message.message);
        },
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
      await _controller.runJavaScript(
        ScheduleHtmlExtractor.extractTimetableHtmlScript,
      );
    } catch (error) {
      _finishImportWithMessage('课表提取失败：$error');
    }
  }

  Future<void> _handleImportedHtml(String rawMessage) async {
    try {
      if (rawMessage.startsWith('ERROR:')) {
        throw ScheduleParseException(
          rawMessage.replaceFirst('ERROR:', '').trim(),
        );
      }

      final importedCourses = _parserService.parse(rawMessage);
      await context.read<CourseProvider>().addCourses(importedCourses);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(importedCourses.length);
    } on ScheduleParseException catch (error) {
      _finishImportWithMessage('导入失败：${error.message}');
    } catch (error) {
      _finishImportWithMessage('导入失败：$error');
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
      SnackBar(backgroundColor: Colors.red, content: Text(message)),
    );
  }
}
