import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/info_button.dart';
import '../../../../shared/widgets/swipe_to_delete_wrapper.dart';
import '../../../../shared/widgets/pebble_context_menu.dart';
import '../../../home/presentation/providers/home_provider.dart';

class ServiceManagementScreen extends ConsumerWidget {
  const ServiceManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('settings'),
        ),
        title: const Text('Manage Services'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Service>>(
        stream: db.watchAllServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snapshot.data ?? [];

          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.miscellaneous_services_outlined,
                    size: 64,
                    color: AppColors.secondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No services yet',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add your first service to get started',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: services.length,
            itemBuilder: (context, index) {
              return SwipeToDeleteWrapper(
                entityName: 'Service',
                onDelete: () async {
                  final db = ref.read(homeHiveProvider);
                  await db.softDeleteService(services[index].id!);
                },
                child: _ServiceCard(service: services[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed('add-service'),
        icon: const Icon(Icons.add),
        label: const Text('Add Service'),
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final Service service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return PebbleContextMenuWrapper(
      title: service.title,
      actions: [
        PebbleContextAction(
          icon: Icons.edit,
          label: 'Edit',
          onTap: () {
            context.goNamed(
              'edit-service',
              pathParameters: {'id': service.id.toString()},
            );
          },
        ),
        PebbleContextAction(
          icon: Icons.copy,
          label: 'Duplicate Service',
          onTap: () => _handleDuplicate(context, ref),
        ),
        PebbleContextAction(
          icon: service.isActive == false ? Icons.check_circle : Icons.hide_source,
          label: service.isActive == false ? 'Activate' : 'Deactivate',
          onTap: () => _handleToggleActive(context, ref),
        ),
        PebbleContextAction(
          icon: Icons.delete,
          iconColor: AppColors.error,
          label: 'Delete',
          onTap: () => _showDeleteDialog(context, ref),
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${service.defaultDurationMinutes} min',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Icon(
                        Icons.attach_money,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      Text(
                        currencyFormat.format(service.cost),
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                  if (service.description != null &&
                      service.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      service.description!,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            InfoButton(
              onTap: () {
                context.goNamed(
                  'service-detail',
                  pathParameters: {'id': service.id.toString()},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleDuplicate(BuildContext context, WidgetRef ref) async {
    final db = ref.read(homeHiveProvider);
    final duplicate = Service()
      ..title = '${service.title} (Copy)'
      ..defaultDurationMinutes = service.defaultDurationMinutes
      ..cost = service.cost
      ..description = service.description
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false
      ..isActive = true;
    await db.insertService(duplicate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service duplicated')),
      );
    }
  }

  void _handleToggleActive(BuildContext context, WidgetRef ref) async {
    final db = ref.read(homeHiveProvider);
    final updated = Service()
      ..title = service.title
      ..defaultDurationMinutes = service.defaultDurationMinutes
      ..cost = service.cost
      ..description = service.description
      ..createdAt = service.createdAt
      ..updatedAt = DateTime.now()
      ..synced = false
      ..isActive = service.isActive == false; // Toggle
    await db.updateService(service.id!, updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.isActive == false ? 'Service activated' : 'Service deactivated'),
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text(
          'Are you sure you want to delete "${service.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final db = ref.read(homeHiveProvider);
              await db.softDeleteService(service.id!);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}