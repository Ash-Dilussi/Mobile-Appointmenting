import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../shared/widgets/info_button.dart';
import '../../../../shared/widgets/pebble_context_menu.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../providers/call_history_provider.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Call History'),
          centerTitle: true,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'All Calls'),
              Tab(text: 'Missed'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Privacy notice for call recording
            const _RecordingPrivacyNotice(),
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
                        error: (e, _) => Center(child: Text('Error: $e')),
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
                        error: (e, _) => Center(child: Text('Error: $e')),
                      ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'callHistoryFab',
          onPressed: () => _showImportCallSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('New Appointment'),
        ),
      ),
    );
  }

  void _showImportCallSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ImportCallSheet(
        onCallSelected: (phone) {
          Navigator.pop(context);
          context.goNamed('booking', queryParameters: {'phone': phone});
        },
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
    customer ??= db.getCustomerByPhone(callLog.phoneNumber);

    IconData icon;
    Color iconColor;
    String statusText;

    if (callLog.direction == 'incoming') {
      icon = Icons.call_received;
      iconColor = AppColors.success;
      statusText = 'Incoming';
    } else if (callLog.isMissed) {
      icon = Icons.call_missed;
      iconColor = AppColors.error;
      statusText = 'Missed';
    } else if (callLog.direction == 'outgoing') {
      icon = Icons.call_made;
      iconColor = AppColors.ongoing;
      statusText = 'Outgoing';
    } else {
      icon = Icons.phone;
      iconColor = AppColors.secondary;
      statusText = callLog.direction;
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

    return PebbleContextMenuWrapper(
      title: customer?.name ?? callLog.phoneNumber,
      actions: [
        PebbleContextAction(
          icon: Icons.call,
          label: 'Call Back',
          onTap: () => _handleCallBack(context, ref),
        ),
        PebbleContextAction(
          icon: Icons.event,
          label: 'Book Appointment',
          onTap: () {
            context.goNamed(
              'booking',
              queryParameters: {'phone': callLog.phoneNumber},
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
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Row(
          children: [
            // Initials avatar or call type icon
            if (customer != null)
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  initials,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: iconColor, size: 24),
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
                  if (customer != null)
                    Text(
                      callLog.phoneNumber,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '$statusText • ${dateFormat.format(callLog.timestamp)} at ${timeFormat.format(callLog.timestamp)}',
                    style: AppTypography.bodySmall,
                  ),
                  if (callLog.durationSeconds > 0)
                    Text(
                      'Duration: ${_formatDuration(callLog.durationSeconds)}',
                      style: AppTypography.bodySmall,
                    ),
                ],
              ),
            ),
            InfoButton(
              onTap: () {
                _showCallDetailsDialog(context, ref);
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

  void _showCallDetailsDialog(BuildContext context, WidgetRef ref) {
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
                value: callLog.isMissed ? 'Missed' : 'Answered'),
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
              _DetailRow(label: 'Followed Up', value: 'Yes'),
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
              _handleCallBack(context, ref);
            },
            child: const Text('Call Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCallBack(BuildContext context, WidgetRef ref) async {
    final phoneNumber = callLog.phoneNumber;
    final uri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(uri)) {
      // Mark as followed up before calling
      final db = ref.read(homeHiveProvider);
      await db.updateCallLog(callLog.id!, callLog..followedUp = true);
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.secondary,
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
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final db = ref.watch(homeHiveProvider);

    // Resolve customer: prefer linked customerId, fall back to phone lookup
    Customer? customer;
    if (callLog.customerId != null) {
      customer = db.getCustomerById(callLog.customerId!);
    }
    customer ??= db.getCustomerByPhone(callLog.phoneNumber);

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
        color: AppColors.surfaceContainerLowest,
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
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    initials,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.call_missed,
                    color: AppColors.error,
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
                    if (customer != null)
                      Text(
                        callLog.phoneNumber,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    Text(
                      '${dateFormat.format(callLog.timestamp)} at ${timeFormat.format(callLog.timestamp)}',
                      style: AppTypography.bodySmall,
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
                  onPressed: () => _handleCallBack(context, ref),
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
                      queryParameters: {'phone': callLog.phoneNumber},
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

  Future<void> _handleCallBack(BuildContext context, WidgetRef ref) async {
    final phoneNumber = callLog.phoneNumber;
    final uri = Uri(scheme: 'tel', path: phoneNumber);

    if (await canLaunchUrl(uri)) {
      final db = ref.read(homeHiveProvider);
      await db.updateCallLog(callLog.id!, callLog..followedUp = true);
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCallSheet extends StatelessWidget {
  final Function(String phone) onCallSelected;

  const _ImportCallSheet({required this.onCallSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'New Appointment',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter a phone number to book an appointment',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1 234 567 8900',
              prefixIcon: Icon(Icons.phone),
            ),
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                onCallSelected(value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                context.goNamed('booking');
              },
              child: const Text('Book Appointment'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Privacy notice widget for call recording feature.
/// Displays a persistent banner informing users that calls are recorded
/// for customer safety and appointment tracking.
class _RecordingPrivacyNotice extends StatelessWidget {
  const _RecordingPrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.mic,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '🔴 Recording for customer safety — conversations are recorded locally for appointment booking',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
