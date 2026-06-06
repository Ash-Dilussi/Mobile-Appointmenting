import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/providers/home_provider.dart';

class ServiceDetailScreen extends ConsumerWidget {
  final int serviceId;

  const ServiceDetailScreen({
    super.key,
    required this.serviceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final service = db.getServiceById(serviceId);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    if (service == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.goNamed('service-management'),
          ),
        ),
        body: const Center(child: Text('Service not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('service-management'),
        ),
        title: const Text('Service Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              context.goNamed(
                'edit-service',
                pathParameters: {'id': serviceId.toString()},
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.miscellaneous_services,
                        size: 36,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    service.title,
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: service.isActive == false
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      service.isActive == false ? 'Inactive' : 'Active',
                      style: AppTypography.labelSmall.copyWith(
                        color: service.isActive == false
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Details Card
            _SectionCard(
              title: 'Details',
              children: [
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Duration',
                  value: '${service.defaultDurationMinutes} minutes',
                ),
                _InfoRow(
                  icon: Icons.attach_money,
                  label: 'Cost',
                  value: currencyFormat.format(service.cost),
                ),
                if (service.description != null &&
                    service.description!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.notes,
                    label: 'Description',
                    value: service.description!,
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Created/Updated Info
            _SectionCard(
              title: 'Record Info',
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Created',
                  value: DateFormat('MMM d, yyyy').format(service.createdAt),
                ),
                _InfoRow(
                  icon: Icons.update,
                  label: 'Last Updated',
                  value: DateFormat('MMM d, yyyy').format(service.updatedAt),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.goNamed('booking');
                    },
                    icon: const Icon(Icons.event),
                    label: const Text('Book Appointment'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      context.goNamed(
                        'edit-service',
                        pathParameters: {'id': serviceId.toString()},
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}