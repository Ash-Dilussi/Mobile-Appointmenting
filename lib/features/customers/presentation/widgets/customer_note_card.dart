import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/database/collections/customer_note.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CustomerNoteCard extends StatelessWidget {
  final CustomerNote note;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int? titleMaxLines;
  final int? descriptionMaxLines;

  const CustomerNoteCard({
    super.key,
    required this.note,
    this.onEdit,
    this.onDelete,
    this.titleMaxLines,
    this.descriptionMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final description = note.description?.trim();

    return Container(
      key: ValueKey('customer-note-${note.id}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  maxLines: titleMaxLines,
                  overflow: titleMaxLines == null
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    maxLines: descriptionMaxLines,
                    overflow: descriptionMaxLines == null
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null || onDelete != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  Semantics(
                    button: true,
                    label: 'Edit note ${note.title}',
                    excludeSemantics: true,
                    child: IconButton(
                      key: ValueKey('edit-customer-note-${note.id}'),
                      tooltip: 'Edit note',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      color: colors.primary,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                if (onEdit != null && onDelete != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onDelete != null)
                  Semantics(
                    button: true,
                    label: 'Delete note ${note.title}',
                    excludeSemantics: true,
                    child: IconButton(
                      key: ValueKey('delete-customer-note-${note.id}'),
                      tooltip: 'Delete note',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: colors.error,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AddCustomerNoteButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddCustomerNoteButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Add customer note',
      child: CustomPaint(
        foregroundPainter: _DashedRoundedRectPainter(
          color: colors.outline,
          radius: AppSpacing.radiusMd,
        ),
        child: Material(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('add-customer-note'),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Add note',
                      style: AppTypography.labelLarge.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRoundedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 7, metric.length)),
          paint,
        );
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
