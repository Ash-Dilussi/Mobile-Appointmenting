import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/style_preset.dart';
import '../../../../core/database/collections/institution.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

class EditCompanyScreen extends ConsumerStatefulWidget {
  const EditCompanyScreen({super.key});

  @override
  ConsumerState<EditCompanyScreen> createState() => _EditCompanyScreenState();
}

class _EditCompanyScreenState extends ConsumerState<EditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  bool _isLoading = false;
  StylePreset? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _loadInstitutionData(Institution institution) {
    if (_nameController.text.isEmpty) {
      _nameController.text = institution.name;
      _addressController.text = institution.address ?? '';
      _phoneController.text = institution.phone ?? '';
      _emailController.text = institution.email ?? '';
      _selectedPreset = StylePreset.values.firstWhere(
        (p) => p.name == institution.themePreset,
        orElse: () => StylePreset.solarOrange,
      );
    }
  }

  Future<void> _saveCompany() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final session = ref.read(authSessionProvider);
      final hiveService = ref.read(hiveServiceProvider);
      final institution = hiveService.getInstitutionById(session!.institutionId!);

      if (institution != null) {
        institution.name = _nameController.text.trim();
        institution.address = _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim();
        institution.phone = _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim();
        institution.email = _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim();
        if (_selectedPreset != null) {
          institution.themePreset = _selectedPreset!.name;
        }

        await hiveService.updateInstitution(institution.id, institution);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company updated successfully')),
          );
          context.pop();
        }
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
    final session = ref.watch(authSessionProvider);
    final hiveService = ref.watch(hiveServiceProvider);

    if (session?.institutionId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Company')),
        body: const Center(child: Text('No company found')),
      );
    }

    final institution = hiveService.getInstitutionById(session!.institutionId!);
    if (institution == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Company')),
        body: const Center(child: Text('Company not found')),
      );
    }

    // Load data after first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstitutionData(institution);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Edit Company'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('staff-management');
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
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
              onPressed: _isLoading ? null : _saveCompany,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
