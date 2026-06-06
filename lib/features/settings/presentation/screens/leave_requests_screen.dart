import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/leave_request.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

class LeaveRequestsScreen extends ConsumerWidget {
  const LeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final hiveService = ref.watch(hiveServiceProvider);

    if (session?.institutionId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leave Requests')),
        body: const Center(child: Text('No company found')),
      );
    }

    final pendingRequests = hiveService.getPendingLeaveRequests(session!.institutionId!);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Leave Requests'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('staff-management');
            }
          },
        ),
      ),
      body: pendingRequests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'No Pending Requests',
                      style: AppTypography.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'All leave requests have been processed.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.secondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: pendingRequests.length,
              itemBuilder: (context, index) {
                final request = pendingRequests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryContainer,
                              child: Text(
                                request.userName.isNotEmpty
                                    ? request.userName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: AppColors.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request.userName.isNotEmpty
                                        ? request.userName
                                        : 'Unnamed',
                                    style: AppTypography.bodyLarge,
                                  ),
                                  Text(
                                    request.userEmail,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Requested ${_formatDate(request.requestedAt)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rejectRequest(context, ref, request),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _approveRequest(context, ref, request),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} minutes ago';
      }
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _approveRequest(
      BuildContext context, WidgetRef ref, LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Leave Request?'),
        content: Text(
          'This will remove ${request.userName} from your company. '
          'They will no longer have access to this company\'s data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final hiveService = ref.read(hiveServiceProvider);
    final session = ref.read(authSessionProvider);

    // Update leave request status
    request.status = 'approved';
    request.processedAt = DateTime.now();
    request.processedBy = session?.userId;
    await hiveService.updateLeaveRequest(request.id!, request);

    // Update user - remove from institution
    final user = hiveService.getUserById(request.userId);
    if (user != null) {
      user.institutionId = null;
      user.status = 'left';
      await hiveService.updateUser(user.id, user);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.userName} has left the company')),
      );
    }
  }

  Future<void> _rejectRequest(
      BuildContext context, WidgetRef ref, LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request?'),
        content: Text(
          'This will reject ${request.userName}\'s request to leave. '
          'They will remain a member of your company.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final hiveService = ref.read(hiveServiceProvider);
    final session = ref.read(authSessionProvider);

    // Update leave request status
    request.status = 'rejected';
    request.processedAt = DateTime.now();
    request.processedBy = session?.userId;
    await hiveService.updateLeaveRequest(request.id!, request);

    // Reset user status to active
    final user = hiveService.getUserById(request.userId);
    if (user != null) {
      user.status = 'active';
      await hiveService.updateUser(user.id, user);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave request rejected')),
      );
    }
  }
}
