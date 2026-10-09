import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/style_preset.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../auth/presentation/widgets/account_setup_recovery.dart';
import '../../application/business_provisioning_service.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() =>
      _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _recoveryMessage;
  StylePreset _selectedPreset = StylePreset.solarOrange;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createBusiness() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _recoveryMessage = null;
    });
    try {
      final session = ref.read(authSessionProvider);
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
            ),
          );
        }
        return;
      }

      await ref.read(businessProvisioningServiceProvider).provision(
            session: session,
            name: _nameController.text,
            address: _addressController.text,
            phone: _phoneController.text,
            email: _emailController.text,
            themePreset: _selectedPreset.name,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business created successfully!')),
        );
        context.go('/home');
      }
    } on BusinessProvisioningRecoveryRequired catch (error) {
      if (mounted) {
        setState(() => _recoveryMessage = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recoveryMessage =
              'We could not finish setting up your business. Your account is safe, and you can retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPresetPrimaryColor(StylePreset preset) {
    // Intentional invariant previews of preset choices, not themeable feature
    // surfaces. Selection text and surrounding UI remain semantic.
    switch (preset) {
      case StylePreset.solarOrange:
        return const Color(0xFF904D00);
      case StylePreset.clinicTeal:
        return const Color(0xFF00796B);
      case StylePreset.midnightCharcoal:
        return const Color(0xFF37474F);
      case StylePreset.forestGreen:
        return const Color(0xFF2E7D32);
      case StylePreset.royalPurple:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Create Business'),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('business-setup');
            }
          },
        ),
      ),
      body: _recoveryMessage != null
          ? SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: AccountSetupRecovery(
                      message: _recoveryMessage!,
                      onRetry: _createBusiness,
                      isRetrying: _isLoading,
                    ),
                  ),
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Icon(Icons.business_outlined, size: 64, color: colors.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Set Up Your Business',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add the details your customers and team will recognise.',
              style: TextStyle(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Business Name',
                hintText: 'Enter business name',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a business name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter business address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'Enter phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Theme Color',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose a color theme for your business',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: StylePreset.values.map((preset) {
                final isSelected = _selectedPreset == preset;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${preset.displayName} theme',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => setState(() => _selectedPreset = preset),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _getPresetPrimaryColor(preset)
                                .withValues(alpha: 0.15)
                            : colors.surfaceContainerLowest,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: isSelected
                              ? _getPresetPrimaryColor(preset)
                              : colors.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _getPresetPrimaryColor(preset),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            preset.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _isLoading ? null : _createBusiness,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Business'),
            ),
          ],
              ),
            ),
    );
  }
}
