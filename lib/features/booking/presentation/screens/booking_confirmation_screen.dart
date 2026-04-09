import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/providers/home_provider.dart';

class BookingConfirmationScreen extends ConsumerWidget {
  final int appointmentId;

  const BookingConfirmationScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final appointment = db.getAppointmentById(appointmentId);

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 60,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Appointment Booked!',
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'Your appointment has been successfully scheduled.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Appointment Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
                child: Column(
                  children: [
                    // Date & Time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date & Time',
                              style: AppTypography.labelSmall,
                            ),
                            Text(
                              '${DateFormat('EEEE, MMMM d').format(appointment.startTime)} at ${DateFormat('h:mm a').format(appointment.startTime)}',
                              style: AppTypography.bodyLarge,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Divider(color: AppColors.outline.withValues(alpha: 0.1)),
                    const SizedBox(height: AppSpacing.lg),

                    // Duration
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: AppTypography.labelSmall,
                            ),
                            Text(
                              '${appointment.endTime.difference(appointment.startTime).inMinutes} minutes',
                              style: AppTypography.bodyLarge,
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Divider(color: AppColors.outline.withValues(alpha: 0.1)),
                    const SizedBox(height: AppSpacing.lg),

                    // Status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: const Icon(
                            Icons.pending,
                            color: AppColors.warning,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: AppTypography.labelSmall,
                            ),
                            Text(
                              appointment.status.toUpperCase(),
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.goNamed('home');
                      },
                      child: const Text('Go to Home'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        context.goNamed('calendar');
                      },
                      child: const Text('View Calendar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
