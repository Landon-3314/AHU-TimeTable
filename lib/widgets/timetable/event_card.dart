import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_theme_tokens.dart';
import '../../models/event.dart';
import '../common/app_ui.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = appThemeTokensOf(context);
    return AppSurface(
      padding: EdgeInsets.zero,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.56),
      borderColor: colorScheme.secondary.withValues(alpha: 0.34),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$markerLabel ${event.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      event.location.isEmpty
                          ? locationPendingLabel
                          : event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                DateFormat('HH:mm').format(event.dateTime),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w800,
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
    final tokens = appThemeTokensOf(context);
    return Card(
      elevation: 0,
      color: tokens.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
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
    final tokens = appThemeTokensOf(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: tokens.divider),
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
