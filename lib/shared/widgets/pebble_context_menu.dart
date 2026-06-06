import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// An action item in a PebbleContextMenu.
class PebbleContextAction {
  const PebbleContextAction({
    required this.icon,
    required this.label,
    this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final VoidCallback onTap;
}

/// Shows an iOS-style context action sheet anchored to the pressed item.
/// Triggered by long-press on a pebble/list tile.
void showPebbleContextMenu({
  required BuildContext context,
  required String title,
  required List<PebbleContextAction> actions,
  VoidCallback? onCancel,
}) {
  HapticFeedback.mediumImpact();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _PebbleContextMenuSheet(
      title: title,
      actions: actions,
      onCancel: onCancel,
    ),
  );
}

class _PebbleContextMenuSheet extends StatelessWidget {
  const _PebbleContextMenuSheet({
    required this.title,
    required this.actions,
    this.onCancel,
  });

  final String title;
  final List<PebbleContextAction> actions;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              title,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Action list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final action = actions[index];
              return ListTile(
                leading: Icon(
                  action.icon,
                  color: action.iconColor ?? AppColors.secondary,
                ),
                title: Text(action.label),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.secondary,
                  size: 20,
                ),
                onTap: () {
                  Navigator.pop(context);
                  action.onTap();
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          // Cancel button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onCancel?.call();
                },
                child: Text(
                  'Cancel',
                  style: const TextStyle(color: AppColors.secondary),
                ),
              ),
            ),
          ),
          // Bottom safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

/// A reusable widget that wraps a child with long-press context menu behavior.
/// Provides a cleaner API than calling showPebbleContextMenu directly.
class PebbleContextMenuWrapper extends StatelessWidget {
  const PebbleContextMenuWrapper({
    super.key,
    required this.child,
    required this.title,
    required this.actions,
    this.onLongPress,
  });

  final Widget child;
  final String title;
  final List<PebbleContextAction> actions;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        onLongPress?.call();
        showPebbleContextMenu(
          context: context,
          title: title,
          actions: actions,
        );
      },
      child: child,
    );
  }
}