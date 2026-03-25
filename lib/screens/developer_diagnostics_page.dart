import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/event.dart';
import '../services/notification/immediate_reminder_notifier.dart';
import '../services/notification/notification_channel_registrar.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class DeveloperDiagnosticsPage extends StatefulWidget {
  const DeveloperDiagnosticsPage({super.key});

  @override
  State<DeveloperDiagnosticsPage> createState() =>
      _DeveloperDiagnosticsPageState();
}

class _DeveloperDiagnosticsPageState extends State<DeveloperDiagnosticsPage> {
  static const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DiagnosticsActionTile(
            title: 'Foreground notification test',
            subtitle: 'Send a local Event notification through the notifier.',
            onTap: _isBusy ? null : _runForegroundNotificationTest,
          ),
          _DiagnosticsActionTile(
            title: 'Background IPC test - mute',
            subtitle: 'Invoke test_mute on the background service.',
            onTap: _isBusy ? null : _invokeBackgroundCommandMute,
          ),
          _DiagnosticsActionTile(
            title: 'Background IPC test - unmute',
            subtitle: 'Invoke test_unmute on the background service.',
            onTap: _isBusy ? null : _invokeBackgroundCommandUnmute,
          ),
          _DiagnosticsActionTile(
            title: 'Storage read test',
            subtitle: 'Read all stored Event rows and print them as JSON.',
            onTap: _isBusy ? null : _showStoredEvents,
          ),
        ],
      ),
    );
  }

  Future<void> _runForegroundNotificationTest() async {
    await _runBusyAction(() async {
      final permissionStatus = await NotificationService.instance
          .ensurePermissions();
      final notifier = await _createImmediateNotifier();
      final event = Event(
        id: 'dev-diagnostics-event',
        name: 'Developer diagnostics notification',
        location: 'ImmediateReminderNotifier',
        dateTime: DateTime.now().add(const Duration(minutes: 1)),
        enableAlarm: true,
      );
      await notifier.showEventReminder(event: event, notificationId: 900001);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            permissionStatus.notificationsGranted
                ? 'Test notification dispatched.'
                : 'Notification permission is not granted yet.',
          ),
        ),
      );
    });
  }

  Future<void> _invokeBackgroundCommandMute() async {
    await _runBusyAction(() async {
      await _invokeBackgroundCommand(command: 'test_mute');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent test_mute to background service.')),
      );
    });
  }

  Future<void> _invokeBackgroundCommandUnmute() async {
    await _runBusyAction(() async {
      await _invokeBackgroundCommand(command: 'test_unmute');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sent test_unmute to background service.'),
        ),
      );
    });
  }

  Future<void> _invokeBackgroundCommand({required String command}) async {
    final service = FlutterBackgroundService();
    service.invoke(command);
  }

  Future<void> _showStoredEvents() async {
    await _runBusyAction(() async {
      final storageService = await StorageService.create();
      final events = storageService.loadEvents();
      final payload = events.map((event) => event.toJson()).toList();
      await _showTextDialog(
        title: 'Stored Event rows',
        content: payload.isEmpty ? '[]' : _prettyJson.convert(payload),
      );
    });
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      await action();
    } catch (error, stackTrace) {
      await _showTextDialog(
        title: 'Diagnostics action failed',
        content: '$error\n\n$stackTrace',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<ImmediateReminderNotifier> _createImmediateNotifier() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(settings: initializationSettings);
    await NotificationChannelRegistrar(plugin).registerChannels();
    return ImmediateReminderNotifier(plugin);
  }

  Future<void> _showTextDialog({
    required String title,
    required String content,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosticsActionTile extends StatelessWidget {
  const _DiagnosticsActionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
