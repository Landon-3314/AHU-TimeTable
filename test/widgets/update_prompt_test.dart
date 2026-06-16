import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/update_manifest.dart';
import 'package:AnKe/services/update_check_service.dart';
import 'package:AnKe/widgets/update_prompt.dart';

void main() {
  final testUpdate = AvailableUpdate(
    manifest: UpdateManifest(
      versionName: '0.3.4',
      versionCode: 2,
      releaseNotes: '修复提醒\n优化导入',
      assets: [
        UpdateAsset(
          abi: 'arm64-v8a',
          url: Uri.parse('https://example.com/app.apk'),
          sha256:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          size: 2048,
        ),
      ],
    ),
    asset: UpdateAsset(
      abi: 'arm64-v8a',
      url: Uri.parse('https://example.com/app.apk'),
      sha256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      size: 2048,
    ),
  );

  testWidgets('update prompt returns cancel and update actions', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: _PromptHost(update: testUpdate)));

    await tester.tap(find.text('显示'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 0.3.4'), findsOneWidget);
    expect(find.textContaining('修复提醒'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('稍后更新'), findsNothing);
    expect(find.text('忽略本次'), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('cancel'), findsOneWidget);

    await tester.tap(find.text('显示'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();
    expect(find.text('update'), findsOneWidget);
  });
}

class _PromptHost extends StatefulWidget {
  const _PromptHost({required this.update});

  final AvailableUpdate update;

  @override
  State<_PromptHost> createState() => _PromptHostState();
}

class _PromptHostState extends State<_PromptHost> {
  String? actionName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () async {
                final action = await showUpdatePrompt(
                  context: context,
                  update: widget.update,
                );
                setState(() {
                  actionName = action?.name;
                });
              },
              child: const Text('显示'),
            ),
            if (actionName != null) Text(actionName!),
          ],
        ),
      ),
    );
  }
}
