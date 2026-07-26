// test/core/entitlements/entitlement_test.dart
//
// Unit tests for the entitlement system core logic.
// Run with: flutter test test/core/entitlements/entitlement_test.dart
//
// These tests have ZERO external dependencies (no Firebase, no Hive, no Riverpod).
// They validate the pure business logic of plan_tier.dart and entitlement_state.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/core/entitlements/app_feature.dart';
import 'package:bookly/core/entitlements/plan_tier.dart';
import 'package:bookly/core/entitlements/entitlement_state.dart';

void main() {
  // ── PlanTier feature matrix ───────────────────────────────────────────────

  group('PlanTier.free', () {
    test('includes basic scheduling features', () {
      expect(PlanTier.free.includes(AppFeature.basicScheduling), isTrue);
      expect(PlanTier.free.includes(AppFeature.callLog), isTrue);
      expect(PlanTier.free.includes(AppFeature.basicReporting), isTrue);
    });

    test('does NOT include paid features', () {
      expect(PlanTier.free.includes(AppFeature.callRecording), isFalse);
      expect(PlanTier.free.includes(AppFeature.advancedAnalytics), isFalse);
      expect(PlanTier.free.includes(AppFeature.exportData), isFalse);
      expect(PlanTier.free.includes(AppFeature.multiUser), isFalse);
      expect(PlanTier.free.includes(AppFeature.customTheme), isFalse);
      expect(PlanTier.free.includes(AppFeature.apiAccess), isFalse);
      expect(PlanTier.free.includes(AppFeature.whiteLabel), isFalse);
      expect(PlanTier.free.includes(AppFeature.prioritySupport), isFalse);
    });

    test('isPaid is false', () {
      expect(PlanTier.free.isPaid, isFalse);
    });
  });

  group('PlanTier.pro', () {
    test('includes all free features (additive)', () {
      for (final f in PlanTier.free.allowedFeatures) {
        expect(PlanTier.pro.includes(f), isTrue,
            reason: '${f.name} should be included in pro');
      }
    });

    test('includes pro-specific features', () {
      expect(PlanTier.pro.includes(AppFeature.callRecording), isTrue);
      expect(PlanTier.pro.includes(AppFeature.advancedAnalytics), isTrue);
      expect(PlanTier.pro.includes(AppFeature.exportData), isTrue);
      expect(PlanTier.pro.includes(AppFeature.multiUser), isTrue);
      expect(PlanTier.pro.includes(AppFeature.customTheme), isTrue);
      expect(PlanTier.pro.includes(AppFeature.recurringScheduling), isTrue);
    });

    test('does NOT include enterprise features', () {
      expect(PlanTier.pro.includes(AppFeature.apiAccess), isFalse);
      expect(PlanTier.pro.includes(AppFeature.whiteLabel), isFalse);
      expect(PlanTier.pro.includes(AppFeature.prioritySupport), isFalse);
    });

    test('isPaid is true', () {
      expect(PlanTier.pro.isPaid, isTrue);
    });
  });

  group('PlanTier.enterprise', () {
    test('includes ALL features (superset)', () {
      for (final f in AppFeature.values) {
        expect(PlanTier.enterprise.includes(f), isTrue,
            reason: '${f.name} should be included in enterprise');
      }
    });
  });

  group('PlanTier.fromString', () {
    test('parses known tiers correctly', () {
      expect(PlanTier.fromString('pro'), PlanTier.pro);
      expect(PlanTier.fromString('enterprise'), PlanTier.enterprise);
      expect(PlanTier.fromString('free'), PlanTier.free);
    });

    test('defaults unknown/null to free', () {
      expect(PlanTier.fromString(null), PlanTier.free);
      expect(PlanTier.fromString(''), PlanTier.free);
      expect(PlanTier.fromString('PREMIUM'), PlanTier.free);
    });

    test('is case-insensitive', () {
      expect(PlanTier.fromString('PRO'), PlanTier.pro);
      expect(PlanTier.fromString('Pro'), PlanTier.pro);
    });
  });

  group('PlanTierX.minimumTierFor', () {
    test('returns free for free features', () {
      expect(
          PlanTierX.minimumTierFor(AppFeature.basicScheduling), PlanTier.free);
      expect(PlanTierX.minimumTierFor(AppFeature.callLog), PlanTier.free);
    });

    test('returns pro for pro features', () {
      expect(PlanTierX.minimumTierFor(AppFeature.callRecording), PlanTier.pro);
      expect(
          PlanTierX.minimumTierFor(AppFeature.advancedAnalytics), PlanTier.pro);
    });

    test('returns enterprise for enterprise features', () {
      expect(
          PlanTierX.minimumTierFor(AppFeature.apiAccess), PlanTier.enterprise);
      expect(
          PlanTierX.minimumTierFor(AppFeature.whiteLabel), PlanTier.enterprise);
    });
  });

  // ── EntitlementState.isEnabled() ─────────────────────────────────────────

  group('EntitlementState.loading()', () {
    final state = EntitlementState.loading();

    test('isLoading is true', () => expect(state.isLoading, isTrue));

    test('isEnabled always returns false (safe default during init)', () {
      for (final f in AppFeature.values) {
        expect(state.isEnabled(f), isFalse,
            reason: '${f.name} should be false while loading');
      }
    });

    test('isPaid is false', () => expect(state.isPaid, isFalse));
    test('effectiveTier is free',
        () => expect(state.effectiveTier, PlanTier.free));
  });

  group('EntitlementState — active pro plan', () {
    final state = EntitlementState(
      tier: PlanTier.pro,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    );

    test('free features are enabled', () {
      expect(state.isEnabled(AppFeature.callLog), isTrue);
      expect(state.isEnabled(AppFeature.basicReporting), isTrue);
    });

    test('pro features are enabled', () {
      expect(state.isEnabled(AppFeature.callRecording), isTrue);
      expect(state.isEnabled(AppFeature.advancedAnalytics), isTrue);
      expect(state.isEnabled(AppFeature.exportData), isTrue);
    });

    test('enterprise features are NOT enabled', () {
      expect(state.isEnabled(AppFeature.apiAccess), isFalse);
      expect(state.isEnabled(AppFeature.whiteLabel), isFalse);
    });

    test('isPaid is true', () => expect(state.isPaid, isTrue));
    test('isExpired is false', () => expect(state.isExpired, isFalse));
  });

  group('EntitlementState — strict expiry (plan expired)', () {
    final expiredState = EntitlementState(
      tier: PlanTier.pro,
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );

    test('pro features are DISABLED on expired plan', () {
      expect(expiredState.isEnabled(AppFeature.callRecording), isFalse);
      expect(expiredState.isEnabled(AppFeature.advancedAnalytics), isFalse);
      expect(expiredState.isEnabled(AppFeature.exportData), isFalse);
    });

    test('free features remain enabled on expired plan', () {
      expect(expiredState.isEnabled(AppFeature.basicScheduling), isTrue);
      expect(expiredState.isEnabled(AppFeature.callLog), isTrue);
    });

    test('isExpired is true', () => expect(expiredState.isExpired, isTrue));
    test('isPaid is false (expired counts as unpaid)', () {
      expect(expiredState.isPaid, isFalse);
    });
    test('effectiveTier reports free on expiry', () {
      expect(expiredState.effectiveTier, PlanTier.free);
    });
  });

  group('EntitlementState — admin override (Firebase console)', () {
    // Institution on free tier but with callRecording granted via Firebase override
    final stateWithOverride = EntitlementState(
      tier: PlanTier.free,
      overrides: {AppFeature.callRecording},
    );

    test('overridden feature is enabled despite free tier', () {
      expect(stateWithOverride.isEnabled(AppFeature.callRecording), isTrue);
    });

    test('non-overridden pro features are still locked', () {
      expect(
          stateWithOverride.isEnabled(AppFeature.advancedAnalytics), isFalse);
      expect(stateWithOverride.isEnabled(AppFeature.exportData), isFalse);
    });

    test('override wins even on expired plan', () {
      final expiredWithOverride = EntitlementState(
        tier: PlanTier.pro,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        overrides: {AppFeature.callRecording},
      );
      // Override beats expiry
      expect(expiredWithOverride.isEnabled(AppFeature.callRecording), isTrue);
      // Non-overridden pro feature still falls to free
      expect(
          expiredWithOverride.isEnabled(AppFeature.advancedAnalytics), isFalse);
    });
  });

  group('EntitlementState — no expiry (null expiresAt)', () {
    final perpetualPro = const EntitlementState(tier: PlanTier.pro);

    test('pro features enabled with no expiry date', () {
      expect(perpetualPro.isEnabled(AppFeature.callRecording), isTrue);
    });

    test('isExpired is false when expiresAt is null', () {
      expect(perpetualPro.isExpired, isFalse);
    });
  });
}
