import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/auth_user.dart';
import '../providers/app_launch_provider.dart';

class EntranceScreen extends ConsumerStatefulWidget {
  const EntranceScreen({super.key, required this.launchState});

  final AppLaunchState launchState;

  @override
  ConsumerState<EntranceScreen> createState() => _EntranceScreenState();
}

class _EntranceScreenState extends ConsumerState<EntranceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _slideController.value = 1;
        _navigate();
      } else {
        _slideController.forward().then((_) => _navigate());
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _routeResolved(AppLaunchState state) {
    if (!mounted) return;
    switch (state) {
      case AppLaunchAuthenticated(:final user):
        context.go(
          user.isLinkedToInstitution ? '/home' : '/business/setup',
        );
      case AppLaunchUnauthenticated():
        context.go('/login');
      case AppLaunchError(:final message):
        context.go('/login', extra: {'error': message});
      case AppLaunchChecking():
        _navigate();
    }
  }

  void _navigate() {
    if (!mounted) return;
    final state = widget.launchState;
    if (state is! AppLaunchChecking) {
      _routeResolved(state);
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _routeResolved(ref.read(appLaunchProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: switch (widget.launchState) {
            AppLaunchAuthenticated(:final user) => _WelcomeBackView(user: user),
            AppLaunchUnauthenticated() => const _WelcomeNewView(),
            AppLaunchChecking() => const _LoadingView(),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        Icons.business_center,
        size: 48,
        color: colors.onPrimaryContainer,
      ),
    );
  }
}

class _WelcomeBackView extends StatelessWidget {
  const _WelcomeBackView({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandMark(),
          const SizedBox(height: 24),
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            user.displayName.isNotEmpty ? user.displayName : user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeNewView extends StatelessWidget {
  const _WelcomeNewView();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandMark(),
          const SizedBox(height: 24),
          Text(
            'Welcome',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandMark(),
          const SizedBox(height: 24),
          Text(
            'Loading…',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onSurface,
                ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}
