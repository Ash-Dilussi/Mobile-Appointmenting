import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/service_color_palette.dart';
import '../../../home/presentation/providers/home_provider.dart';

class ServiceDetailScreen extends ConsumerWidget {
  final int serviceId;

  const ServiceDetailScreen({
    super.key,
    required this.serviceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
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

    final savedColor = ServiceColorPalette.resolveOrNull(service.colorValue);
    // Curated service colors intentionally keep each service's domain identity
    // across institution presets. Missing/unknown legacy values use the active
    // institution theme instead of an unrelated palette default.
    final accentColor = savedColor?.color ?? colors.primary;
    final onAccentColor = savedColor?.onColor ?? colors.onPrimary;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('service-management'),
        ),
        title: Text(
          'Service Details',
          style: TextStyle(color: colors.onSurface),
        ),
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
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.overlay(accentColor),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: onAccentColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.miscellaneous_services,
                          size: 34,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    service.title,
                    style: AppTypography.headlineMedium.copyWith(
                      color: colors.onSurface,
                    ),
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
                          ? colors.errorContainer
                          : colors.tertiaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      service.isActive == false ? 'Inactive' : 'Active',
                      style: AppTypography.labelSmall.copyWith(
                        color: service.isActive == false
                            ? colors.onErrorContainer
                            : colors.onTertiaryContainer,
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
              accentColor: accentColor,
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
              accentColor: accentColor,
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
                      context.pushNamed(
                        'booking',
                        queryParameters: {'serviceId': serviceId.toString()},
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
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppShadows.card(accentColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              color: colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
