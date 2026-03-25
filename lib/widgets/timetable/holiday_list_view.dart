import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../models/event.dart';
import '../../models/timetable_view_data.dart';
import 'event_card.dart';
import 'timetable_grid.dart';

class HolidayListView extends StatelessWidget {
  const HolidayListView({
    super.key,
    required this.pageData,
    required this.onEventTap,
  });

  final TimetableHolidayPageData pageData;
  final ValueChanged<Event> onEventTap;

  @override
  Widget build(BuildContext context) {
    if (pageData.isEmpty) {
      return EmptyScheduleState(
        title: pageData.emptyTitle,
        subtitle: pageData.emptySubtitle,
      );
    }

    return ListView.builder(
      padding: AppSpacing.listPagePadding,
      itemCount: pageData.events.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: ScheduleHeaderCard(
              title: pageData.title,
              subtitle: pageData.subtitle,
            ),
          );
        }

        final event = pageData.events[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: HolidayEventCard(event: event, onTap: () => onEventTap(event)),
        );
      },
    );
  }
}
