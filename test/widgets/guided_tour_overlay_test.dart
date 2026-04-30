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
}
