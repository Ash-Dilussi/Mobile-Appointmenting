import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/info_button.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/pebble_context_menu.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../application/app_call_service.dart';
import '../providers/call_history_provider.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text('Call History'),
          centerTitle: true,
          bottom: TabBar(
            labelColor: colors.primary,
            unselectedLabelColor: colors.onSurfaceVariant,
            indicatorColor: colors.primary,
            tabs: const [
              Tab(text: 'All Calls'),
              Tab(text: 'Missed'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colors.onSecondaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Calls initiated through Bookly appear here. Calls made or received outside the app are not included.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // All Calls Tab
                  ref.watch(allCallLogsProvider).when(
                        data: (calls) {
                          if (calls.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.phone_outlined,
                              message: 'No call history yet',
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: calls.length,
                            itemBuilder: (context, index) {
                              return _CallHistoryCard(
                                callLog: calls[index],
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const _EmptyState(
                          icon: Icons.error_outline,
                          message: 'Call activity is unavailable right now',
                        ),
                      ),

                  // Missed Calls Tab
                  ref.watch(missedCallsProvider).when(
                        data: (calls) {
                          if (calls.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.phone_missed_outlined,
                              message: 'No missed calls',
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: calls.length,
                            itemBuilder: (context, index) {
                              return _MissedCallCard(
                                callLog: calls[index],
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const _EmptyState(
                          icon: Icons.error_outline,
                          message:
                              'Missed-call activity is unavailable right now',
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'callHistoryFab',
          onPressed: () => context.pushNamed('booking'),
          icon: const Icon(Icons.add),
          label: const Text('New Appointment'),
        ),
      ),
    );
  }
}

class _CallHistoryCard extends ConsumerWidget {
  final CallLog callLog;

  const _CallHistoryCard({
    required this.callLog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final db = ref.watch(homeHiveProvider);
    // Resolve customer: prefer linked customerId, fall back to phone lookup
    Customer? customer;
    if (callLog.customerId != null) {
      customer = db.getCustomerById(callLog.customerId!);
    }
    final institutionId = ref.watch(authSessionProvider)?.institutionId;
    if (institutionId != null) {
      customer ??= db.getCustomerByPhoneForInstitution(
        callLog.phoneNumber,
        institutionId,
      );
    }

    final colors = Theme.of(context).colorScheme;
    final isAppInitiated = callLog.origin == CallLog.originAppInitiated;
    final status = isAppInitiated
        ? callStatusPresentation('initiated', colors)
        : callLogStatusPresentation(
            isMissed: callLog.isMissed,
            direction: callLog.direction,
            colors: colors,
          );
    final icon = isAppInitiated
        ? Icons.call_made
        : callLog.isMissed
            ? Icons.call_missed
            : switch (callLog.direction) {
                'incoming' => Icons.call_received,
                'outgoing' => Icons.call_made,
                _ => Icons.phone,
              };

    // Get initials for avatar
    final displayName = customer?.name ?? callLog.phoneNumber;
    final initials = customer != null && customer.name.isNotEmpty
        ? customer.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';

    return PebbleContextMenuWrapper(
      title: customer?.name ?? callLog.phoneNumber,
      actions: [
        PebbleContextAction(
          icon: Icons.call,
          label: 'Call Back',
          onTap: () => _handleCallBack(context, ref, customer?.id),
        ),
        PebbleContextAction(
          icon: Icons.event,
          label: 'Book Appointment',
          onTap: () {
            context.goNamed(
              'booking',
              queryParameters: {
                'phone': callLog.phoneNumber,
                if (callLog.id != null) 'callLogId': callLog.id.toString(),
              },
            );
          },
        ),
        if (customer != null && customer.id != null)
          PebbleContextAction(
            icon: Icons.person,
            label: 'View Customer',
            onTap: () {
              final customerId = customer!.id!;
              context.goNamed(
                'customer-profile',
                pathParameters: {'id': customerId.toString()},
              );
            },
          )
        else if (callLog.linkedAppointmentId == null)
          PebbleContextAction(
            icon: Icons.person_add,
            label: 'Add as Customer',
            onTap: () {
              context.goNamed(
                'add-customer',
                queryParameters: {'phone': callLog.phoneNumber},
              );
            },
          ),
      ],
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            // Initials avatar or call type icon
            if (customer != null)
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  initials,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  icon,
                  color: status.foregroundColor,
                  size: 24,
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer?.name ?? callLog.phoneNumber,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: customer != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      AppBadge(presentation: status, compact: true),
                      Text(
                        '${dateFormat.format(callLog.timestamp)} at ${timeFormat.format(callLog.timestamp)}',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            InfoButton(
              onTap: () {
                _showCallDetailsDialog(context, ref, customer?.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes min ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  void _showCallDetailsDialog(
    BuildContext context,
    WidgetRef ref,
    int? customerId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(callLog.phoneNumber),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'Direction', value: callLog.direction),
            _DetailRow(
                label: 'Status',
                value: callLog.origin == CallLog.originAppInitiated
                    ? 'Call initiated'
                    : callLog.isMissed
                        ? 'Missed'
                        : 'Answered'),
            _DetailRow(
                label: 'Date',
                value: DateFormat('MMM d, yyyy').format(callLog.timestamp)),
            _DetailRow(
                label: 'Time',
                value: DateFormat('h:mm a').format(callLog.timestamp)),
            if (callLog.durationSeconds > 0)
              _DetailRow(
                  label: 'Duration',
                  value: _formatDuration(callLog.durationSeconds)),
            if (callLog.followedUp)
              const _DetailRow(label: 'Followed Up', value: 'Yes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _handleCallBack(context, ref, customerId);
            },
            child: const Text('Call Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCallBack(
    BuildContext context,
    WidgetRef ref,
    int? customerId,
  ) async {
    final phoneNumber = callLog.phoneNumber;
    final uri = Uri(scheme: 'tel', path: phoneNumber);

    if (customerId != null) {
      final result =
          await ref.read(appCallServiceProvider).initiateCustomerCall(
                customerId: customerId,
                phoneNumber: phoneNumber,
              );
      if (result == AppCallLaunchResult.launched && callLog.id != null) {
        final db = ref.read(homeHiveProvider);
        await db.updateCallLog(callLog.id!, callLog..followedUp = true);
      }
      final message = result.failureMessage;
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    final opened = await openExternalPhoneDialer(uri);
    if (opened && callLog.id != null) {
      final db = ref.read(homeHiveProvider);
      await db.updateCallLog(callLog.id!, callLog..followedUp = true);
    } else if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTypography.bodySmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissedCallCard extends ConsumerWidget {
  final CallLog callLog;

  const _MissedCallCard({
    required this.callLog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final db = ref.watch(homeHiveProvider);
    final missedStatus = callStatusPresentation(
      'missed',
      Theme.of(context).colorScheme,
    );

    // Resolve customer: prefer linked customerId, fall back to phone lookup
    Customer? customer;
    if (callLog.customerId != null) {
      customer = db.getCustomerById(callLog.customerId!);
    }
    final institutionId = ref.watch(authSessionProvider)?.institutionId;
    if (institutionId != null) {
      customer ??= db.getCustomerByPhoneForInstitution(
        callLog.phoneNumber,
        institutionId,
      );
    }

    // Get initials for avatar
    final displayName = customer?.name ?? callLog.phoneNumber;
    final initials = customer != null && customer.name.isNotEmpty
        ? customer.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Initials avatar or call type icon
              if (customer != null)
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    initials,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: missedStatus.backgroundColor,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    Icons.call_missed,
                    color: missedStatus.foregroundColor,
                    size: 24,
                  ),
                ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.name ?? callLog.phoneNumber,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: customer != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge(
                          presentation: missedStatus,
                          compact: true,
                        ),
                        Text(
                          '${dateFormat.format(callLog.timestamp)} at ${timeFormat.format(callLog.timestamp)}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleCallBack(context, ref, customer?.id),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Call Back'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    context.goNamed(
                      'booking',
                      queryParameters: {
                        'phone': callLog.phoneNumber,
                        if (callLog.id != null)
                          'callLogId': callLog.id.toString(),
                      },
                    );
                  },
                  icon: const Icon(Icons.event, size: 18),
                  label: const Text('Book'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCallBack(
    BuildContext context,
    WidgetRef ref,
    int? customerId,
  ) async {
    final phoneNumber = callLog.phoneNumber;
    final uri = Uri(scheme: 'tel', path: phoneNumber);

    if (customerId != null) {
      final result =
          await ref.read(appCallServiceProvider).initiateCustomerCall(
                customerId: customerId,
                phoneNumber: phoneNumber,
              );
      if (result == AppCallLaunchResult.launched && callLog.id != null) {
        final db = ref.read(homeHiveProvider);
        await db.updateCallLog(callLog.id!, callLog..followedUp = true);
      }
      final message = result.failureMessage;
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }

    final opened = await openExternalPhoneDialer(uri);
    if (opened && callLog.id != null) {
      final db = ref.read(homeHiveProvider);
      await db.updateCallLog(callLog.id!, callLog..followedUp = true);
    } else if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.bodyLarge.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
