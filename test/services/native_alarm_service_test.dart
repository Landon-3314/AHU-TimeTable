import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/services/native_alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.timetable/native_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('timed mute test parses native restore alarm failure', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'runTimedMuteTest');
      return {'success': false, 'reason': 'restore_alarm_schedule_failed'};
    });

    final result = await NativeAlarmService.instance.runTimedMuteTest(
      muteAfterSeconds: 30,
      restoreAfterSeconds: 60,
    );

    expect(result.success, isFalse);
    expect(result.reason, 'restore_alarm_schedule_failed');
    expect(result.failureMessage, '恢复闹钟写入失败，请查看控制台 MuteDiag 日志');
  });

  test('timed mute test rejects malformed native response', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    final result = await NativeAlarmService.instance.runTimedMuteTest(
      muteAfterSeconds: 30,
      restoreAfterSeconds: 60,
    );

    expect(result.success, isFalse);
    expect(result.reason, 'invalid_native_response');
  });

  test('timed mute test maps platform exception to generic failure', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'schedule_failed');
    });

    final result = await NativeAlarmService.instance.runTimedMuteTest(
      muteAfterSeconds: 30,
      restoreAfterSeconds: 60,
    );

    expect(result.success, isFalse);
    expect(result.reason, 'platform_exception');
    expect(result.failureMessage, '诊断静音闹钟写入失败，请查看控制台 MuteDiag 日志');
  });
}
