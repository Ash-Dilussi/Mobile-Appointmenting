import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/call_log_entry.dart';
import '../../providers/call_log_providers.dart';
import 'contact_suite_view.dart';

class CallLogListTile extends ConsumerWidget {
  final CallLogEntry entry;

  const CallLogListTile({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: _SwipeBackground(),
      confirmDismiss: (direction) => _showCallConfirmDialog(context, ref),
      onDismissed:
          (_) {}, // Never actually dismissed - confirmDismiss returns false
      child: _CallLogTileContent(
        entry: entry,
        onTap: () => _showContactSuiteView(context),
      ),
    );
  }

  Future<bool> _showCallConfirmDialog(
      BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          entry.customerName != null
              ? 'Call ${entry.customerName}?'
              : 'Call ${entry.phoneNumber}?',
        ),
        content: Text(entry.phoneNumber),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Dialer'),
          ),
        ],
      ),
    );

    if (result == true) {
      final uri = Uri(scheme: 'tel', path: entry.phoneNumber);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }

    return false; // Always return false - never dismiss the item
  }

  void _showContactSuiteView(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ContactSuiteView(entry: entry),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call, color: Colors.white),
          SizedBox(width: AppSpacing.xs),
          Text(
            'Call',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallLogTileContent extends StatelessWidget {
  final CallLogEntry entry;
  final VoidCallback onTap;

  const _CallLogTileContent({
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final now = DateTime.now();
    final isToday = entry.startTime.year == now.year &&
        entry.startTime.month == now.month &&
        entry.startTime.day == now.day;

    // Determine call type icon and color
    IconData icon;
    Color iconColor;
    String statusText;

    switch (entry.callType.toLowerCase()) {
      case 'incoming':
        icon = Icons.call_received;
        iconColor = AppColors.success;
        statusText = 'Incoming';
        break;
      case 'outgoing':
        icon = Icons.call_made;
        iconColor = AppColors.primary;
        statusText = 'Outgoing';
        break;
      case 'missed':
      default:
        icon = Icons.call_missed;
        iconColor = AppColors.error;
        statusText = 'Missed';
    }

    // Format duration
    String durationText = '';
    if (entry.durationSeconds > 0) {
      final minutes = entry.durationSeconds ~/ 60;
      final seconds = entry.durationSeconds % 60;
      durationText = '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    // Time/date display
    final timeText = isToday
        ? timeFormat.format(entry.startTime)
        : dateFormat.format(entry.startTime);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            // Call type icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),

            const SizedBox(width: AppSpacing.md),

            // Name/Number and phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.customerName ?? entry.phoneNumber,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Live indicator for ongoing calls
                      if (entry.state == 'ongoing') _LiveIndicator(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.customerName != null ? entry.phoneNumber : 'Unknown',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Duration and time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.state == 'missed' && entry.durationSeconds == 0
                      ? 'Missed'
                      : durationText,
                  style: AppTypography.bodyMedium.copyWith(
                    color: entry.state == 'missed'
                        ? AppColors.error
                        : AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeText,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.secondary,
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

class _LiveIndicator extends StatefulWidget {
  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(left: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: _animation.value * 0.2),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: _animation.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Live',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
