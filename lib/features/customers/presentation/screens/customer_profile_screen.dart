import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../home/presentation/providers/home_provider.dart';

class CustomerProfileScreen extends ConsumerWidget {
  final int customerId;

  const CustomerProfileScreen({
    super.key,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final customer = db.getCustomerById(customerId);

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Customer not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('customers'),
        ),
        title: const Text('Customer Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit customer
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Header
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
                    child: Center(
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : '?',
                        style: AppTypography.displaySmall.copyWith(
                          color: AppColors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    customer.name,
                    style: AppTypography.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Customer since ${DateFormat('MMM yyyy').format(customer.createdAt)}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Contact Info Card
            _SectionCard(
              title: 'Contact Information',
              children: [
                _InfoRow(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: customer.phoneNumber,
                ),
                if (customer.email != null && customer.email!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: customer.email!,
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Notes Card
            if (customer.notes != null && customer.notes!.isNotEmpty)
              _SectionCard(
                title: 'Notes',
                children: [
                  Text(
                    customer.notes!,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),

            const SizedBox(height: AppSpacing.lg),

            // Appointment History
            Text(
              'Appointment History',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),

            // TODO: Add appointment history list

            const SizedBox(height: AppSpacing.xxl),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.goNamed(
                        'booking',
                        queryParameters: {'phone': customer.phoneNumber},
                      );
                    },
                    icon: const Icon(Icons.event),
                    label: const Text('Book Appointment'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      // TODO: Call customer
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
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
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall,
              ),
              Text(
                value,
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
