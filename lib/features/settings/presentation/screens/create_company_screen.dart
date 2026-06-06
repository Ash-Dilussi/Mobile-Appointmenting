import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/style_preset.dart';
import '../../../../core/database/collections/institution.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  StylePreset _selectedPreset = StylePreset.solarOrange;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _createCompany() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final session = ref.read(authSessionProvider);
      final hiveService = ref.read(hiveServiceProvider);

      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please login again.')),
          );
        }
        return;
      }

      // Create institution
      final institutionId = 'inst_${DateTime.now().millisecondsSinceEpoch}';
      final institution = Institution()
        ..id = institutionId
        ..name = _nameController.text.trim()
        ..address = _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim()
        ..phone = _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim()
        ..email = _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim()
        ..themePreset = _selectedPreset.name
        ..ownerId = session.userId;

      await hiveService.insertInstitution(institution);

      // Update user with institutionId
      final user = hiveService.getUserById(session.userId);
      if (user != null) {
        user.institutionId = institutionId;
        user.role = 'owner';
        await hiveService.updateUser(user.id, user);
      }

      // Reload session
      await ref.read(authSessionProvider.notifier).loadSession(session.email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company created successfully!')),
        );
        context.goNamed('settings');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPresetPrimaryColor(StylePreset preset) {
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Create Company'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Icon(
              Icons.business,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Set Up Your Company',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create your company profile to start managing your business.',
              style: TextStyle(
                color: AppColors.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Company Name',
                hintText: 'Enter company name',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter company name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Enter company address',
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
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose a color theme for your company',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: StylePreset.values.map((preset) {
                final isSelected = _selectedPreset == preset;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPreset = preset),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getPresetPrimaryColor(preset).withValues(alpha: 0.15)
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? _getPresetPrimaryColor(preset)
                            : AppColors.secondary.withValues(alpha: 0.3),
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
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _isLoading ? null : _createCompany,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Company'),
            ),
          ],
        ),
      ),
    );
  }
}
