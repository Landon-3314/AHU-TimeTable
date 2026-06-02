import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/widgets/common/guided_tour_overlay.dart';

void main() {
  testWidgets('advances through steps and completes on final confirmation', (
    tester,
  ) async {
    final firstTargetKey = GlobalKey();
    final secondTargetKey = GlobalKey();
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 24,
                top: 24,
                child: SizedBox(
                  key: firstTargetKey,
                  width: 64,
                  height: 48,
                  child: const Placeholder(),
                ),
              ),
              Positioned(
                right: 24,
                bottom: 24,
                child: SizedBox(
                  key: secondTargetKey,
                  width: 64,
                  height: 48,
                  child: const Placeholder(),
                ),
              ),
              GuidedTourOverlay(
                steps: [
                  GuidedTourStep(
                    targetKey: firstTargetKey,
                    title: 'First target',
                    body: 'First target body',
                  ),
                  GuidedTourStep(
                    targetKey: secondTargetKey,
                    title: 'Second target',
                    body: 'Second target body',
                  ),
                ],
                nextLabel: 'Next',
                doneLabel: 'Done',
                stepLabelBuilder: (current, total) => '$current/$total',
                onCompleted: () {
                  completed = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('First target'), findsOneWidget);
    expect(find.text('Second target'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('First target'), findsNothing);
    expect(find.text('Second target'), findsOneWidget);
    expect(completed, isFalse);

    await tester.tap(find.text('Done'));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('blocks underlying semantics while keeping tour action visible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final targetKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Semantics(
                label: 'Underlying timetable content',
                child: SizedBox(
                  key: targetKey,
                  width: 64,
                  height: 48,
                  child: const Placeholder(),
                ),
              ),
              GuidedTourOverlay(
                steps: [
                  GuidedTourStep(
                    targetKey: targetKey,
                    title: 'Tour title',
                    body: 'Tour body',
                  ),
                ],
                nextLabel: 'Next',
                doneLabel: 'Done',
                stepLabelBuilder: (current, total) => '$current/$total',
                onCompleted: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Underlying timetable content'), findsNothing);
    expect(find.bySemanticsLabel('Done'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('dialog barrier and current step expose Chinese semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final targetKey = GlobalKey();
    late BuildContext hostContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return SizedBox(
                key: targetKey,
                width: 64,
                height: 48,
                child: const Placeholder(),
              );
            },
          ),
        ),
      ),
    );

    unawaited(
      showGuidedTourOverlay(
        context: hostContext,
        steps: [
          GuidedTourStep(
            targetKey: targetKey,
            title: '选择周次',
            body: '在这里跳转到目标周次。',
          ),
          GuidedTourStep(
            targetKey: targetKey,
            title: '返回今天',
            body: '快速定位当前日期。',
          ),
        ],
        nextLabel: '下一步',
        doneLabel: '完成',
        stepLabelBuilder: (current, total) => '第 $current 步，共 $total 步',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('功能引导'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('第 1 步，共 2 步')), findsWidgets);

    semantics.dispose();
  });
}
