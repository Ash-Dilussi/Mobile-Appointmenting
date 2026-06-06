import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/info_button.dart';
import '../../../../shared/widgets/swipe_to_delete_wrapper.dart';
import '../../../../shared/widgets/pebble_context_menu.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';

class StationManagementScreen extends ConsumerWidget {
  const StationManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);
    final authSession = ref.watch(authSessionProvider);
    final isOwner = authSession?.role == Role.owner;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('settings'),
        ),
        title: const Text('Manage Stations'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<ServiceStation>>(
        stream: db.watchAllServiceStations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stations = snapshot.data ?? [];

          if (stations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_city_outlined,
                    size: 64,
                    color: AppColors.secondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No stations yet',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isOwner
                        ? 'Add your first service station to get started'
                        : 'No stations available',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: stations.length,
            itemBuilder: (context, index) {
              return SwipeToDeleteWrapper(
                entityName: 'Station',
                onDelete: () async {
                  final db = ref.read(homeHiveProvider);
                  await db.deleteServiceStation(stations[index].id!);
                },
                child: _StationCard(
                  station: stations[index],
                  isOwner: isOwner,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => context.goNamed('add-station'),
              icon: const Icon(Icons.add),
              label: const Text('Add Station'),
            )
          : null,
    );
  }
}

class _StationCard extends ConsumerWidget {
  final ServiceStation station;
  final bool isOwner;

  const _StationCard({
    required this.station,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PebbleContextMenuWrapper(
      title: station.name,
      actions: [
        if (isOwner) ...[
          PebbleContextAction(
            icon: Icons.edit,
            label: 'Edit',
            onTap: () {
              context.goNamed(
                'edit-station',
                pathParameters: {'id': station.id.toString()},
              );
            },
          ),
        ],
        if (station.address != null && station.address!.isNotEmpty)
          PebbleContextAction(
            icon: Icons.map,
            label: 'View on Map',
            onTap: () => _handleViewOnMap(context),
          ),
        if (station.address != null && station.address!.isNotEmpty)
          PebbleContextAction(
            icon: Icons.copy,
            label: 'Copy Address',
            onTap: () => _handleCopyAddress(context),
          ),
        if (isOwner)
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
                    station.name,
                    style: AppTypography.titleMedium,
                  ),
                  if (station.address != null && station.address!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            station.address!,
                            style: AppTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (station.phone != null && station.phone!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          station.phone!,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ],
                  if (station.description != null &&
                      station.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      station.description!,
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
                  'station-detail',
                  pathParameters: {'id': station.id.toString()},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleViewOnMap(BuildContext context) {
    // TODO: Implement map view using url_launcher with geo: URI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map view coming soon')),
    );
  }

  void _handleCopyAddress(BuildContext context) {
    if (station.address != null) {
      Clipboard.setData(ClipboardData(text: station.address!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Station'),
        content: Text(
          'Are you sure you want to delete "${station.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDelete(context, ref);
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

  void _handleDelete(BuildContext context, WidgetRef ref) async {
    final db = ref.read(homeHiveProvider);
    await db.deleteServiceStation(station.id!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station deleted')),
      );
    }
  }
}