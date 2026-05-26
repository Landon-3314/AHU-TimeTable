import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../services/update_download_service.dart';
import '../services/update_check_service.dart';

enum UpdatePromptAction { update, cancel }

Future<UpdatePromptAction?> showUpdatePrompt({
  required BuildContext context,
  required AvailableUpdate update,
  String? title,
  String cancelLabel = '取消',
  String updateLabel = '立即更新',
  String fallbackReleaseNotes = '本次更新包含稳定性改进。',
}) {
  final releaseNotes = update.manifest.releaseNotes.isEmpty
      ? fallbackReleaseNotes
      : update.manifest.releaseNotes;
  return showDialog<UpdatePromptAction>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: Text(title ?? '发现新版本 ${update.manifest.versionName}'),
        content: SingleChildScrollView(
          child: Text(
            releaseNotes,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(UpdatePromptAction.cancel);
                  },
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(UpdatePromptAction.update);
                  },
                  child: Text(updateLabel),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class UpdateDownloadDialog extends StatelessWidget {
  const UpdateDownloadDialog({
    super.key,
    required this.receivedBytes,
    required this.totalBytes,
    required this.message,
  });

  final int receivedBytes;
  final int? totalBytes;
  final String message;

  @override
  Widget build(BuildContext context) {
    final progress = totalBytes == null || totalBytes == 0
        ? null
        : (receivedBytes / totalBytes!).clamp(0.0, 1.0);
    return AlertDialog(
      title: const Text('正在下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

class UpdateDownloadResult {
  const UpdateDownloadResult({this.file, this.error});

  final File? file;
  final Object? error;
}

class UpdateDownloadTaskDialog extends StatefulWidget {
  const UpdateDownloadTaskDialog({
    super.key,
    required this.update,
    this.downloadService = const UpdateDownloadService(),
  });

  final AvailableUpdate update;
  final UpdateDownloadService downloadService;

  @override
  State<UpdateDownloadTaskDialog> createState() =>
      _UpdateDownloadTaskDialogState();
}

class _UpdateDownloadTaskDialogState extends State<UpdateDownloadTaskDialog> {
  int _receivedBytes = 0;
  int? _totalBytes;
  String _message = '准备下载...';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final file = await widget.downloadService.downloadApk(
        widget.update,
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
            _message = _formatProgress(received, total);
          });
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(UpdateDownloadResult(file: file));
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(UpdateDownloadResult(error: error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: UpdateDownloadDialog(
        receivedBytes: _receivedBytes,
        totalBytes: _totalBytes,
        message: _message,
      ),
    );
  }

  static String _formatProgress(int received, int? total) {
    if (total == null || total <= 0) {
      return '已下载 ${_formatBytes(received)}';
    }
    return '已下载 ${_formatBytes(received)} / ${_formatBytes(total)}';
  }

  static String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }
}
