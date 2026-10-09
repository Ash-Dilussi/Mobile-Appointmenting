import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/database/collections/user.dart';
import '../../../../core/database/collections/institution.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/auth/officer_provisioning_service.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final session = ref.watch(authSessionProvider);
    final hiveService = ref.watch(hiveServiceProvider);

    // Check if user has permission (owner only)
    if (session?.role != Role.owner) {
      return Scaffold(
        backgroundColor: colors.surface,
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
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 64, color: colors.onSurfaceVariant),
                const SizedBox(height: AppSpacing.lg),
                Text('Access Denied', style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Only owners can manage staff members.',
                  style: TextStyle(color: colors.onSurfaceVariant),
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
      backgroundColor: colors.surface,
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
                    Icon(Icons.business_outlined,
                        size: 64, color: colors.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.lg),
                    Text('No Business Found', style: AppTypography.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Set up a business to start managing staff.',
                      style: TextStyle(color: colors.onSurfaceVariant),
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
                        Text('Staff & Operators',
                            style: AppTypography.titleMedium),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${staffMembers.where((s) => s.role == 'officer').length}',
                            style: AppTypography.labelSmall.copyWith(
                              color: colors.onPrimaryContainer,
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
                                Icon(Icons.people_outline,
                                    size: 48, color: colors.onSurfaceVariant),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No staff members yet',
                                  style:
                                      TextStyle(color: colors.onSurfaceVariant),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Create an officer account to add staff.',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final officers = staffMembers
                                .where((s) => s.role == 'officer')
                                .toList();
                            final officer = officers[index];
                            return _StaffListItem(
                              officer: officer,
                              onTap: () => context.goNamed(
                                'operator-profile',
                                pathParameters: {'id': officer.id},
                              ),
                            );
                          },
                          childCount: staffMembers
                              .where((s) => s.role == 'officer')
                              .length,
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
    var isSubmitting = false;
    String? errorMessage;

    showDialog<void>(
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
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Staff are provisioned as Officers. You can share their temporary password after creation.',
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final session = ref.read(authSessionProvider);
                          if (name.isEmpty || email.isEmpty) {
                            setState(() {
                              errorMessage = 'Enter a name and email address.';
                            });
                            return;
                          }
                          if (session == null ||
                              !session.isOwner ||
                              !session.hasInstitution) {
                            setState(() {
                              errorMessage = 'Your owner session has expired.';
                            });
                            return;
                          }

                          setState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });
                          try {
                            final result = await ref
                                .read(officerProvisioningServiceProvider)
                                .provisionOfficer(
                                  ownerUid: session.userId,
                                  institutionId: session.institutionId!,
                                  displayName: name,
                                  email: email,
                                );
                            final hive = ref.read(hiveServiceProvider);
                            final cachedOfficer = User()
                              ..id = result.uid
                              ..institutionId = session.institutionId
                              ..email = result.email
                              ..name = name
                              ..role = 'officer';
                            final business = hive.getInstitutionById(
                              session.institutionId!,
                            );
                            if (business != null &&
                                business.hasEverHadAdditionalStaff != true) {
                              business.hasEverHadAdditionalStaff = true;
                              await hive.updateInstitution(
                                business.id,
                                business,
                              );
                            }
                            await hive.insertUser(cachedOfficer);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            _showCredentialsDialog(context, result);
                          } on OfficerProvisioningException catch (error) {
                            setState(() {
                              errorMessage = error.message;
                            });
                          } catch (_) {
                            setState(() {
                              errorMessage =
                                  'We could not create this staff account. Try again.';
                            });
                          } finally {
                            if (context.mounted) {
                              setState(() => isSubmitting = false);
                            }
                          }
                        },
                  child: Text(isSubmitting ? 'Creating...' : 'Create Officer'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      emailController.dispose();
    });
  }

  void _showCredentialsDialog(
    BuildContext context,
    OfficerProvisioningResult result,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Officer account created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${result.email}'),
            const SizedBox(height: AppSpacing.sm),
            SelectableText('Temporary password: ${result.temporaryPassword}'),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Share these credentials through your own secure channel. The officer can change the password later from Settings.',
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: result.temporaryPassword),
              );
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Temporary password copied')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy password'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
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
    final colors = Theme.of(context).colorScheme;
    final pendingStatus = staffStatusPresentation(
      'pending_leave',
      colors,
    );
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
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business, color: colors.onPrimaryContainer),
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
                          style: AppTypography.bodySmall
                              .copyWith(color: colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEditTap,
                  tooltip: 'Edit Business',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBadge(
                      presentation: AppBadgePresentation(
                        label:
                            '$pendingCount pending leave request${pendingCount > 1 ? 's' : ''}',
                        backgroundColor: pendingStatus.backgroundColor,
                        foregroundColor: pendingStatus.foregroundColor,
                      ),
                      compact: true,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: pendingStatus.foregroundColor,
                    ),
                  ],
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.bodySmall
                .copyWith(color: colors.onSurfaceVariant),
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
    final colors = Theme.of(context).colorScheme;
    final pendingStatus = staffStatusPresentation(
      officer.status ?? '',
      colors,
    );
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
          backgroundColor: colors.surfaceContainerHigh,
          child: Text(
            officer.name.isNotEmpty ? officer.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: colors.onSurface,
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
          style:
              AppTypography.bodySmall.copyWith(color: colors.onSurfaceVariant),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (officer.status == 'pending_leave')
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: AppBadge(
                  presentation: pendingStatus,
                  compact: true,
                ),
              ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
