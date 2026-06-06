import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/auth/rbac.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';

class StationDetailScreen extends ConsumerWidget {
  final int stationId;

  const StationDetailScreen({
    super.key,
    required this.stationId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final authSession = ref.watch(authSessionProvider);
    final isOwner = authSession?.role == Role.owner;
    final station = db.getServiceStationById(stationId);

    if (station == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.goNamed('station-management'),
          ),
        ),
        body: const Center(child: Text('Station not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('station-management'),
        ),
        title: const Text('Station Details'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.goNamed(
                  'edit-station',
                  pathParameters: {'id': stationId.toString()},
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
            // Station Header
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
                        Icons.location_city,
                        size: 36,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    station.name,
                    style: AppTypography.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Location Info Card
            _SectionCard(
              title: 'Location Information',
              children: [
                if (station.address != null && station.address!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on,
                    label: 'Address',
                    value: station.address!,
                    onTap: () => _copyToClipboard(context, station.address!, 'Address'),
                  ),
                if (station.phone != null && station.phone!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.phone,
                    label: 'Phone',
                    value: station.phone!,
                    onTap: () => _copyToClipboard(context, station.phone!, 'Phone'),
                  ),
                if (station.description != null && station.description!.isNotEmpty)
                  _InfoRow(
                    icon: Icons.notes,
                    label: 'Description',
                    value: station.description!,
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Record Info Card
            _SectionCard(
              title: 'Record Info',
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Created',
                  value: DateFormat('MMM d, yyyy').format(station.createdAt),
                ),
                _InfoRow(
                  icon: Icons.update,
                  label: 'Last Updated',
                  value: DateFormat('MMM d, yyyy').format(station.updatedAt),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Actions
            if (isOwner)
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
                          'edit-station',
                          pathParameters: {'id': stationId.toString()},
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

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
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
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
            if (onTap != null)
              const Icon(
                Icons.copy,
                size: 16,
                color: AppColors.secondary,
              ),
          ],
        ),
      ),
    );
  }
}