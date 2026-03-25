import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.markerLabel,
    required this.locationPendingLabel,
    required this.onTap,
  });

  final Event event;
  final String markerLabel;
  final String locationPendingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFF59E0B);

    return Card(
      elevation: 0,
      color: const Color(0xFFFFFBEB),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFFCD34D)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$markerLabel ${event.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.location.isEmpty
                          ? locationPendingLabel
                          : event.location,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('HH:mm').format(event.dateTime),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompactEventCard extends StatelessWidget {
  const CompactEventCard({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF4F7FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFBFD0FF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: const Icon(Icons.event_available_outlined),
        title: Text(event.name),
        subtitle: Text(
          '${DateFormat('HH:mm').format(event.dateTime)}'
          '${event.location.isEmpty ? '' : ' / ${event.location}'}',
        ),
        onTap: onTap,
      ),
    );
  }
}

class HolidayEventCard extends StatelessWidget {
  const HolidayEventCard({super.key, required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: const Icon(Icons.event_note_outlined),
        title: Text(event.name),
        subtitle: Text(
          '${DateFormat('MM-dd').format(event.dateTime)} '
          '${DateFormat('HH:mm').format(event.dateTime)}'
          '${event.location.isEmpty ? '' : ' / ${event.location}'}',
        ),
        onTap: onTap,
      ),
    );
  }
}
