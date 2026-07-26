import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../home/presentation/providers/home_provider.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final String? initialPhone;
  final int? customerId; // Pass for edit mode

  const AddCustomerScreen({super.key, this.initialPhone, this.customerId});

  bool get isEditMode => customerId != null;

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
    if (widget.isEditMode) {
      _loadCustomer();
    }
  }

  void _loadCustomer() {
    final db = ref.read(homeHiveProvider);
    final customer = db.getCustomerById(widget.customerId!);
    if (customer != null) {
      _nameController.text = customer.name;
      _phoneController.text = customer.phoneNumber;
      _emailController.text = customer.email ?? '';
      _addressController.text = customer.address ?? '';
      _notesController.text = customer.notes ?? '';
    }
  }

  Future<void> _importFromContacts() async {
    // Request contacts permission
    final status = await Permission.contacts.request();

    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact permission is required to import contacts'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Contact permission is permanently denied. Please enable it in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Open native contact picker
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        setState(() {
          // Set display name
          _nameController.text = contact.displayName;

          // Set first phone number (normalized for display consistency)
          if (contact.phones.isNotEmpty) {
            final rawPhone = contact.phones.first.number;
            _phoneController.text = normalizePhoneNumber(rawPhone);
          }

          // Set first email
          if (contact.emails.isNotEmpty) {
            _emailController.text = contact.emails.first.address;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contact: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(homeHiveProvider);

      if (widget.isEditMode) {
        // Update existing customer
        final existing = db.getCustomerById(widget.customerId!);
        if (existing != null) {
          final updated = existing
            ..name = _nameController.text.trim()
            ..phoneNumber = _phoneController.text.trim()
            ..email = _emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : null
            ..address = _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null
            ..notes = _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null
            ..updatedAt = DateTime.now()
            ..synced = false;
          await db.updateCustomer(widget.customerId!, updated);
        }
      } else {
        // Create new customer
        final newCustomer = Customer()
          ..name = _nameController.text.trim()
          ..phoneNumber = _phoneController.text.trim()
          ..email = _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null
          ..address = _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null
          ..notes = _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;

        await db.insertCustomer(newCustomer);
      }

      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed('customers');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving customer: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('customers');
            }
          },
        ),
        title: Text(widget.isEditMode ? 'Edit Customer' : 'Add Customer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Import from Contacts button (only in add mode)
              if (!widget.isEditMode)
                OutlinedButton.icon(
                  onPressed: _importFromContacts,
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Import from Contacts'),
                ),

              if (!widget.isEditMode) const SizedBox(height: AppSpacing.lg),

              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter customer name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Enter phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'Enter email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Address
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'Enter address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any notes about this customer...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(Icons.notes_outlined),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Save Button
              FilledButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimaryContainer,
                        ),
                      )
                    : Text(widget.isEditMode
                        ? 'Update Customer'
                        : 'Save Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
