import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/app_launch_provider.dart';
import '../../../../core/providers/app_init_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch appInitProvider — navigates once initialization completes
    ref.listen<AsyncValue<bool>>(appInitProvider, (_, next) {
      next.whenOrNull(
        data: (_) {
          // Init done — now check auth state and navigate
          final authState = ref.read(appLaunchProvider);
          context.go('/entrance', extra: authState);
        },
        error: (e, st) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Startup failed: $e')),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: _logoOpacity,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.business_center,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}