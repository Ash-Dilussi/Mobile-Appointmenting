import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/swipe_to_delete_wrapper.dart';
import '../../../../shared/widgets/pebble_context_menu.dart';
import '../../../home/presentation/providers/home_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(homeHiveProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Customers'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Customer List
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: db.watchAllCustomers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var customers = snapshot.data ?? [];

                // Filter by search query
                if (_searchQuery.isNotEmpty) {
                  customers = customers.where((c) {
                    return c.name.toLowerCase().contains(_searchQuery) ||
                        c.phoneNumber.contains(_searchQuery);
                  }).toList();
                }

                if (customers.isEmpty) {
                  return _EmptyState(
                    hasSearch: _searchQuery.isNotEmpty,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    return SwipeToDeleteWrapper(
                      entityName: 'Customer',
                      onDelete: () async {
                        final db = ref.read(homeHiveProvider);
                        await db.deleteCustomer(customers[index].id!);
                      },
                      child: _CustomerCard(
                        customer: customers[index],
                        onTap: () {
                          context.goNamed(
                            'customer-profile',
                            pathParameters: {
                              'id': customers[index].id.toString()
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => GoRouter.of(context).push('/customers/add'),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PebbleContextMenuWrapper(
      title: customer.name,
      actions: [
        PebbleContextAction(
          icon: Icons.edit,
          label: 'Edit',
          onTap: () {
            context.goNamed(
              'edit-customer',
              pathParameters: {'id': customer.id.toString()},
            );
          },
        ),
        PebbleContextAction(
          icon: Icons.call,
          label: 'Call',
          onTap: () => _handleCall(context),
        ),
        PebbleContextAction(
          icon: Icons.event,
          label: 'Book Appointment',
          onTap: () {
            context.goNamed(
              'booking',
              queryParameters: {'phone': customer.phoneNumber},
            );
          },
        ),
        PebbleContextAction(
          icon: Icons.delete,
          iconColor: AppColors.error,
          label: 'Delete',
          onTap: () => _showDeleteDialog(context, ref),
        ),
      ],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: AppTypography.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.phoneNumber,
                      style: AppTypography.bodySmall,
                    ),
                    if (customer.email != null && customer.email!.isNotEmpty)
                      Text(
                        customer.email!,
                        style: AppTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCall(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: customer.phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete "${customer.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final db = ref.read(homeHiveProvider);
              await db.deleteCustomer(customer.id!);
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

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: AppColors.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasSearch ? 'No customers found' : 'No customers yet',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasSearch
                ? 'Try a different search term'
                : 'Add your first customer to get started',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
