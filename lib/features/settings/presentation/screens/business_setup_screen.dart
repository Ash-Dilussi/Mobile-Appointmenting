import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/release_scope.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/style_preset.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/widgets/account_setup_recovery.dart';
import '../../application/business_provisioning_service.dart';

class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() =>
      _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  bool _isCreating = false;
  bool _isConnectingCalendar = false;
  bool _calendarConnected = false;
  String? _createdBusinessName;
  String? _recoveryMessage;
  String? _pendingSoloName;

  Future<void> _createSoloBusiness() async {
    final session = ref.read(authSessionProvider);
    if (session == null || _isCreating) return;

    setState(() {
      _isCreating = true;
      _recoveryMessage = null;
    });
    try {
      final name = _pendingSoloName ??
          defaultSoloBusinessName(
            displayName: session.name,
            email: session.email,
          );
      _pendingSoloName = name;
      final business =
          await ref.read(businessProvisioningServiceProvider).provision(
            session: session,
            name: name,
            themePreset: StylePreset.solarOrange.name,
          );
      if (mounted) {
        setState(() {
          _createdBusinessName = business.name;
          _recoveryMessage = null;
        });
      }
    } on BusinessProvisioningRecoveryRequired catch (error) {
      if (mounted) {
        setState(() => _recoveryMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryMessage =
              'We could not finish setting up your business. Your account is safe, and you can retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _connectCalendar() async {
    if (_isConnectingCalendar) return;
    setState(() => _isConnectingCalendar = true);
    try {
      final account = await ref.read(googleAuthServiceProvider).signIn();
      if (!mounted) return;
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar sign-in cancelled.')),
        );
      } else {
        setState(() => _calendarConnected = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar connected.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnectingCalendar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Set up Bookly'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  minHeight:
                      constraints.maxHeight - (AppSpacing.screenPadding * 2),
                ),
                child: _recoveryMessage != null
                    ? AccountSetupRecovery(
                        message: _recoveryMessage!,
                        onRetry: _createSoloBusiness,
                        isRetrying: _isCreating,
                      )
                    : _createdBusinessName == null
                        ? _buildChoice(context)
                        : _buildReady(context, _createdBusinessName!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoice(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.auto_awesome_outlined, size: 56, color: colors.primary),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'How will you use Bookly?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Choose what fits today. You can add staff later without moving your data.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _SetupChoiceCard(
          icon: Icons.person_outline,
          title: 'Just me',
          description:
              'Start immediately with appointments, customers, services, and service locations.',
          enabled: !_isCreating,
          trailing: _isCreating
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _createSoloBusiness,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SetupChoiceCard(
          icon: Icons.groups_outlined,
          title: 'My team',
          description:
              'Enter your business details and manage staff from the start.',
          enabled: !_isCreating,
          onTap: () => context.pushNamed('create-company'),
        ),
      ],
    );
  }

  Widget _buildReady(BuildContext context, String businessName) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Icon(Icons.check_circle_outline, size: 64, color: colors.primary),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Your business is ready',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We set it up as “$businessName”. You can rename it anytime in Settings.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
        if (ReleaseScope.googleCalendarSyncEnabled) ...[
          const SizedBox(height: AppSpacing.xxxl),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _calendarConnected
                            ? Icons.check_circle_outline
                            : Icons.calendar_month_outlined,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _calendarConnected
                              ? 'Google Calendar connected'
                              : 'Bring in your Google Calendar',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _calendarConnected
                        ? 'You can manage this connection anytime from Settings.'
                        : 'Connect now to sync appointments, or do this later from Settings.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!_calendarConnected)
                    OutlinedButton(
                      onPressed:
                          _isConnectingCalendar ? null : _connectCalendar,
                      child: _isConnectingCalendar
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect Google Calendar'),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        FilledButton(
          onPressed: () => context.goNamed('home'),
          child: const Text('Continue to Bookly'),
        ),
        if (ReleaseScope.googleCalendarSyncEnabled && !_calendarConnected)
          TextButton(
            onPressed: () => context.goNamed('home'),
            child: const Text('Not now'),
          ),
      ],
    );
  }
}

class _SetupChoiceCard extends StatelessWidget {
  const _SetupChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.enabled = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $description',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 116),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  Icon(icon, size: 32, color: colors.primary),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          description,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  trailing ?? Icon(Icons.chevron_right, color: colors.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
