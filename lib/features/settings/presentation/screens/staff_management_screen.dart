import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/database/collections/user.dart';
import '../../../../core/database/collections/institution.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final hiveService = ref.watch(hiveServiceProvider);

    // Check if user has permission (owner only)
    if (session?.role != Role.owner) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Staff Management'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed('settings');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: AppColors.secondary),
                SizedBox(height: AppSpacing.lg),
                Text('Access Denied', style: AppTypography.titleLarge),
                SizedBox(height: AppSpacing.sm),
                Text(
                  'Only owners can manage staff members.',
                  style: TextStyle(color: AppColors.secondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final institutionId = session!.institutionId!;
    final institution = hiveService.getInstitutionById(institutionId);
    final staffMembers = hiveService.getUsersForInstitution(institutionId);
    final pendingCount = hiveService.getPendingLeaveRequestCount(institutionId);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Staff Management'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('settings');
            }
          },
        ),
      ),
      body: institution == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.business_outlined, size: 64, color: AppColors.secondary),
                    const SizedBox(height: AppSpacing.lg),
                    Text('No Company Found', style: AppTypography.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Create a company to start managing staff.',
                      style: TextStyle(color: AppColors.secondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                // Company Card
                SliverToBoxAdapter(
                  child: _CompanyCard(
                    institution: institution,
                    pendingCount: pendingCount,
                    onEditTap: () => context.goNamed('edit-company'),
                    onPendingTap: pendingCount > 0
                        ? () => context.goNamed('leave-requests')
                        : null,
                  ),
                ),

                // Staff Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPadding,
                      AppSpacing.lg,
                      AppSpacing.screenPadding,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Text('Staff & Operators', style: AppTypography.titleMedium),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${staffMembers.where((s) => s.role == 'officer').length}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Staff List
                staffMembers.where((s) => s.role == 'officer').isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 48, color: AppColors.secondary),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No staff members yet',
                                  style: TextStyle(color: AppColors.secondary),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Invite staff to join your company.',
                                  style: TextStyle(color: AppColors.secondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final officers = staffMembers.where((s) => s.role == 'officer').toList();
                            final officer = officers[index];
                            return _StaffListItem(
                              officer: officer,
                              onTap: () => context.goNamed(
                                'operator-profile',
                                pathParameters: {'id': officer.id},
                              ),
                            );
                          },
                          childCount: staffMembers.where((s) => s.role == 'officer').length,
                        ),
                      ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteStaffDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Invite Staff'),
      ),
    );
  }

  void _showInviteStaffDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'officer';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Invite Staff Member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Enter staff member name',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter staff member email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'officer', child: Text('Officer')),
                    ],
                    onChanged: (value) {
                      setState(() => selectedRole = value!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invitation sent!')),
                    );
                  },
                  child: const Text('Send Invite'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CompanyCard extends StatelessWidget {
  final Institution institution;
  final int pendingCount;
  final VoidCallback onEditTap;
  final VoidCallback? onPendingTap;

  const _CompanyCard({
    required this.institution,
    required this.pendingCount,
    required this.onEditTap,
    this.onPendingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, color: AppColors.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        institution.name,
                        style: AppTypography.titleMedium,
                      ),
                      if (institution.address != null)
                        Text(
                          institution.address!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEditTap,
                  tooltip: 'Edit Company',
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            // Contact info row
            Row(
              children: [
                if (institution.email != null) ...[
                  _InfoChip(Icons.email_outlined, institution.email!),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (institution.phone != null)
                  _InfoChip(Icons.phone_outlined, institution.phone!),
              ],
            ),

            // Pending requests badge
            if (pendingCount > 0) ...[
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: onPendingTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_actions, size: 18, color: AppColors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$pendingCount pending leave request${pendingCount > 1 ? 's' : ''}',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.chevron_right, size: 18, color: AppColors.error),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

class _StaffListItem extends StatelessWidget {
  final User officer;
  final VoidCallback onTap;

  const _StaffListItem({required this.officer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.surfaceContainerHigh,
          child: Text(
            officer.name.isNotEmpty ? officer.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          officer.name.isNotEmpty ? officer.name : 'Unnamed',
          style: AppTypography.bodyLarge,
        ),
        subtitle: Text(
          officer.email,
          style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (officer.status == 'pending_leave')
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pending Leave',
                  style: TextStyle(color: AppColors.error, fontSize: 10),
                ),
              ),
            const Icon(Icons.chevron_right, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}
