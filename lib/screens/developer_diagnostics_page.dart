import 'package:flutter/material.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

import '../services/native_alarm_service.dart';
import '../widgets/long_screenshot_scroll_capture.dart';

class DeveloperDiagnosticsPage extends StatefulWidget {
  const DeveloperDiagnosticsPage({super.key});

  @override
  State<DeveloperDiagnosticsPage> createState() =>
      _DeveloperDiagnosticsPageState();
}

class _DeveloperDiagnosticsPageState extends State<DeveloperDiagnosticsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者诊断')),
      body: LongScreenshotScrollCapture(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _simulateMute(context),
                      icon: const Icon(Icons.volume_off_outlined),
                      label: const Text('模拟上课静音'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _simulateUnmute(context),
                      icon: const Icon(Icons.volume_up_outlined),
                      label: const Text('模拟下课取消静音'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () => _runOneMinuteSelfTest(context),
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('执行 1 分钟后静音测试'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simulateMute(BuildContext context) async {
    await SoundMode.setSoundMode(RingerModeStatus.silent);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已调用 sound_mode 静音')));
  }

  Future<void> _simulateUnmute(BuildContext context) async {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已调用 sound_mode 恢复响铃')));
  }

  Future<void> _runOneMinuteSelfTest(BuildContext context) async {
    await NativeAlarmService.instance.runOneMinuteMuteTest();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('测试闹钟已写入原生层，请息屏等待 1 分钟观察')));
  }
}
