import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/app_launch_provider.dart';
import '../../domain/entities/auth_user.dart';

class EntranceScreen extends ConsumerStatefulWidget {
  final AppLaunchState launchState;
  const EntranceScreen({super.key, required this.launchState});

  @override
  ConsumerState<EntranceScreen> createState() => _EntranceScreenState();
}

class _EntranceScreenState extends ConsumerState<EntranceScreen>
    with TickerProviderStateMixin {
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
      begin: const Offset(0, 0.08), // subtle upward slide
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    _slideController.forward().then((_) => _navigate());
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _navigate() {
    if (!mounted) return;
    switch (widget.launchState) {
      case AppLaunchAuthenticated():
        context.go('/home');
      case AppLaunchUnauthenticated():
        context.go('/login');
      case AppLaunchError(:final message):
        context.go('/login', extra: {'error': message});
      case AppLaunchChecking():
        // Still checking — stay on this screen, animation continues
        // When splash resolves, it will call this again with a new state
        // But since we already forwarded, use a delayed re-check
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) context.go('/entrance', extra: widget.launchState);
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return switch (widget.launchState) {
      AppLaunchAuthenticated(:final user) => _WelcomeBackView(user: user),
      AppLaunchUnauthenticated() => const _WelcomeNewView(),
      AppLaunchChecking() => const _LoadingView(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _WelcomeBackView extends StatelessWidget {
  final AuthUser user;
  const _WelcomeBackView({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.business_center, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome back',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.displayName.isNotEmpty ? user.displayName : user.email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.secondary,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.business_center, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onSurface,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.business_center, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading…',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}