import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timetable/models/timetable_view_data.dart';
import 'package:timetable/widgets/timetable/timetable_grid.dart';
import 'package:timetable/widgets/timetable/week_selector.dart';

void main() {
  const chips = <TimetableDayChipData>[
    TimetableDayChipData(weekday: 1, label: 'Mon', dateLabel: '4/20'),
    TimetableDayChipData(weekday: 2, label: 'Tue', dateLabel: '4/21'),
    TimetableDayChipData(weekday: 3, label: 'Wed', dateLabel: '4/22'),
    TimetableDayChipData(weekday: 4, label: 'Thu', dateLabel: '4/23'),
    TimetableDayChipData(weekday: 5, label: 'Fri', dateLabel: '4/24'),
    TimetableDayChipData(weekday: 6, label: 'Sat', dateLabel: '4/25'),
    TimetableDayChipData(weekday: 7, label: 'Sun', dateLabel: '4/26'),
  ];

  Widget buildHeader({required int selectedWeekday}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            child: DayWeekHeader(
              summaryLabel: 'Week 1',
              chips: chips,
              selectedWeekday: selectedWeekday,
              onDaySelected: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('scrolls selected weekday chip into view', (tester) async {
    await tester.pumpWidget(buildHeader(selectedWeekday: 1));
    await tester.pumpAndSettle();

    final scrollViewFinder = find.byType(SingleChildScrollView);
    final initialScrollView = tester.widget<SingleChildScrollView>(
      scrollViewFinder,
    );
    final controller = initialScrollView.controller!;
    expect(controller.offset, 0);

    await tester.pumpWidget(buildHeader(selectedWeekday: 7));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));

    final scrollRect = tester.getRect(scrollViewFinder);
    final selectedChipRect = tester.getRect(find.text('Sun'));
    expect(selectedChipRect.left, greaterThanOrEqualTo(scrollRect.left - 0.5));
    expect(selectedChipRect.right, lessThanOrEqualTo(scrollRect.right + 0.5));
  });

  testWidgets('week selector uses grid picker', (tester) async {
    int? selectedWeek;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekSelector(
            currentWeek: 2,
            tooltip: '选择周数',
            options: const [
              TimetableWeekOption(value: 1, label: '第 1 周'),
              TimetableWeekOption(value: 2, label: '第 2 周'),
              TimetableWeekOption(value: 3, label: '第 3 周'),
            ],
            onSelected: (week) => selectedWeek = week,
          ),
        ),
      ),
    );

    await tester.tap(find.text('第 2 周'));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('确定'), findsNothing);
    expect(find.text('第 3 周'), findsOneWidget);

    await tester.tap(find.text('第 3 周'));
    await tester.pumpAndSettle();

    expect(selectedWeek, 3);
    expect(find.byType(GridView), findsNothing);
  });
}
