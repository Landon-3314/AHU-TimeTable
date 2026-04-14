import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../models/event.dart';
import '../../models/timetable_view_data.dart';
import '../long_screenshot_scroll_capture.dart';
import 'event_card.dart';
import 'timetable_grid.dart';

class HolidayListView extends StatefulWidget {
  const HolidayListView({
    super.key,
    required this.pageData,
    required this.onEventTap,
  });

  final TimetableHolidayPageData pageData;
  final ValueChanged<Event> onEventTap;

  @override
  State<HolidayListView> createState() => _HolidayListViewState();
}

class _HolidayListViewState extends State<HolidayListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageData.isEmpty) {
      return EmptyScheduleState(
        title: widget.pageData.emptyTitle,
        subtitle: widget.pageData.emptySubtitle,
      );
    }

    return LongScreenshotScrollCapture(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: AppSpacing.listPagePadding,
        itemCount: widget.pageData.events.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: ScheduleHeaderCard(
                title: widget.pageData.title,
                subtitle: widget.pageData.subtitle,
              ),
            );
          }

          final event = widget.pageData.events[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: HolidayEventCard(
              event: event,
              onTap: () => widget.onEventTap(event),
            ),
          );
        },
      ),
    );
  }
}
