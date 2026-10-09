import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/collections/appointment.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/service_color_palette.dart';
import 'app_surface_card.dart';
import 'app_badge.dart';

class AppointmentTileService {
  const AppointmentTileService({
    required this.name,
    required this.durationMinutes,
    this.colorValue,
  });

  final String name;
  final int durationMinutes;
  final int? colorValue;
}

typedef AppointmentStatusPresentation = AppBadgePresentation;

AppointmentStatusPresentation appointmentStatusPresentation(
  String status,
  ColorScheme colors,
) {
  return switch (status.trim().toLowerCase()) {
    'upcoming' => AppointmentStatusPresentation(
        label: 'Upcoming',
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
    'confirmed' => AppointmentStatusPresentation(
        label: 'Confirmed',
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
      ),
    'ongoing' => AppointmentStatusPresentation(
        label: 'In progress',
        backgroundColor: colors.tertiaryContainer,
        foregroundColor: colors.onTertiaryContainer,
      ),
    'done' => AppointmentStatusPresentation(
        label: 'Completed',
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurface,
      ),
    'cancelled' => AppointmentStatusPresentation(
        label: 'Cancelled',
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      ),
    'no_show' => AppointmentStatusPresentation(
        label: 'No-show',
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      ),
    _ => AppointmentStatusPresentation(
        label: 'Scheduled',
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurfaceVariant,
      ),
  };
}

class AppointmentTile extends StatelessWidget {
  const AppointmentTile({
    super.key,
    required this.appointment,
    required this.customerName,
    required this.services,
    required this.totalDurationMinutes,
    required this.locationName,
    this.onTap,
  });

  final Appointment appointment;
  final String customerName;
  final List<AppointmentTileService> services;
  final int totalDurationMinutes;
  final String locationName;
  final VoidCallback? onTap;

  static final _monthFormat = DateFormat('MMMM');
  static final _dayFormat = DateFormat('d');
  static final _timeFormat = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = appointmentStatusPresentation(appointment.status, colors);
    final resolvedCustomerName =
        customerName.trim().isEmpty ? 'Unnamed customer' : customerName.trim();
    final resolvedLocationName = locationName.trim().isEmpty
        ? 'Location unavailable'
        : locationName.trim();

    return AppSurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppBadge(presentation: status, compact: true),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    resolvedCustomerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      if (services.isNotEmpty) ...[
                        Flexible(
                          child: _ServiceIndicators(services: services),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        '$totalDurationMinutes min',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.location_on_outlined,
                          size: AppSpacing.lg,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          resolvedLocationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              color: colors.outlineVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: AppSpacing.xxxl * 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _monthFormat.format(appointment.startTime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _dayFormat.format(appointment.startTime),
                    style: AppTypography.headlineMedium.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    _timeFormat.format(appointment.startTime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceIndicators extends StatelessWidget {
  const _ServiceIndicators({required this.services});

  final List<AppointmentTileService> services;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < services.length; index++) ...[
          if (index > 0) const SizedBox(width: AppSpacing.xs),
          Semantics(
            label: '${services[index].name} service',
            child: Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(
                // A configured service color is invariant domain identity;
                // unsaved/invalid values fall back to the active theme.
                color: ServiceColorPalette.resolveOrNull(
                      services[index].colorValue,
                    )?.color ??
                    colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
