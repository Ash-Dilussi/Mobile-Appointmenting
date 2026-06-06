import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/database/collections/user.dart';
import '../../../../core/database/collections/leave_request.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';

class OperatorProfileScreen extends ConsumerStatefulWidget {
  final String operatorId;

  const OperatorProfileScreen({super.key, required this.operatorId});

  @override
  ConsumerState<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends ConsumerState<OperatorProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  String? _gender;
  DateTime? _birthdate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  int? _calculateAge(DateTime? birthdate) {
    if (birthdate == null) return null;
    final today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthdate = picked);
    }
  }

  Future<void> _saveProfile(User operator) async {
    final hiveService = ref.read(hiveServiceProvider);

    operator.name = _nameController.text.trim();
    operator.address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
    operator.phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    operator.gender = _gender;
    operator.birthdate = _birthdate;

    await hiveService.updateUser(operator.id, operator);

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  Future<void> _requestLeaveCompany(User operator) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Company?'),
        content: Text(
          'Are you sure you want to request leaving ${operator.institutionId}? '
          'This request will be sent to the company owner for approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final hiveService = ref.read(hiveServiceProvider);

    // Create leave request
    final leaveRequest = LeaveRequest()
      ..institutionId = operator.institutionId!
      ..userId = operator.id
      ..userEmail = operator.email
      ..userName = operator.name
      ..status = 'pending';

    await hiveService.insertLeaveRequest(leaveRequest);

    // Update user status
    operator.status = 'pending_leave';
    await hiveService.updateUser(operator.id, operator);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted')),
      );
      context.pop();
    }
  }

  void _loadOperatorData(User operator) {
    if (_nameController.text.isEmpty) {
      _nameController.text = operator.name;
      _addressController.text = operator.address ?? '';
      _phoneController.text = operator.phone ?? '';
      _gender = operator.gender;
      _birthdate = operator.birthdate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final hiveService = ref.watch(hiveServiceProvider);
    final operator = hiveService.getUserById(widget.operatorId);

    if (operator == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Operator not found')),
      );
    }

    final isOwner = session?.role == Role.owner;
    final isOwnProfile = session?.userId == operator.id;
    final canEdit = isOwner || isOwnProfile;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOperatorData(operator);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isOwnProfile ? 'My Profile' : 'Operator Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('staff-management');
            }
          },
        ),
        actions: [
          if (canEdit && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: _isEditing ? _buildEditView(operator) : _buildProfileView(operator, isOwnProfile),
    );
  }

  Widget _buildProfileView(User operator, bool isOwnProfile) {
    final age = _calculateAge(operator.birthdate);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Avatar
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              operator.name.isNotEmpty ? operator.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Name
        Center(
          child: Text(
            operator.name.isNotEmpty ? operator.name : 'Unnamed',
            style: AppTypography.titleLarge,
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: operator.role == 'owner'
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              operator.role == 'owner' ? 'Owner' : 'Officer',
              style: AppTypography.labelMedium.copyWith(
                color: operator.role == 'owner' ? AppColors.primary : AppColors.secondary,
              ),
            ),
          ),
        ),

        if (operator.status == 'pending_leave')
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Pending Leave Request',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.error),
                ),
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.xxl),

        // Info cards
        _buildInfoCard(Icons.email_outlined, 'Email', operator.email),
        _buildInfoCard(Icons.phone_outlined, 'Phone', operator.phone ?? 'Not set'),
        _buildInfoCard(Icons.location_on_outlined, 'Address', operator.address ?? 'Not set'),
        _buildInfoCard(Icons.cake_outlined, 'Birthdate',
            operator.birthdate != null
                ? '${operator.birthdate!.day}/${operator.birthdate!.month}/${operator.birthdate!.year}${age != null ? ' ($age years)' : ''}'
                : 'Not set'),
        _buildInfoCard(Icons.wc_outlined, 'Gender',
            operator.gender != null ? _capitalize(operator.gender!) : 'Not set'),

        const SizedBox(height: AppSpacing.xxl),

        // Leave Company button (only for operators, not owners, on own profile)
        if (operator.role == 'officer' && isOwnProfile && operator.status != 'pending_leave')
          OutlinedButton.icon(
            onPressed: () => _requestLeaveCompany(operator),
            icon: const Icon(Icons.exit_to_app, color: AppColors.error),
            label: const Text('Leave Company', style: TextStyle(color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),

        if (operator.status == 'pending_leave')
          const Center(
            child: Text(
              'Your leave request is pending approval from the company owner.',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.secondary)),
        subtitle: Text(value, style: AppTypography.bodyMedium),
      ),
    );
  }

  Widget _buildEditView(User operator) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          value: _gender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            prefixIcon: Icon(Icons.wc_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Male')),
            DropdownMenuItem(value: 'female', child: Text('Female')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cake_outlined),
          title: const Text('Birthdate'),
          subtitle: Text(
            _birthdate != null
                ? '${_birthdate!.day}/${_birthdate!.month}/${_birthdate!.year}'
                : 'Not set',
          ),
          trailing: TextButton(
            onPressed: _selectBirthdate,
            child: const Text('Select'),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: FilledButton(
                onPressed: () => _saveProfile(operator),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _capitalize(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}
