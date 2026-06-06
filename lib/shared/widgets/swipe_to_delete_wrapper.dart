import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Wraps a list tile with swipe-to-delete functionality.
/// Shows a red background with trash icon on swipe, then a
/// confirmation dialog before executing the delete action.
class SwipeToDeleteWrapper extends StatelessWidget {
  const SwipeToDeleteWrapper({
    super.key,
    required this.child,
    required this.onDelete,
    required this.entityName,
    this.deleteLabel,
  });

  final Widget child;
  final VoidCallback onDelete;
  final String entityName;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismissible_${entityName}_${child.hashCode}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _showDeleteConfirmation(context),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: child,
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $entityName?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(deleteLabel ?? 'Delete'),
          ),
        ],
      ),
    );
  }
}