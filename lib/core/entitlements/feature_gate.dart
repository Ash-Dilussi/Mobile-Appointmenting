// lib/core/entitlements/feature_gate.dart
//
// FeatureGate — wraps any widget and conditionally shows it or a lock UI.
// Uses .select() so each gate widget only rebuilds when its specific feature
// boolean changes — not on any other entitlement mutation.
//
// Usage patterns:
//
//   // A: Wrap a widget — shows lock badge when not entitled
//   FeatureGate(
//     feature: AppFeature.callRecording,
//     child: RecordingToggle(),
//   )
//
//   // B: Custom fallback (e.g. hide entirely instead of showing a lock)
//   FeatureGate(
//     feature: AppFeature.exportData,
//     fallback: const SizedBox.shrink(),
//     child: ExportButton(),
//   )
//
//   // C: Imperative guard (in onTap / route guard)
//   if (!ref.read(entitlementProvider).isEnabled(AppFeature.advancedAnalytics)) {
//     UpgradeBottomSheet.show(context, feature: AppFeature.advancedAnalytics);
//     return;
//   }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_feature.dart';
import 'entitlement_provider.dart';
import 'plan_tier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeatureGate
// ─────────────────────────────────────────────────────────────────────────────

class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.fallback,
    this.showPaywallOnTap = true,
    this.showLockBadge = true,
  });

  final AppFeature feature;
  final Widget child;

  /// Custom widget shown when the feature is locked.
  /// If null, shows the default [_LockedFeatureBadge].
  final Widget? fallback;

  /// If true, tapping the locked state navigates to the upgrade screen.
  final bool showPaywallOnTap;

  /// If true and [fallback] is null, shows the lock icon overlay.
  /// Set to false to make the gate invisible (no lock badge shown).
  final bool showLockBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // .select() → O(1) bool comparison → minimal rebuilds
    final enabled = ref.watch(
      entitlementProvider.select((s) => s.isEnabled(feature)),
    );

    if (enabled) return child;

    if (fallback != null) return fallback!;

    if (!showLockBadge) return const SizedBox.shrink();

    return _LockedFeatureBadge(
      feature: feature,
      showPaywallOnTap: showPaywallOnTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LockedFeatureBadge
// Default locked state: greyed child with lock chip overlay.
// ─────────────────────────────────────────────────────────────────────────────

class _LockedFeatureBadge extends StatelessWidget {
  const _LockedFeatureBadge({
    required this.feature,
    required this.showPaywallOnTap,
  });

  final AppFeature feature;
  final bool showPaywallOnTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: showPaywallOnTap
          ? () => UpgradeBottomSheet.show(context, feature: feature)
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 20,
              color: AppColors.secondary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                feature.displayName,
                style: TextStyle(
                  color: AppColors.secondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _UpgradeChip(feature: feature),
          ],
        ),
      ),
    );
  }
}

class _UpgradeChip extends StatelessWidget {
  const _UpgradeChip({required this.feature});
  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final requiredTier = PlanTierX.minimumTierFor(feature);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        '${requiredTier.displayName} ↑',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UpgradeBottomSheet
// ─────────────────────────────────────────────────────────────────────────────

class UpgradeBottomSheet {
  static void show(BuildContext context, {required AppFeature feature}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeSheet(feature: feature),
    );
  }
}

class _UpgradeSheet extends StatelessWidget {
  const _UpgradeSheet({required this.feature});
  final AppFeature feature;

  @override
  Widget build(BuildContext context) {
    final requiredTier = PlanTierX.minimumTierFor(feature);

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 32, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                feature.displayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                feature.upgradeReason,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.secondary, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/upgrade',
                      extra: {'triggerFeature': feature.name});
                },
                child: Text('Upgrade to ${requiredTier.displayName}'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Maybe Later'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
