import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../home/presentation/providers/home_provider.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(homeHiveProvider);

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
        body: TabBarView(
          children: [
            // All Calls Tab
            StreamBuilder<List<CallLog>>(
              stream: db.watchAllCallLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final calls = snapshot.data ?? [];

                if (calls.isEmpty) {
                  return _EmptyState(
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
                      ref: ref,
                    );
                  },
                );
              },
            ),

            // Missed Calls Tab
            StreamBuilder<List<CallLog>>(
              stream: db.watchMissedCalls(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final calls = snapshot.data ?? [];

                if (calls.isEmpty) {
                  return _EmptyState(
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
                      ref: ref,
                    );
                  },
                );
              },
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

class _CallHistoryCard extends StatelessWidget {
  final CallLog callLog;
  final WidgetRef ref;

  const _CallHistoryCard({
    required this.callLog,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');

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

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
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
                  callLog.phoneNumber,
                  style: AppTypography.bodyLarge,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.secondary),
            onSelected: (value) => _handleAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'call',
                child: Row(
                  children: [
                    Icon(Icons.call, size: 20),
                    SizedBox(width: 8),
                    Text('Call Back'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'book',
                child: Row(
                  children: [
                    Icon(Icons.event, size: 20),
                    SizedBox(width: 8),
                    Text('Book Appointment'),
                  ],
                ),
              ),
              if (callLog.linkedAppointmentId == null)
                const PopupMenuItem(
                  value: 'customer',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, size: 20),
                      SizedBox(width: 8),
                      Text('Add as Customer'),
                    ],
                  ),
                ),
            ],
          ),
        ],
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

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'call':
        // TODO: Implement call back
        break;
      case 'book':
        context.goNamed(
          'booking',
          queryParameters: {'phone': callLog.phoneNumber},
        );
        break;
      case 'customer':
        // TODO: Implement add as customer
        break;
    }
  }
}

class _MissedCallCard extends StatelessWidget {
  final CallLog callLog;
  final WidgetRef ref;

  const _MissedCallCard({
    required this.callLog,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');

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
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
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
                      callLog.phoneNumber,
                      style: AppTypography.bodyLarge,
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
                  onPressed: () {
                    // Call back
                  },
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
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
