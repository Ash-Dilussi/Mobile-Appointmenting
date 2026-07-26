// lib/features/subscription/domain/subscription_plan.dart
//
// Pure domain model — no Firebase/Hive imports. Serialization lives in the
// data layer (subscription_repository_impl.dart).

import '../../../core/entitlements/app_feature.dart';
import '../../../core/entitlements/plan_tier.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.institutionId,
    required this.tier,
    this.expiresAt,
    this.overrides = const [],
    this.stripeSubscriptionId,
    this.paddleSubscriptionId,
  });

  final String institutionId;
  final PlanTier tier;

  /// UTC expiry. null = no expiry.
  final DateTime? expiresAt;

  /// Firebase-console-managed override list (feature names as strings).
  /// Converted to Set<AppFeature> in EntitlementState.
  final List<AppFeature> overrides;

  /// Stored for webhook reconciliation — never used for access control.
  final String? stripeSubscriptionId;
  final String? paddleSubscriptionId;

  // ── Serialization (called by repository impl) ─────────────────────────────

  /// From Firestore document data at `institutions/{id}/subscription`
  factory SubscriptionPlan.fromFirestore({
    required String institutionId,
    required Map<String, dynamic> data,
  }) {
    final overrideStrings = (data['overrides'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();

    final overrideFeatures = overrideStrings
        .map((s) => _featureFromString(s))
        .whereType<AppFeature>()
        .toList();

    return SubscriptionPlan(
      institutionId: institutionId,
      tier: PlanTier.fromString(data['tier'] as String?),
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as dynamic).toDate() as DateTime
          : null,
      overrides: overrideFeatures,
      stripeSubscriptionId: data['stripeSubscriptionId'] as String?,
      paddleSubscriptionId: data['paddleSubscriptionId'] as String?,
    );
  }

  /// For Hive JSON cache (`Box<String>` → `jsonEncode(toJson())`)
  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      institutionId: json['institutionId'] as String,
      tier: PlanTier.fromString(json['tier'] as String?),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      overrides: (json['overrides'] as List<dynamic>? ?? [])
          .whereType<String>()
          .map(_featureFromString)
          .whereType<AppFeature>()
          .toList(),
      stripeSubscriptionId: json['stripeSubscriptionId'] as String?,
      paddleSubscriptionId: json['paddleSubscriptionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'institutionId': institutionId,
        'tier': tier.toJson(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'overrides': overrides.map((f) => f.name).toList(),
        'stripeSubscriptionId': stripeSubscriptionId,
        'paddleSubscriptionId': paddleSubscriptionId,
      };

  /// Free-tier fallback used when no Firestore document exists yet.
  factory SubscriptionPlan.freeTier(String institutionId) => SubscriptionPlan(
        institutionId: institutionId,
        tier: PlanTier.free,
      );

  // ── Private helpers ───────────────────────────────────────────────────────

  static AppFeature? _featureFromString(String s) {
    try {
      return AppFeature.values.firstWhere((f) => f.name == s);
    } catch (_) {
      return null; // unknown feature string → skip silently
    }
  }
}
