// lib/core/entitlements/entitlement_state.dart
//
// Immutable value object. All feature checks in the app flow through
// EntitlementState.isEnabled(). It is synchronous by design — resolved once
// at startup, then read from memory everywhere.
//
// Code generation: run `flutter pub run build_runner build --delete-conflicting-outputs`

import 'package:freezed_annotation/freezed_annotation.dart';
import 'app_feature.dart';
import 'plan_tier.dart';

part 'entitlement_state.freezed.dart';

@freezed
class EntitlementState with _$EntitlementState {
  // ── Resolved state (normal runtime state) ───────────────────────────────
  const factory EntitlementState({
    required PlanTier tier,

    /// UTC expiry from Firebase. null = no expiry (lifetime / manual plans).
    DateTime? expiresAt,

    /// Firebase-console-managed per-institution feature overrides.
    /// An override grants a feature regardless of tier or expiry.
    /// Stored as a Set<AppFeature> to allow O(1) lookup.
    @Default(<AppFeature>{}) Set<AppFeature> overrides,
  }) = _EntitlementResolved;

  // ── Loading sentinel (before bootstrap completes) ─────────────────────────
  // All isEnabled() calls return false while loading → UI shows locked state.
  const factory EntitlementState.loading() = _EntitlementLoading;

  // ── Required for custom methods on a freezed class ────────────────────────
  const EntitlementState._();

  // ── Core check — the only method widgets and services should call ─────────

  /// Returns true if the current institution may use [feature].
  ///
  /// Resolution order (highest priority first):
  ///   1. Loading sentinel  → false (safe default during init)
  ///   2. Admin override    → true  (Firebase console can unlock any feature)
  ///   3. Plan expired      → strict drop to free tier (no grace period)
  ///   4. Tier matrix       → standard lookup
  bool isEnabled(AppFeature feature) {
    // 1. Loading guard
    if (this is _EntitlementLoading) return false;

    // Cast to resolved variant to access properties
    final resolved = this as _EntitlementResolved;

    // 2. Admin override wins unconditionally
    if (resolved.overrides.contains(feature)) return true;

    // 3. Strict expiry — drop immediately, no grace period
    if (resolved._isExpired) {
      return PlanTier.free.includes(feature);
    }

    // 4. Standard tier lookup
    return resolved.tier.includes(feature);
  }

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isLoading => this is _EntitlementLoading;

  bool get isPaid {
    if (isLoading) return false;
    final resolved = this as _EntitlementResolved;
    return resolved.tier.isPaid && !resolved._isExpired;
  }

  bool get isExpired {
    if (isLoading) return false;
    final resolved = this as _EntitlementResolved;
    return resolved._isExpired;
  }

  /// Effective tier accounting for expiry — use in UI display (e.g. plan badge).
  PlanTier get effectiveTier {
    if (isLoading) return PlanTier.free;
    final resolved = this as _EntitlementResolved;
    if (resolved._isExpired) return PlanTier.free;
    return resolved.tier;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool get _isExpired {
    if (this is _EntitlementLoading) return false;
    final resolved = this as _EntitlementResolved;
    return resolved.expiresAt != null &&
        DateTime.now().toUtc().isAfter(resolved.expiresAt!);
  }
}
