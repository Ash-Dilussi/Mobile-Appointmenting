import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_form_group.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String? resetEmail;

  const ResetPasswordScreen({super.key, this.resetEmail});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final email = widget.resetEmail ?? '';
      final newPassword = _passwordController.text;

      final success = await ref
          .read(authStateProvider.notifier)
          .resetPassword(email, newPassword);

      setState(() {
        _isLoading = false;
        _isSuccess = success;
      });

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to reset password. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
                  _isSuccess ? 'Password Reset!' : 'Set New Password',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.left,
                ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  _isSuccess
                      ? 'Your password has been successfully reset.'
                      : 'Enter a new password for your account.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.left,
                ),

                const SizedBox(height: AppSpacing.xxxl),

                if (!_isSuccess) ...[
                  AppFormGroup(
                    children: [
                      // New Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: AppIconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      // Confirm Password field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleResetPassword(),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: AppIconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Show confirmed password'
                                : 'Hide confirmed password',
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Reset Password button
                  AppButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimaryContainer,
                            ),
                          )
                        : const Text('Reset Password'),
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
                      'Demo: Enter any password (min 6 characters) to reset.',
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

                  const SizedBox(height: AppSpacing.xxl),

                  // Go to Login button
                  AppButton(
                    onPressed: () => context.goNamed('login'),
                    child: const Text('Go to Login'),
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
