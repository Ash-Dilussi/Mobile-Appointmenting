import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_options.dart';
import '../../core/database/hive_service.dart';
import '../../core/hive/hive_initializer.dart';
import '../../core/logging/logger_service.dart';
import '../../seed_dummy_data.dart';

// New imports for entitlements step
import '../../features/subscription/data/subscription_repository.dart';
import '../../core/entitlements/entitlement_provider.dart';
import '../../core/entitlements/plan_tier.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';

/// Tracks the initialization state of the app.
/// SplashScreen watches this and navigates when it reaches AsyncData.
final appInitProvider =
    AsyncNotifierProvider<AppInitNotifier, bool>(AppInitNotifier.new);

class AppInitNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // 1. Firebase — already initialized in main() before runApp()
    // 2. Hive — already initialized in main() before runApp()
    // Both are safe to access here via their singletons.

    // 2b. Auth cache box — opened separately by HiveInitializer
    try {
      await HiveInitializer.init();
      logger.info('AppInit', 'HiveInitializer (auth_cache) initialized');
    } catch (e, st) {
      logger.error('AppInit', 'HiveInitializer init failed: $e',
          error: e, stackTrace: st);
      rethrow; // auth_cache is required — surface the error
    }

    // 3. Seed dummy data (dev/debug builds only)
    assert(() {
      seedDummyData(HiveService.instance, force: true);
      return true;
    }());

    // 4. Clean old logs — non-critical, run last
    try {
      await logger.cleanOldLogs(keepDays: 7);
      logger.info('AppInit', 'Old logs cleaned');
    } catch (_) {
      // Never block startup for log cleanup
    }

    // 4c. Backfill call log customer links — non-critical, run after Hive init
    try {
      await HiveService.instance.backfillCallLogCustomerLinks();
      logger.info('AppInit', 'Call log customer links backfilled');
    } catch (_) {
      // Never block startup for backfill
    }

    // ── STEP 5 (NEW) — Entitlements ──────────────────────────────────────────
    // Must run AFTER Firebase (step 1) and Hive (step 2) are ready.
    // Must NEVER rethrow — free tier is always the safe fallback.
    // Follows the same error-tolerant pattern as step 1.
    try {
      final session = ref.read(authSessionProvider);

      if (session?.institutionId != null) {
        await ref
            .read(entitlementProvider.notifier)
            .bootstrap(institutionId: session!.institutionId!);

        logger.info(
          'AppInit',
          'Entitlements loaded: '
              '${ref.read(entitlementProvider).effectiveTier.displayName} '
              'for institution ${session.institutionId}',
        );
      } else {
        // New user who hasn't created a company yet.
        // entitlementProvider remains in loading state here;
        // CreateCompanyScreen calls initFree() + bootstrap() after company creation.
        logger.info(
          'AppInit',
          'No institutionId in session — entitlement stays loading '
              '(will resolve after company creation)',
        );
        // Safe-guard: if no institution, explicitly set free so UI is never stuck
        ref.read(entitlementProvider.notifier).initFree();
      }
    } catch (e, st) {
      // Should never reach here (bootstrap() swallows its own errors),
      // but belt-and-suspenders: log and default to free.
      logger.error(
        'AppInit',
        'Unexpected entitlement error — free tier applied',
        error: e,
        stackTrace: st,
      );
      ref.read(entitlementProvider.notifier).initFree();
    }
    // ── END STEP 5 ────────────────────────────────────────────────────────────

    return true; // AsyncData(true) → SplashScreen navigates
  }
}
