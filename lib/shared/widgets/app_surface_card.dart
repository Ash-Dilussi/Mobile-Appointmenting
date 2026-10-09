import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_shadows.dart';

/// The app's standard content surface.
///
/// Routine grouping is flat with a semantic hairline. Use [elevated] only for
/// content that deliberately floats above the surrounding page.
class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(AppSpacing.radiusLg);
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: borderRadius,
        border: Border.all(color: colors.outlineVariant, width: 0.5),
        boxShadow: elevated ? AppShadows.card(colors.primaryContainer) : null,
      ),
      child: child,
    );

    if (onTap == null) return surface;

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: surface,
    );
  }
}
