import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

class DeveloperDiagnosticsPage extends StatelessWidget {
  const DeveloperDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开发者诊断')),
      body: ListView(
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
    );
  }

  Future<void> _simulateMute(BuildContext context) async {
    await SoundMode.setSoundMode(RingerModeStatus.silent);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已触发 sound_mode 静音')),
    );
  }

  Future<void> _simulateUnmute(BuildContext context) async {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已触发 sound_mode 恢复')),
    );
  }

  Future<void> _runOneMinuteSelfTest(BuildContext context) async {
    FlutterBackgroundService().invoke('test_1_min_mute');
    debugPrint('[DND Debug - UI] 已向后台服务发送 1 分钟测试指令');
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('测试指令已发送到后台服务，请息屏等待1分钟观察')),
    );
  }
}
