// lib/core/entitlements/plan_tier.dart
//
// FEATURE MATRIX — the only place that maps tier → allowed features.
// Adding a new feature to a tier = one line change here. Nothing else changes.

import 'app_feature.dart';

enum PlanTier {
  free,
  pro,
  enterprise;

  /// Firestore serialization: stored as lowercase string e.g. "pro"
  static PlanTier fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'pro':
        return PlanTier.pro;
      case 'enterprise':
        return PlanTier.enterprise;
      default:
        return PlanTier.free; // unknown / null → safe default
    }
  }

  String toJson() => name; // 'free' | 'pro' | 'enterprise'
}

extension PlanTierX on PlanTier {
  // ── Human-readable display ───────────────────────────────────────────────

  String get displayName {
    switch (this) {
      case PlanTier.free:
        return 'Free';
      case PlanTier.pro:
        return 'Pro';
      case PlanTier.enterprise:
        return 'Enterprise';
    }
  }

  // ── Feature matrix ───────────────────────────────────────────────────────
  // Defined as a const Set for O(1) lookup. Tiers are additive — each tier
  // contains everything below it plus its own extras.

  Set<AppFeature> get allowedFeatures {
    switch (this) {
      case PlanTier.free:
        return const {
          AppFeature.basicScheduling,
          AppFeature.callLog,
          AppFeature.basicReporting,
        };

      case PlanTier.pro:
        return {
          // inherits all free features
          ...PlanTier.free.allowedFeatures,
          // pro-exclusive additions
          AppFeature.callRecording,
          AppFeature.advancedAnalytics,
          AppFeature.exportData,
          AppFeature.multiUser,
          AppFeature.customTheme,
          AppFeature.recurringScheduling,
        };

      case PlanTier.enterprise:
        return {
          // inherits all pro features
          ...PlanTier.pro.allowedFeatures,
          // enterprise-exclusive additions
          AppFeature.apiAccess,
          AppFeature.whiteLabel,
          AppFeature.prioritySupport,
        };
    }
  }

  /// O(1) membership check — the hot path called by EntitlementState.isEnabled()
  bool includes(AppFeature feature) => allowedFeatures.contains(feature);

  bool get isPaid => this != PlanTier.free;

  /// The minimum tier required to use [feature].
  /// Used by UpgradeScreen to show the correct CTA tier.
  static PlanTier minimumTierFor(AppFeature feature) {
    if (PlanTier.free.includes(feature)) return PlanTier.free;
    if (PlanTier.pro.includes(feature)) return PlanTier.pro;
    return PlanTier.enterprise;
  }
}
