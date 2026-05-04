import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/providers/home_provider.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  final int appointmentId;

  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final appointment = db.getAppointmentById(appointmentId);

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed('home');
              }
            },
          ),
        ),
        body: const Center(child: Text('Appointment not found')),
      );
    }

    // Fetch related data
    final customer = appointment.customerId != null
        ? db.getCustomerById(appointment.customerId!)
        : null;
    final service = appointment.serviceId != null
        ? db.getServiceById(appointment.serviceId!)
        : null;
    final station = appointment.stationId != null
        ? db.getServiceStationById(appointment.stationId!)
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('home');
            }
          },
        ),
        title: const Text('Appointment Details'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              context.goNamed(
                'booking-edit',
                pathParameters: {'id': appointmentId.toString()},
              );
            },
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('Edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            _StatusBadge(status: appointment.status),
            const SizedBox(height: AppSpacing.lg),

            // Customer Section - Floating Pebble Card
            _PebbleCard(
              icon: Icons.person,
              title: 'Customer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? 'Unknown Customer',
                    style: AppTypography.titleLarge,
                  ),
                  if (customer != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      icon: Icons.phone,
                      text: customer.phoneNumber,
                    ),
                    if (customer.email != null && customer.email!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.email,
                        text: customer.email!,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      onTap: () {
                        context.goNamed(
                          'customer-profile',
                          pathParameters: {'id': customer.id.toString()},
                        );
                      },
                      child: Text(
                        'View Customer Profile',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Service Section - Floating Pebble Card
            _PebbleCard(
              icon: Icons.spa,
              title: 'Service',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service?.title ?? 'No Service Assigned',
                    style: AppTypography.titleLarge,
                  ),
                  if (service != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.schedule,
                            text:
                                '${service.defaultDurationMinutes} minutes',
                          ),
                        ),
                        Expanded(
                          child: _InfoRow(
                            icon: Icons.attach_money,
                            text:
                                '\$${service.cost.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Date & Time Section - Floating Pebble Card
            _PebbleCard(
              icon: Icons.calendar_today,
              title: 'Date & Time',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(appointment.startTime),
                    style: AppTypography.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    DateFormat('h:mm a').format(appointment.startTime),
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      'Duration: ${appointment.endTime.difference(appointment.startTime).inMinutes} minutes',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Station Section - Floating Pebble Card (if station exists)
            if (station != null) ...[
              _PebbleCard(
                icon: Icons.location_on,
                title: 'Station',
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: const Icon(
                        Icons.chair,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      station.name,
                      style: AppTypography.titleLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Notes Section - Floating Pebble Card (if notes exist)
            if (appointment.notes != null &&
                appointment.notes!.isNotEmpty) ...[
              _PebbleCard(
                icon: Icons.notes,
                title: 'Notes',
                child: Text(
                  appointment.notes!,
                  style: AppTypography.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Created/Updated Info
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                'Created ${_formatDate(appointment.createdAt)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays == 1) {
      return 'yesterday at ${DateFormat('h:mm a').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

class _PebbleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _PebbleCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.secondary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, label) = _getStatusStyle(status);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, String) _getStatusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
        return (AppColors.primary, AppColors.primaryContainer.withValues(alpha: 0.2), 'Upcoming');
      case 'confirmed':
        return (AppColors.ongoing, AppColors.ongoing.withValues(alpha: 0.1), 'Confirmed');
      case 'ongoing':
        return (AppColors.ongoing, AppColors.ongoing.withValues(alpha: 0.2), 'Ongoing');
      case 'done':
        return (AppColors.success, AppColors.success.withValues(alpha: 0.1), 'Completed');
      case 'cancelled':
        return (AppColors.error, AppColors.errorContainer, 'Cancelled');
      default:
        return (AppColors.secondary, AppColors.surfaceContainer, status);
    }
  }
}
