import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/service_color_palette.dart';

class ServiceBadge extends StatelessWidget {
  const ServiceBadge({
    super.key,
    required this.label,
    this.colorValue,
    this.compact = false,
  });

  final String label;
  final int? colorValue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final option = ServiceColorPalette.resolve(colorValue);

    return Semantics(
      label: 'Service: $label. Color: ${option.name}',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: compact ? AppSpacing.xs : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: option.color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer_rounded,
                size: compact ? 12 : 16,
                color: option.onColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact
                          ? AppTypography.labelSmall
                          : AppTypography.labelMedium)
                      .copyWith(
                    color: option.onColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
