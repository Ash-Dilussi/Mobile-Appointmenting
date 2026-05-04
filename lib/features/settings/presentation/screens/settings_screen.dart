import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
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
                  subtitle: _getThemeSubtitle(ref),
                  onTap: () => _showThemeSelector(context, ref),
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
                  icon: Icons.location_city_outlined,
                  title: 'Manage Stations',
                  subtitle: 'Add, edit, or remove service stations',
                  onTap: () {
                    context.goNamed('station-management');
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

            // Tips & Hints Section
            Text(
              'Tips & Hints',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _HintTile(
                  hint: 'When a call comes in, tap "Book Now" to quickly schedule an appointment',
                ),
                const Divider(height: 1, indent: AppSpacing.xxl, color: AppColors.outline),
                _HintTile(
                  hint: 'Use the calendar view to see your entire schedule at a glance',
                ),
                const Divider(height: 1, indent: AppSpacing.xxl, color: AppColors.outline),
                _HintTile(
                  hint: 'Search for existing customers by name or phone number',
                ),
                const Divider(height: 1, indent: AppSpacing.xxl, color: AppColors.outline),
                _HintTile(
                  hint: 'Missed calls are tracked automatically - follow up with one tap',
                ),
                const Divider(height: 1, indent: AppSpacing.xxl, color: AppColors.outline),
                _HintTile(
                  hint: 'Your data is stored locally and works even without internet',
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
                    _showAboutDialog(context);
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

            // Developer Tools Section
            Text(
              'Developer Tools',
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Load Sample Data',
                  subtitle: 'Seed database with test data',
                  onTap: () async {
                    await _seedSampleData(context);
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

  Future<void> _seedSampleData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ensure adapters are registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CustomerAdapter());
        Hive.registerAdapter(ServiceAdapter());
        Hive.registerAdapter(AppointmentAdapter());
        Hive.registerAdapter(CallLogAdapter());
      }

      // Open boxes properly with await
      final customerBox = await Hive.openBox<Customer>('customers');
      final serviceBox = await Hive.openBox<Service>('services');
      final appointmentBox = await Hive.openBox<Appointment>('appointments');
      final callLogBox = await Hive.openBox<CallLog>('callLogs');

      await customerBox.clear();
      await serviceBox.clear();
      await appointmentBox.clear();
      await callLogBox.clear();

      final now = DateTime.now();

      // Verify box is ready
      final testCustomer = Customer()
        ..id = 999
        ..phoneNumber = 'test'
        ..name = 'Test'
        ..createdAt = now
        ..updatedAt = now
        ..synced = false;
      await customerBox.put(999, testCustomer);
      final verify = customerBox.get(999);
      if (verify == null) {
        throw Exception('Box not working properly');
      }
      await customerBox.delete(999);

      // Customers
      final customers = <Customer>[
        Customer()
          ..id = 1
          ..phoneNumber = '+1234567890'
          ..name = 'Alice Johnson'
          ..email = 'alice@email.com'
          ..notes = 'Morning person'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 2
          ..phoneNumber = '+1987654321'
          ..name = 'Bob Smith'
          ..email = 'bob@email.com'
          ..notes = 'Regular client'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 3
          ..phoneNumber = '+1555123456'
          ..name = 'Carol Davis'
          ..email = 'carol@email.com'
          ..notes = 'New customer'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 4
          ..phoneNumber = '+1415555678'
          ..name = 'David Wilson'
          ..email = 'david@email.com'
          ..notes = 'Afternoon'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 5
          ..phoneNumber = '+1617555123'
          ..name = 'Emma Brown'
          ..email = 'emma@email.com'
          ..notes = 'VIP'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
      ];
      for (var c in customers) {
        await customerBox.put(c.id, c);
      }

      // Services
      final services = <Service>[
        Service()
          ..id = 1
          ..title = 'Haircut'
          ..defaultDurationMinutes = 30
          ..cost = 50.0
          ..description = 'Standard haircut'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 2
          ..title = 'Hair Coloring'
          ..defaultDurationMinutes = 90
          ..cost = 150.0
          ..description = 'Full coloring'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 3
          ..title = 'Massage'
          ..defaultDurationMinutes = 60
          ..cost = 80.0
          ..description = 'Relaxing massage'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 4
          ..title = 'Manicure'
          ..defaultDurationMinutes = 45
          ..cost = 40.0
          ..description = 'Nail care'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 5
          ..title = 'Consultation'
          ..defaultDurationMinutes = 15
          ..cost = 0.0
          ..description = 'Free consultation'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
      ];
      for (var s in services) {
        await serviceBox.put(s.id, s);
      }

      // Appointments
      final appointments = <Appointment>[
        Appointment()
          ..id = 1
          ..customerId = 1
          ..serviceId = 1
          ..startTime = _makeDate(0, 9, 0)
          ..endTime = _makeDate(0, 9, 30)
          ..status = 'confirmed'
          ..staffId = 1
          ..notes = ''
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Appointment()
          ..id = 2
          ..customerId = 2
          ..serviceId = 3
          ..startTime = _makeDate(0, 10, 0)
          ..endTime = _makeDate(0, 11, 0)
          ..status = 'upcoming'
          ..staffId = 1
          ..notes = ''
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Appointment()
          ..id = 3
          ..customerId = 3
          ..serviceId = 2
          ..startTime = _makeDate(1, 14, 0)
          ..endTime = _makeDate(1, 15, 30)
          ..status = 'upcoming'
          ..staffId = 1
          ..notes = ''
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Appointment()
          ..id = 4
          ..customerId = 4
          ..serviceId = 4
          ..startTime = _makeDate(2, 11, 0)
          ..endTime = _makeDate(2, 11, 45)
          ..status = 'ongoing'
          ..staffId = 1
          ..notes = ''
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Appointment()
          ..id = 5
          ..customerId = 5
          ..serviceId = 1
          ..startTime = _makeDate(-1, 15, 0)
          ..endTime = _makeDate(-1, 15, 30)
          ..status = 'done'
          ..staffId = 1
          ..notes = ''
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Appointment()
          ..id = 6
          ..customerId = 1
          ..serviceId = 3
          ..startTime = _makeDate(3, 9, 30)
          ..endTime = _makeDate(3, 10, 30)
          ..status = 'upcoming'
          ..staffId = 1
          ..notes = 'Follow-up massage'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
      ];
      for (var a in appointments) {
        await appointmentBox.put(a.id, a);
      }

      // Call Logs
      final callLogs = <CallLog>[
        CallLog()
          ..id = 1
          ..phoneNumber = '+1234567890'
          ..timestamp = _makeDate(0, 8, 30)
          ..direction = 'incoming'
          ..durationSeconds = 120
          ..isMissed = false
          ..followedUp = true
          ..linkedAppointmentId = 1
          ..customerId = 1
          ..createdAt = now
          ..synced = false,
        CallLog()
          ..id = 2
          ..phoneNumber = '+1987654321'
          ..timestamp = _makeDate(0, 9, 45)
          ..direction = 'incoming'
          ..durationSeconds = 60
          ..isMissed = false
          ..followedUp = true
          ..linkedAppointmentId = 2
          ..customerId = 2
          ..createdAt = now
          ..synced = false,
        CallLog()
          ..id = 3
          ..phoneNumber = '+1555123456'
          ..timestamp = _makeDate(0, 12, 0)
          ..direction = 'incoming'
          ..durationSeconds = 0
          ..isMissed = true
          ..followedUp = false
          ..linkedAppointmentId = null
          ..customerId = 3
          ..createdAt = now
          ..synced = false,
        CallLog()
          ..id = 4
          ..phoneNumber = '+1415555678'
          ..timestamp = _makeDate(-1, 16, 0)
          ..direction = 'outgoing'
          ..durationSeconds = 180
          ..isMissed = false
          ..followedUp = true
          ..linkedAppointmentId = null
          ..customerId = 4
          ..createdAt = now
          ..synced = false,
        CallLog()
          ..id = 5
          ..phoneNumber = '+1617555123'
          ..timestamp = _makeDate(-2, 10, 0)
          ..direction = 'incoming'
          ..durationSeconds = 90
          ..isMissed = false
          ..followedUp = true
          ..linkedAppointmentId = 5
          ..customerId = 5
          ..createdAt = now
          ..synced = false,
      ];
      for (var cl in callLogs) {
        await callLogBox.put(cl.id, cl);
      }

      // Verify data was written
      final customerCount = customerBox.length;
      final apptCount = appointmentBox.length;

      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Loaded $customerCount customers, $apptCount appointments')),
        );
      }
    } catch (e, st) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e\n$st')),
        );
      }
    }
  }

  DateTime _makeDate(int dayOffset, int hour, int minute) {
    final now = DateTime.now();
    final date = now.add(Duration(days: dayOffset));
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _getThemeSubtitle(WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
      case ThemeMode.system:
        return 'Follow system';
    }
  }

  void _showThemeSelector(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(themeModeProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('Appearance', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _ThemeOptionTile(
              icon: Icons.light_mode_outlined,
              title: 'Light',
              subtitle: 'Always use light theme',
              isSelected: currentMode == ThemeMode.light,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _ThemeOptionTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark',
              subtitle: 'Always use dark theme',
              isSelected: currentMode == ThemeMode.dark,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            _ThemeOptionTile(
              icon: Icons.settings_brightness_outlined,
              title: 'System',
              subtitle: 'Follow device settings',
              isSelected: currentMode == ThemeMode.system,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.app_settings_alt,
                  color: AppColors.onPrimaryContainer,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'In-Call Appointment Handler',
                style: AppTypography.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Version 1.0.0',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Developed by',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ash_Dilussi',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '© 2026 Ash_Dilussi. All rights reserved.',
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
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

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer.withOpacity(0.3)
                    : AppColors.surfaceContainerHigh,
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _HintTile extends StatelessWidget {
  final String hint;

  const _HintTile({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: const Icon(
              Icons.lightbulb_outline,
              color: AppColors.primaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              hint,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
