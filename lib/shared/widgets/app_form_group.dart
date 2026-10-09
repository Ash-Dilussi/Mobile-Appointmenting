import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Inset, grouped-field surface used by the authentication pilot.
class AppFormGroup extends StatelessWidget {
  const AppFormGroup({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final inputTheme = theme.inputDecorationTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: inputTheme.copyWith(
              fillColor: colors.surfaceContainerLowest,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: AppSpacing.lg,
                    color: colors.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
