import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../home/presentation/providers/home_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String? prefilledPhone;
  final int? callLogId;

  const BookingScreen({
    super.key,
    this.prefilledPhone,
    this.callLogId,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int? _selectedServiceId;
  Customer? _existingCustomer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledPhone != null) {
      _phoneController.text = widget.prefilledPhone!;
      _checkExistingCustomer();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingCustomer() async {
    final db = ref.read(homeHiveProvider);
    final customer = db.getCustomerByPhone(_phoneController.text);
    if (customer != null && mounted) {
      setState(() {
        _existingCustomer = customer;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(homeHiveProvider);
      final phone = _phoneController.text.trim();

      // Get or create customer
      int customerId;
      if (_existingCustomer != null) {
        customerId = _existingCustomer!.id!;
      } else {
        // Create new customer
        final newCustomer = Customer()
          ..phoneNumber = phone
          ..name = 'New Customer' // TODO: Add name field
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;
        customerId = (await db.insertCustomer(newCustomer))!;
      }

      // Get service duration
      int durationMinutes = 30;
      if (_selectedServiceId != null) {
        final service = db.getServiceById(_selectedServiceId!);
        if (service != null) {
          durationMinutes = service.defaultDurationMinutes;
        }
      }

      // Calculate start and end time
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final endTime = startTime.add(Duration(minutes: durationMinutes));

      // Create appointment
      final appointment = Appointment()
        ..customerId = customerId
        ..serviceId = _selectedServiceId
        ..startTime = startTime
        ..endTime = endTime
        ..status = 'upcoming'
        ..notes = _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..synced = false;
      final appointmentId = await db.insertAppointment(appointment);

      // Update call log if linked
      if (widget.callLogId != null) {
        final callLog = db.getCallLogById(widget.callLogId!);
        if (callLog != null) {
          callLog
            ..linkedAppointmentId = appointmentId
            ..customerId = customerId
            ..followedUp = true;
          await db.updateCallLog(widget.callLogId!, callLog);
        }
      }

      if (mounted) {
        context.goNamed(
          'booking-confirmation',
          pathParameters: {'appointmentId': appointmentId.toString()},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating appointment: $e'),
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
    final services = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Appointment'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Customer Phone',
                  hintText: 'Enter phone number',
                  prefixIcon: const Icon(Icons.phone),
                  suffixIcon: _existingCustomer != null
                      ? Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Existing',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.length >= 3) {
                    _checkExistingCustomer();
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),

              if (_existingCustomer != null) ...[
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () {
                    context.goNamed(
                      'customer-profile',
                      pathParameters: {'id': _existingCustomer!.id.toString()},
                    );
                  },
                  child: Text(
                    'View Customer Profile',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Date and Time Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM d, yyyy').format(_selectedDate),
                          style: AppTypography.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Time',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime.format(context),
                          style: AppTypography.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Service Selection
              services.when(
                data: (serviceList) {
                  if (serviceList.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: serviceList.map((service) {
                          final isSelected = _selectedServiceId == service.id;
                          return ChoiceChip(
                            label: Text(service.title),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedServiceId = selected ? service.id : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any notes for this appointment...',
                  alignLabelWithHint: true,
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
                    : const Text('Book Appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
