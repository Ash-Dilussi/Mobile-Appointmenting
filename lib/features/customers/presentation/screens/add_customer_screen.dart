import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../../shared/widgets/app_date_picker_sheet.dart';
import '../widgets/customer_note_card.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  final String? initialPhone;
  final int? customerId; // Pass for edit mode

  const AddCustomerScreen({super.key, this.initialPhone, this.customerId});

  bool get isEditMode => customerId != null;

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen>
    with UnsavedChangesGuard<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final List<CustomerNote> _notes = [];
  DateTime? _dob;

  bool _isLoading = false;
  late _CustomerFormSnapshot _baseline;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
    if (widget.isEditMode) {
      _loadCustomer();
    }
    _baseline = _currentSnapshot();
    for (final controller in _textControllers) {
      controller.addListener(_refreshDirtyState);
    }
  }

  List<TextEditingController> get _textControllers => [
        _nameController,
        _phoneController,
        _emailController,
        _addressController,
        _cityController,
      ];

  void _refreshDirtyState() {
    if (mounted) setState(() {});
  }

  _CustomerFormSnapshot _currentSnapshot() => _CustomerFormSnapshot(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        dob: _dob,
        notes: List<CustomerNote>.of(_notes),
      );

  @override
  bool get hasUnsavedChanges => !_baseline.matches(_currentSnapshot());

  Future<void> _leaveScreen() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('customers');
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
      _cityController.text = customer.city ?? '';
      _dob = customer.dob;
      _notes
        ..clear()
        ..addAll(customer.notes);
    }
  }

  Future<void> _importFromContacts() async {
    try {
      // The operating system owns this single-contact picker. Bookly receives
      // only the contact the user selects and never requests broad address-book
      // access.
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
            backgroundColor: Theme.of(context).colorScheme.error,
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
    _cityController.dispose();
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
            ..city = _cityController.text.trim().isNotEmpty
                ? _cityController.text.trim()
                : null
            ..dob = _dob
            ..notes = List<CustomerNote>.of(_notes)
            ..updatedAt = DateTime.now()
            ..synced = false;
          await db.updateCustomer(widget.customerId!, updated);
        }
      } else {
        // Create new customer
        final institutionId = ref.read(authSessionProvider)?.institutionId;
        if (institutionId == null || institutionId.isEmpty) {
          throw StateError('An institution is required to create a customer.');
        }
        final newCustomer = Customer()
          ..institutionId = institutionId
          ..name = _nameController.text.trim()
          ..phoneNumber = _phoneController.text.trim()
          ..email = _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null
          ..address = _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null
          ..city = _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null
          ..dob = _dob
          ..notes = List<CustomerNote>.of(_notes)
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;

        await db.insertCustomer(newCustomer);
      }

      if (mounted) {
        await allowPopWithoutPrompt();
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      minimumDate: DateTime(1900),
      maximumDate: DateTime(now.year, now.month, now.day),
      title: 'Select date of birth',
    );
    if (selected != null && mounted) setState(() => _dob = selected);
  }

  Widget _buildNotesSection() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Notes',
              style: AppTypography.titleMedium.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                '${_notes.length}',
                style: AppTypography.labelSmall.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (var index = 0; index < _notes.length; index++) ...[
          CustomerNoteCard(
            note: _notes[index],
            onEdit: () => _showNoteEditor(note: _notes[index]),
            onDelete: () => _deleteNote(_notes[index]),
          ),
          if (index < _notes.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
        if (_notes.isNotEmpty) const SizedBox(height: AppSpacing.md),
        AddCustomerNoteButton(onPressed: _showNoteEditor),
      ],
    );
  }

  Future<void> _showNoteEditor({CustomerNote? note}) async {
    final result = await showModalBottomSheet<CustomerNote>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CustomerNoteEditorSheet(note: note),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _notes.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _notes.add(result);
      } else {
        _notes[index] = result;
      }
    });
  }

  void _deleteNote(CustomerNote note) {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() => _notes.removeAt(index));
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${note.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted || _notes.any((item) => item.id == note.id)) return;
            setState(() => _notes.insert(
                  index > _notes.length ? _notes.length : index,
                  note,
                ));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: canPopWithoutDiscardConfirmation,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await handleCloseRequest(_leaveScreen);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => handleCloseRequest(_leaveScreen),
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

                TextFormField(
                  key: const Key('customer-city-field'),
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'City (optional)',
                    hintText: 'Enter city',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Date of birth
                Semantics(
                  button: true,
                  label: _dob == null
                      ? 'Select date of birth, optional'
                      : 'Date of birth ${DateFormat.yMMMMd().format(_dob!)}',
                  child: InkWell(
                    key: const Key('customer-dob-field'),
                    onTap: _selectDob,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of birth (optional)',
                        prefixIcon: Icon(Icons.cake_outlined),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        _dob == null
                            ? 'Select date'
                            : DateFormat.yMMMd().format(_dob!),
                        style: AppTypography.bodyLarge.copyWith(
                          color: _dob == null
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                _buildNotesSection(),

                const SizedBox(height: AppSpacing.xxl),

                // Save Button
                FilledButton(
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
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
      ),
    );
  }
}

class _CustomerFormSnapshot {
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final DateTime? dob;
  final List<CustomerNote> notes;

  const _CustomerFormSnapshot({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.city,
    required this.dob,
    required this.notes,
  });

  bool matches(_CustomerFormSnapshot other) =>
      name == other.name &&
      phone == other.phone &&
      email == other.email &&
      address == other.address &&
      city == other.city &&
      dob == other.dob &&
      orderedListsEqual(notes, other.notes, _notesEqual);

  static bool _notesEqual(CustomerNote first, CustomerNote second) =>
      first.id == second.id &&
      first.title.trim() == second.title.trim() &&
      (first.description ?? '').trim() == (second.description ?? '').trim() &&
      first.createdAt == second.createdAt;
}

class _CustomerNoteEditorSheet extends StatefulWidget {
  final CustomerNote? note;

  const _CustomerNoteEditorSheet({this.note});

  @override
  State<_CustomerNoteEditorSheet> createState() =>
      _CustomerNoteEditorSheetState();
}

class _CustomerNoteEditorSheetState extends State<_CustomerNoteEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.note?.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    final description = _descriptionController.text.trim();
    final result = widget.note == null
        ? CustomerNote(
            id: const Uuid().v4(),
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            createdAt: now,
            updatedAt: now,
          )
        : widget.note!.copyWith(
            title: _titleController.text.trim(),
            description: description,
            clearDescription: description.isEmpty,
            updatedAt: now,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          AppSpacing.md,
          AppSpacing.screenPadding,
          AppSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _isEditing ? 'Edit note' : 'Add note',
                style: AppTypography.titleLarge.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Use a clear title so this information is easy to scan later.',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('customer-note-title-field'),
                controller: _titleController,
                autofocus: !_isEditing,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Communication preference',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a note title'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('customer-note-description-field'),
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add the details for this note',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('cancel-customer-note'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('save-customer-note'),
                      onPressed: _save,
                      child: Text(_isEditing ? 'Save changes' : 'Save note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
