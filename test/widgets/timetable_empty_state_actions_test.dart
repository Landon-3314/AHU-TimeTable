import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:AnKe/models/timetable_view_data.dart';
import 'package:AnKe/widgets/timetable/course_overview_panel.dart';
import 'package:AnKe/widgets/timetable/holiday_list_view.dart';
import 'package:AnKe/widgets/timetable/timetable_grid.dart';

void main() {
  testWidgets('empty week view renders the supplied action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TimetableGrid(
          pageData: const TimetableWeekPageData(
            week: 1,
            title: 'Week 1',
            subtitle: '',
            sections: [
              TimetableWeekSectionData(
                title: 'Monday',
                items: [],
                emptyText: 'Empty',
              ),
            ],
          ),
          onCourseTap: (_) {},
          onEventTap: (_) {},
          coursePeriodTextBuilder: (_) => '',
          emptyAction: const Text('Week action'),
        ),
      ),
    );

    expect(find.text('Week action'), findsOneWidget);
  });

  testWidgets('empty holiday view renders the supplied action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HolidayListView(
          pageData: const TimetableHolidayPageData(
            title: 'Holiday',
            subtitle: '',
            emptyTitle: 'No events',
            emptySubtitle: '',
            events: [],
          ),
          onEventTap: (_) {},
          emptyAction: const Text('Holiday action'),
        ),
      ),
    );

    expect(find.text('Holiday action'), findsOneWidget);
  });

  testWidgets('empty overview renders the supplied action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CourseOverviewPanel(
          courseGroups: const [],
          groupCountLabelBuilder: (_) => '',
          onCourseGroupTap: (_) {},
          emptyAction: const Text('Overview action'),
        ),
      ),
    );

    expect(find.text('Overview action'), findsOneWidget);
  });
}
