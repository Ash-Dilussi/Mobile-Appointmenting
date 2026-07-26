// lib/features/subscription/data/subscription_repository.dart
//
// Abstract interface — depends only on domain types.
// Concrete implementation is in subscription_repository_impl.dart.

import '../../../core/entitlements/plan_tier.dart';
import '../domain/subscription_plan.dart';

abstract class SubscriptionRepository {
  /// Returns the cached plan immediately (may be stale).
  /// Returns null if no cache exists yet.
  Future<SubscriptionPlan?> getCachedPlan({required String institutionId});

  /// Fetches fresh plan from Firestore and updates the Hive cache.
  /// Throws on network failure — caller handles the fallback.
  Future<SubscriptionPlan> fetchPlan({required String institutionId});

  /// Called by the webhook handler (Cloud Function) or manually after
  /// a Stripe/Paddle webhook confirms payment. Writes to both Hive + Firestore.
  Future<void> activatePlan({
    required String institutionId,
    required PlanTier tier,
    required DateTime expiresAt,
    String? stripeSubscriptionId,
    String? paddleSubscriptionId,
  });
}
