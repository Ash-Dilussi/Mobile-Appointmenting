import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/collections/appointment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/appointment_tile.dart';
import '../../../home/presentation/providers/home_provider.dart';

class AppointmentHistoryTile extends ConsumerWidget {
  final Appointment appointment;

  const AppointmentHistoryTile({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayFormat = DateFormat('d');
    final monthFormat = DateFormat('MMM');
    final timeFormat = DateFormat('h:mm a');
    final db = ref.watch(homeHiveProvider);
    final service = appointment.serviceId == null
        ? null
        : db.getServiceById(appointment.serviceId!);

    final status = appointmentStatusPresentation(
      appointment.status == 'completed' ? 'done' : appointment.status,
      Theme.of(context).colorScheme,
    );

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
      title: Align(
        alignment: Alignment.centerLeft,
        child: ServiceBadge(
          label: service?.title ?? 'Appointment',
          colorValue: service?.colorValue,
          compact: true,
        ),
      ),
      subtitle: Text(
        timeFormat.format(appointment.startTime),
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.secondary,
        ),
      ),
      trailing: AppBadge(presentation: status, compact: true),
    );
  }
}
