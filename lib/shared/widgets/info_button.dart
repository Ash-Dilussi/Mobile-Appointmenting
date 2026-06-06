import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// A circular info button that replaces the 3-dot menu pattern.
/// Acts as the primary trigger for navigating to entity detail views.
class InfoButton extends StatelessWidget {
  const InfoButton({
    super.key,
    required this.onTap,
    this.size = 28,
    this.showBorder = true,
  });

  final VoidCallback onTap;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainerLowest,
          border: showBorder
              ? Border.all(color: AppColors.outlineVariant, width: 1)
              : null,
        ),
        child: Icon(
          Icons.info_outline,
          size: size * 0.55,
          color: AppColors.secondary,
        ),
      ),
    );
  }
}