import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/app_init_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/app_launch_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoOpacity;
  bool _navigationScheduled = false;
  bool _errorScheduled = false;

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
    // Treat initialization completion as durable state. A transition-only
    // listener can miss a result that resolves before this screen subscribes.
    final appInit = ref.watch(appInitProvider);
    appInit.whenOrNull(
      data: (_) => _scheduleNavigation(),
      error: (error, _) => _scheduleError(error),
    );

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

  void _scheduleNavigation() {
    if (_navigationScheduled) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(appLaunchProvider);
      context.go('/entrance', extra: authState);
    });
  }

  void _scheduleError(Object error) {
    if (_errorScheduled) return;
    _errorScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Startup failed: $error')),
      );
    });
  }
}
