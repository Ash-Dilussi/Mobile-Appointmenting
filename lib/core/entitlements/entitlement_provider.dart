// lib/core/entitlements/entitlement_provider.dart
//
// Single Riverpod provider that owns EntitlementState for the whole app.
// Bootstrap is called once from AppInitNotifier (step 5).
// Upgrade is called once after a successful Stripe/Paddle webhook confirmation.
//
// Every widget uses:
//   ref.watch(entitlementProvider.select((s) => s.isEnabled(AppFeature.X)))
// This selects a bool, so the widget only rebuilds when that specific feature
// changes — not on any other entitlement state mutation.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/subscription/data/subscription_repository.dart';
import '../../features/subscription/domain/subscription_plan.dart';
import '../../core/logging/logger_service.dart';
import 'app_feature.dart';
import 'entitlement_state.dart';
import 'plan_tier.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final entitlementProvider =
    NotifierProvider<EntitlementNotifier, EntitlementState>(
  EntitlementNotifier.new,
);

// ── Convenience selector providers (optional but handy in widgets) ────────────
// Usage: final canRecord = ref.watch(canUseProvider(AppFeature.callRecording));

final canUseProvider = Provider.family<bool, AppFeature>((ref, feature) {
  return ref.watch(
    entitlementProvider.select((s) => s.isEnabled(feature)),
  );
});

/// The current effective tier, accounting for expiry.
final currentTierProvider = Provider<PlanTier>((ref) {
  return ref.watch(entitlementProvider.select((s) => s.effectiveTier));
});

// ── Repository provider (override in tests) ───────────────────────────────────

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  // Provide the concrete implementation via ProviderScope.overrides in main.dart
  // after HiveService.subscriptionBox and FirebaseFirestore.instance are ready.
  throw UnimplementedError(
    'subscriptionRepositoryProvider must be overridden in ProviderScope',
  );
});

// ── Notifier ──────────────────────────────────────────────────────────────────

class EntitlementNotifier extends Notifier<EntitlementState> {
  @override
  EntitlementState build() => const EntitlementState.loading();

  // ── Bootstrap (called from AppInitNotifier step 5) ─────────────────────

  /// Resolves the startup plan for [institutionId] using a cache-first strategy.
  /// The returned future completes after the local cache is read; the remote
  /// refresh continues in the background so network latency never blocks app
  /// navigation.
  Future<void> bootstrap({required String institutionId}) async {
    final repo = ref.read(subscriptionRepositoryProvider);

    try {
      final cached = await repo.getCachedPlan(institutionId: institutionId);
      if (cached != null) {
        state = _planToState(cached);
        LoggerService.instance.log(
          LogLevel.info,
          'Entitlement',
          'Cache hit: ${cached.tier.displayName} for $institutionId',
        );
      } else {
        state = const EntitlementState(tier: PlanTier.free);
      }
    } catch (e, st) {
      LoggerService.instance.log(
        LogLevel.error,
        'Entitlement',
        'Cache bootstrap error for $institutionId — defaulting to free',
        error: e,
        stackTrace: st,
      );
      state = const EntitlementState(tier: PlanTier.free);
    }

    unawaited(_refreshRemote(institutionId: institutionId));
  }

  Future<void> _refreshRemote({required String institutionId}) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    try {
      final fresh = await repo.fetchPlan(institutionId: institutionId);
      state = _planToState(fresh);
      LoggerService.instance.log(
        LogLevel.info,
        'Entitlement',
        'Remote resolved: ${fresh.tier.displayName} for $institutionId'
            '${fresh.expiresAt != null ? " (expires ${fresh.expiresAt})" : ""}',
      );
    } catch (e, st) {
      LoggerService.instance.log(
        LogLevel.error,
        'Entitlement',
        'Remote refresh failed for $institutionId — keeping local state',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Sets free tier explicitly. Called for new institutions (no Firestore doc yet).
  void initFree() {
    state = const EntitlementState(tier: PlanTier.free);
    LoggerService.instance.log(
      LogLevel.info,
      'Entitlement',
      'New institution initialised on free tier',
    );
  }

  /// Called after Stripe/Paddle payment confirmed on device.
  void onUpgradeConfirmed({
    required PlanTier tier,
    required DateTime expiresAt,
  }) {
    // Preserve existing overrides if not loading, otherwise empty set
    final existingOverrides = state.isLoading
        ? <AppFeature>{}
        : state.when(
            (tier, expiresAt, overrides) => overrides,
            loading: () => <AppFeature>{},
          );

    state = EntitlementState(
      tier: tier,
      expiresAt: expiresAt.toUtc(),
      overrides: existingOverrides,
    );
    LoggerService.instance.log(
      LogLevel.info,
      'Entitlement',
      'Upgraded to ${tier.displayName} until $expiresAt',
    );
  }

  /// Re-bootstrap after session change (e.g. user switches institution).
  Future<void> refresh({required String institutionId}) =>
      _refreshRemote(institutionId: institutionId);

  EntitlementState _planToState(SubscriptionPlan plan) {
    return EntitlementState(
      tier: plan.tier,
      expiresAt: plan.expiresAt,
      overrides: plan.overrides.toSet(),
    );
  }
}
