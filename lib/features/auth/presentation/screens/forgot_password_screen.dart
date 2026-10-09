import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_form_group.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final email = _emailController.text.trim();
      final success = await ref
          .read(authStateProvider.notifier)
          .sendPasswordResetEmail(email);

      setState(() {
        _isLoading = false;
        _emailSent = success;
      });

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'If an account exists with that email, a reset link has been sent.',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: 0),
        elevation: 0,
        leading: AppIconButton(
          tooltip: 'Back to sign in',
          color: colors.onSurfaceVariant,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // Title
                Text(
                  'Reset Password',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.left,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  _emailSent
                      ? 'Check your email for a link to reset your password.'
                      : 'Enter the email address associated with your account.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.left,
                ),

                const SizedBox(height: AppSpacing.xxxl),

                if (!_emailSent) ...[
                  // Email field
                  AppFormGroup(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSendResetLink(),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Send Reset Link button
                  AppButton(
                    onPressed: _isLoading ? null : _handleSendResetLink,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimaryContainer,
                            ),
                          )
                        : const Text('Send Reset Link'),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Demo note
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      'Demo: Use the email you signed up with. The reset link will go directly to setting a new password.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  // Success state
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 32,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Text(
                    'Email Sent!',
                    style: AppTypography.titleLarge.copyWith(
                      color: colors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Go to Reset Password button
                  AppButton(
                    onPressed: () {
                      final email = _emailController.text.trim();
                      context.goNamed(
                        'reset-password',
                        queryParameters: {'email': email},
                      );
                    },
                    child: const Text('Continue to Reset Password'),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Back to login
                  TextButton(
                    onPressed: () => context.goNamed('login'),
                    child: const Text('Back to Login'),
                  ),
                ],

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
