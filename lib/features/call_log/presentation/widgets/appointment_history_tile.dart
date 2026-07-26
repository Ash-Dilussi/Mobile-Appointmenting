import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/collections/appointment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class AppointmentHistoryTile extends StatelessWidget {
  final Appointment appointment;

  const AppointmentHistoryTile({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final dayFormat = DateFormat('d');
    final monthFormat = DateFormat('MMM');
    final yearFormat = DateFormat('yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Determine status styling
    Color statusColor;
    String statusText;
    switch (appointment.status.toLowerCase()) {
      case 'completed':
      case 'done':
        statusColor = AppColors.success;
        statusText = 'Completed';
        break;
      case 'upcoming':
      case 'confirmed':
        statusColor = AppColors.primary;
        statusText = 'Upcoming';
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        statusText = 'Cancelled';
        break;
      case 'ongoing':
        statusColor = AppColors.ongoing;
        statusText = 'Ongoing';
        break;
      default:
        statusColor = AppColors.secondary;
        statusText = appointment.status;
    }

    return ListTile(
      onTap: () {
        context.pushNamed(
          'appointment-detail',
          pathParameters: {'id': appointment.id.toString()},
        );
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 48,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dayFormat.format(appointment.startTime),
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              monthFormat.format(appointment.startTime).toUpperCase(),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      title: Text(
        _getServiceName(appointment),
        style: AppTypography.bodyMedium.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        '${timeFormat.format(appointment.startTime)}',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.secondary,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          statusText,
          style: AppTypography.bodySmall.copyWith(
            color: statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getServiceName(Appointment appointment) {
    // If there's a service associated, return its name
    // Otherwise return a generic label
    if (appointment.serviceId != null) {
      return 'Service #${appointment.serviceId}';
    }
    return 'Appointment';
  }
}
