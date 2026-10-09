import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/release_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/service_color_palette.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../../core/providers/auth_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _handleSignOut() async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await ref.read(authNotifierProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final session = ref.watch(authSessionProvider);
    final hasNoBusiness = session != null && !session.hasInstitution;

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        context.go('/login');
      }
    });

    return Scaffold(
      backgroundColor: colors.surface,
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
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: session?.name?.isNotEmpty == true
                      ? session!.name!
                      : 'Profile',
                  subtitle: session?.email ?? 'Manage your account details',
                  onTap: () {
                    context.goNamed('profile-setup');
                  },
                ),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () {
                    context.goNamed('change-password');
                  },
                ),
                _SettingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete account',
                  subtitle: 'Permanently delete your Bookly account',
                  destructive: true,
                  onTap: () => context.pushNamed('delete-account'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // App Preferences Section
            Text(
              'App Preferences',
              style: AppTypography.titleSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                if (ReleaseScope.developmentOnlyDestinationsEnabled)
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage notification settings',
                    onTap: () => _openComingSoon(context, 'Notifications'),
                  ),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: _getThemeSubtitle(ref),
                  onTap: () => _showThemeSelector(context, ref),
                ),
              ],
            ),

            if (ReleaseScope.googleCalendarSyncEnabled) ...[
              const SizedBox(height: AppSpacing.xl),

              // Calendar Integration Section
              Text(
                'Calendar Integration',
                style: AppTypography.titleSmall.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _SettingsCard(
                children: [
                  Consumer(builder: (context, ref, _) {
                    final authService = ref.watch(googleAuthServiceProvider);
                    final isSignedIn = authService.isSignedIn;
                    return _SettingsTile(
                      icon: Icons.calendar_month_rounded,
                      title: 'Google Calendar',
                      subtitle: isSignedIn
                          ? '${authService.currentUser?.email}'
                          : 'Sign in to sync appointments',
                      onTap: () async {
                        if (isSignedIn) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text(
                                  'Are you sure you want to sign out from Google Calendar?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await authService.signOut();
                          }
                        } else {
                          final account = await authService.signIn();
                          if (account == null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Sign in cancelled')),
                            );
                          }
                        }
                      },
                    );
                  }),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Business Management Section
            Text(
              'Business Management',
              style: AppTypography.titleSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.insights_outlined,
                  title: 'Insights',
                  subtitle: 'View business performance',
                  onTap: () {
                    context.goNamed('insights');
                  },
                ),
                if (hasNoBusiness) ...[
                  _SettingsTile(
                    icon: Icons.business,
                    title: 'Set Up Business',
                    subtitle: 'Choose solo or team setup to get started',
                    onTap: () {
                      context.goNamed('business-setup');
                    },
                  ),
                ] else ...[
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
                    title: 'Service Locations',
                    subtitle: 'Add, edit, or remove service locations',
                    onTap: () {
                      context.goNamed('station-management');
                    },
                  ),
                  if (session?.isOwner == true)
                    _SettingsTile(
                      icon: Icons.people_outline,
                      title: 'Staff Management',
                      subtitle: 'Manage staff members',
                      onTap: () {
                        context.goNamed('staff-management');
                      },
                    ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Help & Support Section
            Text(
              'Help & Support',
              style: AppTypography.titleSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                if (ReleaseScope.developmentOnlyDestinationsEnabled)
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: 'Help Center',
                    subtitle: 'FAQs and guides',
                    onTap: () => _openComingSoon(context, 'Help Center'),
                  ),
                _SettingsTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Contact Support',
                  subtitle: 'Email bookly.support@gmail.com',
                  onTap: () => _contactSupport(context),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Tips & Hints Section
            Text(
              'Tips & Hints',
              style: AppTypography.titleSmall.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCard(
              children: [
                const _HintTile(
                  hint:
                      'When a call comes in, tap "Book Now" to quickly schedule an appointment',
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.xxl,
                    color: colors.outlineVariant),
                const _HintTile(
                  hint:
                      'Use the calendar view to see your entire schedule at a glance',
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.xxl,
                    color: colors.outlineVariant),
                const _HintTile(
                  hint: 'Search for existing customers by name or phone number',
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.xxl,
                    color: colors.outlineVariant),
                const _HintTile(
                  hint: 'Calls started from Bookly appear in Call History',
                ),
                Divider(
                    height: 1,
                    indent: AppSpacing.xxl,
                    color: colors.outlineVariant),
                const _HintTile(
                  hint:
                      'Your data is stored locally and works even without internet',
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // About Section
            Text(
              'About',
              style: AppTypography.titleSmall.copyWith(
                color: colors.onSurfaceVariant,
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
                if (ReleaseScope.developmentOnlyDestinationsEnabled) ...[
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => _openComingSoon(context, 'Terms of Service'),
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => _openComingSoon(context, 'Privacy Policy'),
                  ),
                ],
              ],
            ),

            if (ReleaseScope.developmentOnlyDestinationsEnabled) ...[
              const SizedBox(height: AppSpacing.xl),

              // Destructive sample data tooling is never shown in release.
              Text(
                'Developer Tools',
                style: AppTypography.titleSmall.copyWith(
                  color: colors.onSurfaceVariant,
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
            ],

            const SizedBox(height: AppSpacing.xl),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _handleSignOut(),
                icon: Icon(Icons.logout, color: colors.error),
                label: Text(
                  'Sign Out',
                  style: AppTypography.labelLarge.copyWith(
                    color: colors.error,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.error),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  void _openComingSoon(BuildContext context, String featureName) {
    context.pushNamed(
      'coming-soon',
      queryParameters: {'feature': featureName},
    );
  }

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'bookly.support@gmail.com',
      queryParameters: const {'subject': 'Bookly support request'},
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email app is available on this device.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open an email app.'),
          ),
        );
      }
    }
  }

  Future<void> _seedSampleData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ensure adapters are registered
      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(CustomerNoteAdapter());
      }
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
      CustomerNote customerNote(String id, String title) => CustomerNote(
            id: id,
            title: title,
            createdAt: now,
            updatedAt: now,
          );

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
          ..notes = [customerNote('sample-note-1', 'Morning person')]
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 2
          ..phoneNumber = '+1987654321'
          ..name = 'Bob Smith'
          ..email = 'bob@email.com'
          ..notes = [customerNote('sample-note-2', 'Regular client')]
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 3
          ..phoneNumber = '+1555123456'
          ..name = 'Carol Davis'
          ..email = 'carol@email.com'
          ..notes = [customerNote('sample-note-3', 'New customer')]
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 4
          ..phoneNumber = '+1415555678'
          ..name = 'David Wilson'
          ..email = 'david@email.com'
          ..notes = [customerNote('sample-note-4', 'Afternoon')]
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Customer()
          ..id = 5
          ..phoneNumber = '+1617555123'
          ..name = 'Emma Brown'
          ..email = 'emma@email.com'
          ..notes = [customerNote('sample-note-5', 'VIP')]
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
          ..colorValue = ServiceColorPalette.options[5].argbValue
          ..defaultDurationMinutes = 30
          ..cost = 50.0
          ..description = 'Standard haircut'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 2
          ..title = 'Hair Coloring'
          ..colorValue = ServiceColorPalette.options[0].argbValue
          ..defaultDurationMinutes = 90
          ..cost = 150.0
          ..description = 'Full coloring'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 3
          ..title = 'Massage'
          ..colorValue = ServiceColorPalette.options[7].argbValue
          ..defaultDurationMinutes = 60
          ..cost = 80.0
          ..description = 'Relaxing massage'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 4
          ..title = 'Manicure'
          ..colorValue = ServiceColorPalette.options[8].argbValue
          ..defaultDurationMinutes = 45
          ..cost = 40.0
          ..description = 'Nail care'
          ..createdAt = now
          ..updatedAt = now
          ..synced = false,
        Service()
          ..id = 5
          ..title = 'Consultation'
          ..colorValue = ServiceColorPalette.options[4].argbValue
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
          ..notes = [
            AppointmentNote(
              id: 'sample-appointment-note-1',
              title: 'Follow-up',
              description: 'Follow-up massage',
              createdAt: now,
              updatedAt: now,
            ),
          ]
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
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _ThemeOptionTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark',
              subtitle: 'Always use dark theme',
              isSelected: currentMode == ThemeMode.dark,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            _ThemeOptionTile(
              icon: Icons.settings_brightness_outlined,
              title: 'System',
              subtitle: 'Follow device settings',
              isSelected: currentMode == ThemeMode.system,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system);
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
    final colors = Theme.of(context).colorScheme;
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
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.app_settings_alt,
                  color: colors.onPrimaryContainer,
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
                  color: colors.primary,
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
                    color: colors.primary,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
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
                color: colors.outlineVariant,
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
  final bool destructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final iconBackground =
        destructive ? colors.errorContainer : colors.primaryContainer;
    final iconForeground =
        destructive ? colors.onErrorContainer : colors.onPrimaryContainer;
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
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: iconForeground, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: destructive ? colors.error : colors.onSurface,
                    ),
                  ),
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
            Icon(
              Icons.chevron_right,
              color: colors.onSurfaceVariant,
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
    final colors = Theme.of(context).colorScheme;
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
                    ? colors.primaryContainer
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(icon, color: colors.primary, size: 20),
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
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check, color: colors.primary, size: 20),
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              Icons.lightbulb_outline,
              color: colors.primary,
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
