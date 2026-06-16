import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/core/app_colors.dart';
import 'package:AnKe/core/app_theme.dart';
import 'package:AnKe/widgets/common/capsule_multi_select.dart';

void main() {
  Widget buildHarness({
    required Set<int> initialSelection,
    required ValueChanged<Set<int>> onChanged,
    bool enableDragSelect = false,
    bool singleLine = false,
    ThemeData? theme,
    double? width,
  }) {
    var selected = {...initialSelection};
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: StatefulBuilder(
              builder: (context, setState) {
                return CapsuleMultiSelect<int>(
                  options: const [
                    CapsuleMultiSelectOption(value: 1, label: 'Week 1'),
                    CapsuleMultiSelectOption(value: 2, label: 'Week 2'),
                    CapsuleMultiSelectOption(value: 3, label: 'Week 3'),
                    CapsuleMultiSelectOption(value: 4, label: 'Week 4'),
                  ],
                  selectedValues: selected,
                  enableDragSelect: enableDragSelect,
                  singleLine: singleLine,
                  onChanged: (next) {
                    setState(() {
                      selected = next;
                    });
                    onChanged(next);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders selected capsules without checkbox or check icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(initialSelection: {1}, onChanged: (_) {}),
    );

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.done), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('toggles a capsule by tapping it', (tester) async {
    Set<int> latest = {1};

    await tester.pumpWidget(
      buildHarness(
        initialSelection: latest,
        onChanged: (next) {
          latest = next;
        },
      ),
    );

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();

    expect(latest, {1, 2});

    await tester.tap(find.text('Week 1'));
    await tester.pumpAndSettle();

    expect(latest, {2});
  });

  testWidgets('singleLine renders capsules in a horizontal scroll view', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        initialSelection: {1},
        singleLine: true,
        onChanged: (_) {},
        width: 120,
      ),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );

    expect(scrollView.scrollDirection, Axis.horizontal);
    expect(find.byType(Row), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('uses theme colors for selected capsule styling', (tester) async {
    final theme = AppTheme.light(
      palette: AppThemePalette.custom(
        primaryValue: 0xFF6D28D9,
        accentValue: 0xFF0EA5E9,
      ),
    );

    await tester.pumpWidget(
      buildHarness(initialSelection: {1}, onChanged: (_) {}, theme: theme),
    );

    final selectedContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('capsule_multi_select_1')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = selectedContainer.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final selectedText = tester.widget<Text>(find.text('Week 1'));

    expect(decoration.color, theme.colorScheme.primaryContainer);
    expect(border.top.color, theme.colorScheme.primary);
    expect(selectedText.style?.color, theme.colorScheme.secondary);
  });

  testWidgets('selecting a capsule keeps chip size and position stable', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(initialSelection: const {}, onChanged: (_) {}),
    );

    final chipTwoFinder = find.byKey(
      const ValueKey<String>('capsule_multi_select_2'),
    );
    final chipThreeFinder = find.byKey(
      const ValueKey<String>('capsule_multi_select_3'),
    );
    final chipTwoRectBefore = tester.getRect(chipTwoFinder);
    final chipThreeRectBefore = tester.getRect(chipThreeFinder);

    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();

    expect(tester.getRect(chipTwoFinder), chipTwoRectBefore);
    expect(tester.getRect(chipThreeFinder), chipThreeRectBefore);
  });

  testWidgets(
    'dragging from an unselected capsule selects every touched item',
    (tester) async {
      Set<int> latest = {};

      await tester.pumpWidget(
        buildHarness(
          initialSelection: latest,
          enableDragSelect: true,
          onChanged: (next) {
            latest = next;
          },
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Week 1')),
      );
      await gesture.moveTo(tester.getCenter(find.text('Week 2')));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Week 3')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(latest, {1, 2, 3});
    },
  );

  testWidgets('dragging from a selected capsule deselects every touched item', (
    tester,
  ) async {
    Set<int> latest = {1, 2, 3};

    await tester.pumpWidget(
      buildHarness(
        initialSelection: latest,
        enableDragSelect: true,
        onChanged: (next) {
          latest = next;
        },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Week 1')),
    );
    await gesture.moveTo(tester.getCenter(find.text('Week 2')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Week 3')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(latest, isEmpty);
  });

  testWidgets('drag selection works across wrapped rows', (tester) async {
    Set<int> latest = {};

    await tester.pumpWidget(
      buildHarness(
        initialSelection: latest,
        enableDragSelect: true,
        width: 150,
        onChanged: (next) {
          latest = next;
        },
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Week 1')),
    );
    await gesture.moveTo(tester.getCenter(find.text('Week 2')));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Week 3')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(latest, {1, 2, 3});
  });

  testWidgets('does not apply the same dragged capsule more than once', (
    tester,
  ) async {
    Set<int> latest = {1, 2};

    await tester.pumpWidget(
      buildHarness(
        initialSelection: latest,
        enableDragSelect: true,
        onChanged: (next) {
          latest = next;
        },
      ),
    );

    final weekTwoCenter = tester.getCenter(find.text('Week 2'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Week 1')),
    );
    await gesture.moveTo(weekTwoCenter);
    await tester.pump();
    await gesture.moveTo(weekTwoCenter + const Offset(1, 0));
    await tester.pump();
    await gesture.moveTo(weekTwoCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(latest, isEmpty);
  });
}
