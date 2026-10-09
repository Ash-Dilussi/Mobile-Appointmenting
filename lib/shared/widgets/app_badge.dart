import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class AppBadgePresentation {
  const AppBadgePresentation({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

AppBadgePresentation callStatusPresentation(
  String status,
  ColorScheme colors,
) {
  return switch (status.trim().toLowerCase()) {
    'incoming' => AppBadgePresentation(
        label: 'Incoming',
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
      ),
    'outgoing' => AppBadgePresentation(
        label: 'Outgoing',
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
    'initiated' => AppBadgePresentation(
        label: 'Call initiated',
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
      ),
    'missed' => AppBadgePresentation(
        label: 'Missed',
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      ),
    'completed' => AppBadgePresentation(
        label: 'Completed',
        backgroundColor: colors.surfaceContainerHighest,
        foregroundColor: colors.onSurface,
      ),
    'live' => AppBadgePresentation(
        label: 'Live',
        backgroundColor: colors.tertiaryContainer,
        foregroundColor: colors.onTertiaryContainer,
      ),
    _ => AppBadgePresentation(
        label: status.trim().isEmpty ? 'Unknown' : status.trim(),
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurfaceVariant,
      ),
  };
}

AppBadgePresentation callLogStatusPresentation({
  required bool isMissed,
  required String direction,
  required ColorScheme colors,
}) {
  return callStatusPresentation(isMissed ? 'missed' : direction, colors);
}

AppBadgePresentation staffStatusPresentation(
  String status,
  ColorScheme colors,
) {
  return switch (status.trim().toLowerCase()) {
    'pending_leave' || 'pending leave' => AppBadgePresentation(
        label: 'Pending Leave',
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      ),
    _ => AppBadgePresentation(
        label: status.trim(),
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurfaceVariant,
      ),
  };
}

AppBadgePresentation subscriptionStatusPresentation(
  String status,
  ColorScheme colors,
) {
  return switch (status.trim().toLowerCase()) {
    'popular' => AppBadgePresentation(
        label: 'Popular',
        backgroundColor: colors.tertiaryContainer,
        foregroundColor: colors.onTertiaryContainer,
      ),
    'current_plan' || 'current plan' => AppBadgePresentation(
        label: 'Current Plan',
        backgroundColor: colors.secondaryContainer,
        foregroundColor: colors.onSecondaryContainer,
      ),
    _ => AppBadgePresentation(
        label: status.trim(),
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurfaceVariant,
      ),
  };
}

class AppBadge extends StatefulWidget {
  const AppBadge({
    super.key,
    required this.presentation,
    this.compact = false,
    this.showDot = false,
    this.pulse = false,
  });

  final AppBadgePresentation presentation;
  final bool compact;
  final bool showDot;
  final bool pulse;

  @override
  State<AppBadge> createState() => _AppBadgeState();
}

class _AppBadgeState extends State<AppBadge> {
  Timer? _pulseTimer;
  bool _pulseHigh = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseTimer();
  }

  @override
  void didUpdateWidget(covariant AppBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) _syncPulseTimer();
  }

  void _syncPulseTimer() {
    _pulseTimer?.cancel();
    _pulseTimer = null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!widget.pulse || reduceMotion) {
      _pulseHigh = true;
      return;
    }
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _pulseHigh = !_pulseHigh);
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final presentation = widget.presentation;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180);

    return Semantics(
      label: presentation.label,
      liveRegion: widget.pulse,
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: widget.pulse && !_pulseHigh && !reduceMotion ? 0.96 : 1,
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: widget.pulse && !_pulseHigh && !reduceMotion ? 0.76 : 1,
            duration: duration,
            curve: Curves.easeOut,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? AppSpacing.sm : AppSpacing.md,
                vertical: widget.compact ? AppSpacing.xs : AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: presentation.backgroundColor,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showDot) ...[
                    Container(
                      width: widget.compact ? 6 : 8,
                      height: widget.compact ? 6 : 8,
                      decoration: BoxDecoration(
                        color: presentation.foregroundColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    presentation.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: presentation.foregroundColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
