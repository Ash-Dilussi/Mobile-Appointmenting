import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/swipe_to_delete_wrapper.dart';
import '../../../../shared/widgets/pebble_context_menu.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../call_history/application/app_call_service.dart';
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
    final institutionId = ref.watch(authSessionProvider)?.institutionId;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
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
              stream: institutionId == null
                  ? Stream.value(const <Customer>[])
                  : db.watchCustomersForInstitution(institutionId),
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
                    final customer = customers[index];
                    final customerId = customer.id;
                    final card = _CustomerCard(
                      customer: customer,
                      onTap: customerId == null
                          ? null
                          : () {
                              context.goNamed(
                                'customer-profile',
                                pathParameters: {
                                  'id': customerId.toString(),
                                },
                              );
                            },
                    );
                    if (customerId == null) return card;
                    return SwipeToDeleteWrapper(
                      entityName: 'Customer',
                      onDelete: () async {
                        final db = ref.read(homeHiveProvider);
                        await db.deleteCustomer(customerId);
                      },
                      child: card,
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
  final VoidCallback? onTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = customer.name.trim();
    final displayName = name.isEmpty ? 'Unnamed customer' : name;
    final phone = customer.phoneNumber.trim();
    final email = customer.email?.trim() ?? '';
    final customerId = customer.id;
    return PebbleContextMenuWrapper(
      title: displayName,
      actions: [
        if (customerId != null)
          PebbleContextAction(
            icon: Icons.edit,
            label: 'Edit',
            onTap: () {
              context.goNamed(
                'edit-customer',
                pathParameters: {'id': customerId.toString()},
              );
            },
          ),
        if (customerId != null && phone.isNotEmpty)
          PebbleContextAction(
            icon: Icons.call,
            label: 'Call',
            onTap: () => _handleCall(context, ref, customerId, phone),
          ),
        if (customerId != null || phone.isNotEmpty)
          PebbleContextAction(
            icon: Icons.event,
            label: 'Book Appointment',
            onTap: () {
              context.goNamed(
                'booking',
                queryParameters: {
                  if (customerId != null) 'customerId': customerId.toString(),
                  if (phone.isNotEmpty) 'phone': phone,
                },
              );
            },
          ),
        if (customerId != null)
          PebbleContextAction(
            icon: Icons.delete,
            iconColor: colors.error,
            label: 'Delete',
            onTap: () => _showDeleteDialog(
              context,
              ref,
              customerId,
              displayName,
            ),
          ),
      ],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTypography.titleLarge.copyWith(
                      color: colors.onPrimaryContainer,
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
                      displayName,
                      style: AppTypography.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: AppTypography.bodySmall,
                      ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: AppTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCall(
    BuildContext context,
    WidgetRef ref,
    int customerId,
    String phone,
  ) async {
    final result = await ref.read(appCallServiceProvider).initiateCustomerCall(
          customerId: customerId,
          phoneNumber: phone,
        );
    final message = result.failureMessage;
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    int customerId,
    String displayName,
  ) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete "$displayName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final db = ref.read(homeHiveProvider);
              await db.deleteCustomer(customerId);
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
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
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasSearch ? 'No customers found' : 'No customers yet',
            style: AppTypography.bodyLarge.copyWith(
              color: colors.onSurfaceVariant,
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
