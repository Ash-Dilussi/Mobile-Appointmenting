import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';

/// A reusable destination for visible features whose full experience has not
/// been implemented yet.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    this.featureName,
  });

  final String? featureName;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trimmedFeatureName = featureName?.trim();
    final hasFeatureName = trimmedFeatureName?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: IconButton(
          tooltip: 'Go back',
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Coming Soon'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight - (AppSpacing.screenPadding * 2),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.construction_rounded,
                              size: 52,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                          ),
                          child: Text(
                            'IN THE WORKS',
                            style: textTheme.labelMedium?.copyWith(
                              color: colors.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          hasFeatureName
                              ? '$trimmedFeatureName is coming soon'
                              : 'This screen is coming soon',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'We\'re still building this experience. '
                          'Please check back in a future update.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        SizedBox(
                          width: double.infinity,
                          height: AppSpacing.buttonMinHeight,
                          child: FilledButton.icon(
                            onPressed: () => _goBack(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Go Back'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
