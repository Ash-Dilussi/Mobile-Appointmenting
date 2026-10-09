import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../widgets/appointment_note_card.dart';

class BookingConfirmationScreen extends ConsumerWidget {
  final int appointmentId;

  const BookingConfirmationScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final db = ref.watch(homeHiveProvider);
    final appointment = db.getAppointmentById(appointmentId);

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: colors.onTertiaryContainer,
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
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Appointment Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
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
                            color: colors.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: colors.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
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
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: AppSpacing.lg),

                    // Duration
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: colors.onPrimaryContainer,
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
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: AppSpacing.lg),

                    // Status
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            Icons.pending,
                            color: colors.onSecondaryContainer,
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
                                color: colors.onSurface,
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

              if (appointment.notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text('Notes', style: AppTypography.titleMedium),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          '${appointment.notes.length}',
                          style: AppTypography.labelSmall.copyWith(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var index = 0;
                    index < appointment.notes.length;
                    index++) ...[
                  AppointmentNoteCard(note: appointment.notes[index]),
                  if (index < appointment.notes.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
              ],

              const SizedBox(height: AppSpacing.xxxl),

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
