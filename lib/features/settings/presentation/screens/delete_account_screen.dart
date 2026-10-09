import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static final Uri _supportEmail = Uri(
    scheme: 'mailto',
    path: 'bookly.support@gmail.com',
    queryParameters: {'subject': 'Bookly ownership transfer support'},
  );

  bool _understandsDeletion = false;

  Future<void> _openSupportEmail() async {
    if (!await launchUrl(_supportEmail) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email bookly.support@gmail.com for support.'),
        ),
      );
    }
  }

  Future<bool> _confirmDeletion({required bool business}) async {
    final controller = TextEditingController();
    var canDelete = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final colors = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Text(
              business
                  ? 'Permanently delete business?'
                  : 'Permanently delete account?',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business
                      ? 'This immediately deletes the business, all staff memberships, and all business data. Every affected device will erase its local copy at its next launch or authentication check.'
                      : 'This removes your identity and membership. You will lose access to all Bookly data on this device.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Type DELETE to continue.'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Confirmation'),
                  onChanged: (value) {
                    setDialogState(() => canDelete = value.trim() == 'DELETE');
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canDelete
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                child: Text(business ? 'Delete business' : 'Delete account'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result ?? false;
  }

  Future<void> _delete({
    required bool deleteInstitution,
    bool deletesBusinessData = false,
  }) async {
    if (!await _confirmDeletion(
          business: deleteInstitution || deletesBusinessData,
        ) ||
        !mounted) {
      return;
    }

    final deleted = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount(deleteInstitution: deleteInstitution);
    if (!mounted) return;
    if (deleted) {
      context.go('/login');
      return;
    }

    final state = ref.read(authNotifierProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.errorMessage?.isNotEmpty == true
              ? state.errorMessage!
              : 'The deletion could not be completed. Please try again.',
        ),
      ),
    );
  }

  void _cancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final session = ref.watch(authSessionProvider);
    final business = ref.watch(currentInstitutionProvider);
    final authState = ref.watch(authNotifierProvider);
    final isOwner = session?.isOwner == true && session?.hasInstitution == true;
    final isAlwaysSoloOwner =
        isOwner && business?.hasEverHadAdditionalStaff == false;
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Icon(
              Icons.delete_forever_outlined,
              color: colors.error,
              size: 44,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isAlwaysSoloOwner
                  ? 'Delete your account and business'
                  : isOwner
                      ? 'Your business has one owner'
                      : 'This cannot be undone',
              style: AppTypography.headlineMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isAlwaysSoloOwner
                  ? 'Because this business has always been yours alone, one action removes your account and all business data.'
                  : isOwner
                      ? 'Your personal account cannot be deleted by itself because that would leave the business without an owner. Choose one of the two paths below.'
                      : 'Deleting your account removes your Firebase identity, Bookly membership, and local account data. Business-owned records remain available to its other authorized staff.',
              style: AppTypography.bodyLarge.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (isOwner && !isAlwaysSoloOwner) ...[
              _PathCard(
                icon: Icons.domain_disabled_outlined,
                title: 'Delete the business and account',
                description:
                    'Immediately removes the business, every staff membership, and all of its data. Offline devices erase local copies when they next connect.',
                actionLabel: 'Delete business',
                destructive: true,
                enabled: !isLoading,
                onPressed: () => _delete(deleteInstitution: true),
              ),
              const SizedBox(height: AppSpacing.md),
              _PathCard(
                icon: Icons.close,
                title: 'Cancel and keep the account',
                description:
                    'Nothing changes. Your business and account stay active.',
                actionLabel: 'Cancel',
                enabled: !isLoading,
                onPressed: _cancel,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need to keep the business?',
                      style: AppTypography.titleSmall.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Self-service ownership transfer is not available in v1. Contact support for a manually assisted transfer.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openSupportEmail,
                      icon: const Icon(Icons.email_outlined),
                      label: const Text('bookly.support@gmail.com'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _understandsDeletion,
                onChanged: isLoading
                    ? null
                    : (value) {
                        setState(() => _understandsDeletion = value ?? false);
                      },
                title: Text(
                  isAlwaysSoloOwner
                      ? 'I understand that my account and all business data will be permanently deleted.'
                      : 'I understand that my account and access will be permanently deleted.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _understandsDeletion && !isLoading
                    ? () => _delete(
                          deleteInstitution: false,
                          deletesBusinessData: isAlwaysSoloOwner,
                        )
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onError,
                        ),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(
                  isAlwaysSoloOwner
                      ? 'Delete account and business'
                      : 'Delete my account',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: isLoading ? null : _cancel,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = destructive ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: destructive ? colors.error : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (destructive)
            FilledButton(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              child: Text(actionLabel),
            )
          else
            OutlinedButton(
              onPressed: enabled ? onPressed : null,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
