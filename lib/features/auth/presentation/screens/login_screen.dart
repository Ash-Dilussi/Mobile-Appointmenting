import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/release_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/utils/tap_guard.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_form_group.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../core/constants/auth_error_messages.dart';
import '../../../../core/constants/auth_field_constraints.dart';
import '../providers/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _errorBannerDuration = Duration(seconds: 10);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  Timer? _errorBannerTimer;
  final _sheetTapGuard = TapGuard();
  String? _errorBannerMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _errorBannerTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final authState = ref.watch(authNotifierProvider);
    final notifier = ref.read(authNotifierProvider.notifier);
    final showGoogleSignIn = ReleaseScope.googleSignInEnabled;

    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorCode != null) {
        _dismissErrorBanner(clearAuthError: false);

        // User-not-found dialog — friendly prompt to create account
        if (next.errorCode == 'user-not-found') {
          notifier.clearError();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) _showNewUserDialog(context);
          });
          return;
        }

        _showErrorBanner(authErrorMessage(next.errorCode));
      }
      if (next.status == AuthStatus.authenticated) {
        _dismissErrorBanner(clearAuthError: false);
        context.go('/home');
      } else if (next.status == AuthStatus.newUser) {
        _dismissErrorBanner(clearAuthError: false);
        context.goNamed('business-setup');
      }
    });

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (_errorBannerMessage != null)
              _buildErrorBanner(colors, _errorBannerMessage!),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.business_center,
                          size: 56,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Welcome Back',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Sign in to continue',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      if (authState.isLoading) const LinearProgressIndicator(),
                      const SizedBox(height: AppSpacing.lg),
                      AppFormGroup(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            maxLength: AuthFieldConstraints.emailMaxLength,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: AuthFieldConstraints.validateEmail,
                          ),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            obscuringCharacter: '•',
                            enableSuggestions: false,
                            autocorrect: false,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
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
                                  setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: AuthFieldConstraints.validatePassword,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  notifier.signInWithEmail(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                  );
                                }
                              },
                        child: const Text('Sign In'),
                      ),
                      if (showGoogleSignIn) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Text(
                                'OR',
                                style:
                                    TextStyle(color: colors.onSurfaceVariant),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        OutlinedButton.icon(
                          onPressed: authState.isLoading
                              ? null
                              : () => notifier.signInWithGoogle(),
                          icon: const Icon(
                            Icons.g_mobiledata,
                            size: 20,
                          ),
                          label: const Text('Continue with Google'),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      TextButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text("Forgot Password?"),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Register'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorBanner(String message) {
    _errorBannerTimer?.cancel();
    if (!mounted) return;

    setState(() => _errorBannerMessage = message);

    _errorBannerTimer = Timer(_errorBannerDuration, _dismissErrorBanner);
  }

  void _dismissErrorBanner({bool clearAuthError = true}) {
    _errorBannerTimer?.cancel();
    _errorBannerTimer = null;
    if (!mounted) return;

    if (_errorBannerMessage != null) {
      setState(() => _errorBannerMessage = null);
    }
    // Also clear any legacy messenger banner retained across hot reload.
    ScaffoldMessenger.maybeOf(context)?.clearMaterialBanners();
    if (clearAuthError) {
      ref.read(authNotifierProvider.notifier).clearError();
    }
  }

  Widget _buildErrorBanner(ColorScheme colors, String message) {
    return Material(
      key: const ValueKey('login_error_banner'),
      color: colors.error,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.onError),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: TextStyle(color: colors.onError)),
            ),
            TextButton(
              key: const ValueKey('login_error_dismiss'),
              style: TextButton.styleFrom(foregroundColor: colors.onError),
              onPressed: _dismissErrorBanner,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a friendly bottom sheet when the entered email has no registered account.
  Future<void> _showNewUserDialog(BuildContext context) async {
    if (!_sheetTapGuard.tryAcquire()) return;
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final controller = AnimationController(
      vsync: Navigator.of(context),
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
      reverseDuration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        transitionAnimationController: controller,
        backgroundColor: colors.surface.withValues(alpha: 0),
        builder: (sheetContext) {
          final sheetColors = Theme.of(sheetContext).colorScheme;
          return Container(
            margin: const EdgeInsets.only(top: 80),
            decoration: BoxDecoration(
              color: sheetColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color:
                            sheetColors.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Icon(
                      Icons.person_search_rounded,
                      size: 64,
                      color: sheetColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Are you new here?',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            context.go('/register');
                          },
                          child: const Text('Create Account'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: sheetColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            minimumSize: const Size(100, 52),
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}
