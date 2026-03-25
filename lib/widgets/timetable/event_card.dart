import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
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
    return Card(
      elevation: 0,
      color: AppColors.warningSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: const BorderSide(color: AppColors.warningBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.warningAccent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      DateFormat('HH:mm').format(event.dateTime),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.warningAccent,
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
      color: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.infoBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxs,
        ),
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
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.divider),
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
