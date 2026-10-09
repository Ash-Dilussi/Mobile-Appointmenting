import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';

class AccountSetupRecovery extends StatelessWidget {
  const AccountSetupRecovery({
    super.key,
    required this.message,
    required this.onRetry,
    required this.isRetrying,
  });

  static final Uri _supportEmail = Uri(
    scheme: 'mailto',
    path: 'bookly.support@gmail.com',
    queryParameters: const {'subject': 'Bookly account setup help'},
  );

  final String message;
  final Future<void> Function() onRetry;
  final bool isRetrying;

  Future<void> _contactSupport(BuildContext context) async {
    final opened = await launchUrl(
      _supportEmail,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email bookly.support@gmail.com for setup help.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.sync_problem_outlined, size: 64, color: colors.error),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Your account is safe',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Retrying repairs the same setup attempt and will not create another business.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          FilledButton(
            onPressed: isRetrying ? null : onRetry,
            child: isRetrying
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Retry setup'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: isRetrying ? null : () => _contactSupport(context),
            child: const Text('Contact support'),
          ),
        ],
      ),
    );
  }
}
