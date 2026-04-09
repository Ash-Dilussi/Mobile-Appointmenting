import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            Text(
              'Account',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: 'Manage your account details',
                  onTap: () {
                    // TODO: Navigate to profile
                  },
                ),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () {
                    // TODO: Navigate to change password
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // App Preferences Section
            Text(
              'App Preferences',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Manage notification settings',
                  onTap: () {
                    // TODO: Navigate to notifications
                  },
                ),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Light mode',
                  onTap: () {
                    // TODO: Navigate to appearance settings
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Business Management Section
            Text(
              'Business Management',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.miscellaneous_services_outlined,
                  title: 'Manage Services',
                  subtitle: 'Add, edit, or remove services',
                  onTap: () {
                    context.goNamed('service-management');
                  },
                ),
                _SettingsTile(
                  icon: Icons.people_outline,
                  title: 'Staff Management',
                  subtitle: 'Manage staff members',
                  onTap: () {
                    // TODO: Navigate to staff management
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Help & Support Section
            Text(
              'Help & Support',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  subtitle: 'FAQs and guides',
                  onTap: () {
                    // TODO: Navigate to help
                  },
                ),
                _SettingsTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Contact Support',
                  subtitle: 'Get help from our team',
                  onTap: () {
                    // TODO: Navigate to contact support
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // About Section
            Text(
              'About',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About App',
                  subtitle: 'Version 1.0.0',
                  onTap: () {
                    // TODO: Show about dialog
                  },
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {
                    // TODO: Navigate to terms
                  },
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(authStateProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: Text(
                  'Sign Out',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: AppSpacing.xxl,
                color: AppColors.outline.withOpacity(0.1),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.bodySmall,
                    ),
                  ],
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
    );
  }
}
