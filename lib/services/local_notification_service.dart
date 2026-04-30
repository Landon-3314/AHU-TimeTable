import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'schedule_plan.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const MethodChannel _timezoneChannel = MethodChannel('app.timezone');
  static const String _logTag = '[NotificationDiag]';
  static const String _scheduledIdsKey = 'notifications.managedScheduledIds.v1';
  static const String _debugScheduledIdsKey =
      'notifications.debugScheduledIds.v1';
  static const String _androidNativeMigrationClearKey =
      'notifications.androidNativeMigrationCleared.v1';
  static const String _channelId = 'timetable_reminders';
  static const String _channelName = '课程与日程提醒';
  static const String _channelDescription = '课前提醒、日程提醒和手动静音提醒';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supportsScheduledNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> initialize() async {
    if (!_supportsScheduledNotifications) {
      _log(
        'initialize skipped: unsupported platform=$defaultTargetPlatform '
        'kIsWeb=$kIsWeb',
      );
      return;
    }
    if (_initialized) {
      _log('initialize skipped: already initialized');
      return;
    }

    _log('initialize start platform=$defaultTargetPlatform');
    await _initializeTimezone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    final initialized = await _plugin.initialize(settings: settings);
    _log('plugin.initialize completed result=$initialized');
    await _ensureAndroidChannel();
    _initialized = true;
    _log('initialize complete timezone=${tz.local.name}');
  }

  Future<void> schedulePlan(
    SchedulePlan plan, {
    required bool useExactAlarms,
  }) async {
    if (!_supportsScheduledNotifications) {
      _log('schedulePlan skipped: unsupported platform=$defaultTargetPlatform');
      return;
    }
    await initialize();
    _log(
      'schedulePlan start notifications=${plan.notifications.length} '
      'useExactAlarms=$useExactAlarms',
    );
    await cancelManagedNotifications();

    final scheduledIds = <int>[];
    var skippedPast = 0;
    var failed = 0;
    for (final notification in plan.notifications) {
      final scheduledDate = tz.TZDateTime.from(
        notification.scheduledAt,
        tz.local,
      );
      if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
        skippedPast++;
        _log(
          'schedulePlan skip past id=${notification.id} '
          'kind=${notification.kind.name} '
          'scheduledAt=${scheduledDate.toIso8601String()}',
        );
        continue;
      }

      final scheduled = await _scheduleNotification(
        notification: notification,
        scheduledDate: scheduledDate,
        useExactAlarms: useExactAlarms,
      );
      if (scheduled) {
        scheduledIds.add(notification.id);
      } else {
        failed++;
      }
    }

    await _writeScheduledIds(scheduledIds);
    _log(
      'schedulePlan complete scheduled=${scheduledIds.length} '
      'failed=$failed skippedPast=$skippedPast',
    );
    await logPendingNotificationRequests(reason: 'schedulePlan');
  }

  Future<void> cancelManagedNotifications() async {
    if (!_supportsScheduledNotifications) {
      _log('cancelManagedNotifications skipped: unsupported platform');
      return;
    }
    await initialize();
    final ids = await _readScheduledIds();
    _log('cancelManagedNotifications start count=${ids.length} ids=$ids');
    for (final id in ids) {
      await _plugin.cancel(id: id);
      _log('cancelManagedNotifications cancelled id=$id');
    }
    await _writeScheduledIds(const <int>[]);
    await logPendingNotificationRequests(reason: 'cancelManagedNotifications');
  }

  Future<void> cancelAndroidPluginSchedulesForNativeMigration() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        !_supportsScheduledNotifications) {
      return;
    }
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final alreadyCleared =
        prefs.getBool(_androidNativeMigrationClearKey) ?? false;
    if (alreadyCleared) {
      await cancelManagedNotifications();
      return;
    }

    _log('android native migration: cancel all plugin notifications once');
    await _plugin.cancelAll();
    await _writeScheduledIds(const <int>[]);
    await _writeScheduledIds(const <int>[], key: _debugScheduledIdsKey);
    await prefs.setBool(_androidNativeMigrationClearKey, true);
    await logPendingNotificationRequests(reason: 'androidNativeMigration');
  }

  Future<bool> scheduleDebugNotification({
    required ManagedNotificationKind kind,
    required Duration delay,
    required String title,
    required String body,
    required bool useExactAlarms,
  }) async {
    if (!_supportsScheduledNotifications) {
      _log('scheduleDebugNotification skipped: unsupported platform');
      return false;
    }
    await initialize();
    final now = DateTime.now();
    final id = 0x20000000 + (now.millisecondsSinceEpoch & 0x0fffffff);
    final notification = ManagedNotification(
      id: id,
      kind: kind,
      scheduledAt: now.add(delay),
      title: title,
      body: body,
    );
    _log(
      'scheduleDebugNotification start id=$id kind=${kind.name} '
      'delay=${delay.inSeconds}s '
      'scheduledAt=${notification.scheduledAt.toIso8601String()} '
      'useExactAlarms=$useExactAlarms title="$title"',
    );
    final scheduled = await _scheduleNotification(
      notification: notification,
      scheduledDate: tz.TZDateTime.from(notification.scheduledAt, tz.local),
      useExactAlarms: useExactAlarms,
    );
    if (!scheduled) {
      _log('scheduleDebugNotification failed id=$id kind=${kind.name}');
      await logPendingNotificationRequests(reason: 'debugScheduleFailed');
      return false;
    }
    final ids = await _readScheduledIds(key: _debugScheduledIdsKey);
    await _writeScheduledIds([...ids, id], key: _debugScheduledIdsKey);
    _log('scheduleDebugNotification complete id=$id debugIds=${[...ids, id]}');
    await logPendingNotificationRequests(reason: 'scheduleDebugNotification');
    return true;
  }

  Future<void> cancelDebugNotifications() async {
    if (!_supportsScheduledNotifications) {
      _log('cancelDebugNotifications skipped: unsupported platform');
      return;
    }
    await initialize();
    final ids = await _readScheduledIds(key: _debugScheduledIdsKey);
    _log('cancelDebugNotifications start count=${ids.length} ids=$ids');
    for (final id in ids) {
      await _plugin.cancel(id: id);
      _log('cancelDebugNotifications cancelled id=$id');
    }
    await _writeScheduledIds(const <int>[], key: _debugScheduledIdsKey);
    await logPendingNotificationRequests(reason: 'cancelDebugNotifications');
  }

  Future<void> logPendingNotificationRequests({required String reason}) async {
    if (!_supportsScheduledNotifications) {
      _log('pending dump skipped: unsupported platform reason=$reason');
      return;
    }
    await initialize();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      _log('pending dump reason=$reason count=${pending.length}');
      for (final request in pending) {
        _log(
          'pending id=${request.id} title="${request.title}" '
          'body="${request.body}" payload="${request.payload}"',
        );
      }
    } catch (e) {
      _log('pending dump failed reason=$reason error=$e');
    }
  }

  Future<bool> _scheduleNotification({
    required ManagedNotification notification,
    required tz.TZDateTime scheduledDate,
    required bool useExactAlarms,
  }) async {
    final preferredMode = useExactAlarms
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      _log(
        'zonedSchedule attempt id=${notification.id} '
        'kind=${notification.kind.name} mode=${preferredMode.name} '
        'scheduledDate=${scheduledDate.toIso8601String()} '
        'now=${tz.TZDateTime.now(tz.local).toIso8601String()} '
        'timezone=${tz.local.name}',
      );
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: scheduledDate,
        notificationDetails: _detailsFor(notification.kind),
        androidScheduleMode: preferredMode,
        payload: notification.kind.name,
      );
      _log(
        'zonedSchedule success id=${notification.id} '
        'kind=${notification.kind.name} mode=${preferredMode.name}',
      );
      return true;
    } on PlatformException catch (e) {
      if (useExactAlarms) {
        _log(
          'exact zonedSchedule failed, retry inexact '
          'id=${notification.id} code=${e.code} message=${e.message}',
        );
        try {
          await _plugin.zonedSchedule(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            scheduledDate: scheduledDate,
            notificationDetails: _detailsFor(notification.kind),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: notification.kind.name,
          );
          _log(
            'zonedSchedule success after inexact retry '
            'id=${notification.id} kind=${notification.kind.name}',
          );
          return true;
        } on PlatformException catch (retryError) {
          _log(
            'inexact retry platform failure id=${notification.id} '
            'code=${retryError.code} message=${retryError.message} '
            'details=${retryError.details}',
          );
          return false;
        } catch (retryError) {
          _log(
            'inexact retry unexpected failure id=${notification.id} '
            'error=$retryError',
          );
          return false;
        }
      }
      _log(
        'zonedSchedule platform failure id=${notification.id} '
        'code=${e.code} message=${e.message} details=${e.details}',
      );
      return false;
    } catch (e) {
      _log('zonedSchedule unexpected failure id=${notification.id} error=$e');
      return false;
    }
  }

  NotificationDetails _detailsFor(ManagedNotificationKind kind) {
    final title = switch (kind) {
      ManagedNotificationKind.manualMute => '上课手动静音提醒',
      _ => _channelName,
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        title,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> _ensureAndroidChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _log('ensureAndroidChannel skipped: platform=$defaultTargetPlatform');
      return;
    }
    _log('ensureAndroidChannel start id=$_channelId name="$_channelName"');
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
    _log('ensureAndroidChannel complete id=$_channelId');
  }

  Future<void> _initializeTimezone() async {
    _log('timezone initialize start');
    tz_data.initializeTimeZones();
    try {
      final name = await _timezoneChannel.invokeMethod<String>(
        'getLocalTimezone',
      );
      _log('timezone native result="$name"');
      if (name != null && name.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(name));
      }
    } catch (e) {
      _log('timezone fallback to default local error=$e');
    }
    _log('timezone initialize complete local=${tz.local.name}');
  }

  Future<List<int>> _readScheduledIds({String key = _scheduledIdsKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      _log('read ids key=$key empty');
      return const <int>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final ids = decoded.whereType<int>().toList(growable: false);
        _log('read ids key=$key ids=$ids');
        return ids;
      }
    } catch (e) {
      // Ignore corrupted bookkeeping and overwrite it after the next sync.
      _log('read ids key=$key corrupted raw="$raw" error=$e');
    }
    return const <int>[];
  }

  Future<void> _writeScheduledIds(
    List<int> ids, {
    String key = _scheduledIdsKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(ids));
    _log('write ids key=$key ids=$ids');
  }

  static void _log(String message) {
    debugPrint('$_logTag ${DateTime.now().toIso8601String()} $message');
  }
}
