import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../home/presentation/providers/home_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String? prefilledPhone;
  final int? callLogId;
  final DateTime? prefilledDate;
  final int? appointmentId; // For edit mode

  const BookingScreen({
    super.key,
    this.prefilledPhone,
    this.callLogId,
    this.prefilledDate,
    this.appointmentId,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<int> _selectedServiceIds = [];
  int? _selectedStationId;
  Customer? _existingCustomer;
  bool _isLoading = false;

  // Customer search suggestions
  List<Customer> _customerSuggestions = [];
  bool _showSuggestions = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Service duration overrides (per appointment, not stored in service defaults)
  Map<int, int> _serviceDurationOverrides = {};

  // Service price overrides (per appointment)
  Map<int, double> _servicePriceOverrides = {};

  // Service notes (per appointment)
  Map<int, String> _serviceNotes = {};

  @override
  void initState() {
    super.initState();
    if (widget.appointmentId != null) {
      _loadAppointmentForEdit();
    } else {
      if (widget.prefilledPhone != null) {
        _phoneController.text = widget.prefilledPhone!;
        _checkExistingCustomer();
      }
      if (widget.prefilledDate != null) {
        _selectedDate = widget.prefilledDate!;
        _selectedTime = TimeOfDay.fromDateTime(widget.prefilledDate!);
      }
    }
  }

  Future<void> _loadAppointmentForEdit() async {
    final db = ref.read(homeHiveProvider);
    final appointment = db.getAppointmentById(widget.appointmentId!);
    if (appointment == null) return;

    // Populate customer info
    if (appointment.customerId != null) {
      final customer = db.getCustomerById(appointment.customerId!);
      if (customer != null) {
        _phoneController.text = customer.phoneNumber;
        _existingCustomer = customer;
      }
    }

    // Populate date/time
    _selectedDate = appointment.startTime;
    _selectedTime = TimeOfDay.fromDateTime(appointment.startTime);

    // Populate services
    if (appointment.serviceId != null) {
      _selectedServiceIds = [appointment.serviceId!];
      final service = db.getServiceById(appointment.serviceId!);
      if (service != null) {
        _serviceDurationOverrides[appointment.serviceId!] =
            appointment.endTime.difference(appointment.startTime).inMinutes;
      }
    }

    // Populate station
    _selectedStationId = appointment.stationId;

    // Populate notes
    if (appointment.notes != null) {
      _notesController.text = appointment.notes!;
    }

    // Populate appointment services (line items)
    final appointmentServices = db.getAppointmentServicesForAppointment(appointment.id!);
    for (final apptService in appointmentServices) {
      if (apptService.serviceId != null) {
        _selectedServiceIds.add(apptService.serviceId!);
        if (apptService.durationOverride != null) {
          _serviceDurationOverrides[apptService.serviceId!] = apptService.durationOverride!;
        }
        if (apptService.priceOverride != null) {
          _servicePriceOverrides[apptService.serviceId!] = apptService.priceOverride!;
        }
        if (apptService.notes != null && apptService.notes!.isNotEmpty) {
          _serviceNotes[apptService.serviceId!] = apptService.notes!;
        }
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingCustomer() async {
    final db = ref.read(homeHiveProvider);
    final customer = db.getCustomerByPhone(_phoneController.text);
    if (customer != null && mounted) {
      setState(() {
        _existingCustomer = customer;
        _hideSuggestions();
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.length < 3) {
      _hideSuggestions();
      return;
    }

    final db = ref.read(homeHiveProvider);
    final allCustomers = db.getAllCustomers();
    final lowerQuery = query.toLowerCase();

    final matches = allCustomers
        .where((c) {
          return c.phoneNumber.contains(query) ||
              c.name.toLowerCase().contains(lowerQuery);
        })
        .take(5)
        .toList();

    if (mounted) {
      setState(() {
        _customerSuggestions = matches;
        _showSuggestions = matches.isNotEmpty;
      });
      _showOverlay();
    }
  }

  void _showOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _showSuggestions = false;
        _customerSuggestions = [];
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _customerSuggestions.length,
                itemBuilder: (context, index) {
                  final customer = _customerSuggestions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: AppColors.onPrimaryContainer),
                      ),
                    ),
                    title: Text(customer.name),
                    subtitle: Text(customer.phoneNumber),
                    onTap: () => _selectCustomer(customer),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectCustomer(Customer customer) {
    _phoneController.text = customer.phoneNumber;
    setState(() {
      _existingCustomer = customer;
      _showSuggestions = false;
    });
    _hideSuggestions();
  }

  void _clearExistingCustomer() {
    setState(() {
      _existingCustomer = null;
    });
  }

  Widget _buildSelectedServicesList(List<Service> allServices) {
    final selectedServices = allServices
        .where((s) => s.id != null && _selectedServiceIds.contains(s.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Services',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...selectedServices.map((service) => _ServiceSelectionCard(
              service: service,
              initialDuration: _serviceDurationOverrides[service.id] ??
                  service.defaultDurationMinutes,
              initialPrice: _servicePriceOverrides[service.id] ?? service.cost,
              initialNotes: _serviceNotes[service.id] ?? '',
              onDurationChanged: (duration) {
                setState(() {
                  _serviceDurationOverrides[service.id!] = duration;
                });
              },
              onPriceChanged: (price) {
                setState(() {
                  _servicePriceOverrides[service.id!] = price;
                });
              },
              onNotesChanged: (notes) {
                setState(() {
                  if (notes.isEmpty) {
                    _serviceNotes.remove(service.id);
                  } else {
                    _serviceNotes[service.id!] = notes;
                  }
                });
              },
              onRemove: () {
                setState(() {
                  _selectedServiceIds.remove(service.id);
                  _serviceDurationOverrides.remove(service.id);
                  _servicePriceOverrides.remove(service.id);
                  _serviceNotes.remove(service.id);
                });
              },
            )),
        const SizedBox(height: AppSpacing.md),
        // Total summary
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duration', style: AppTypography.labelSmall),
                  Text(
                    '${_getTotalDuration()} min',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total', style: AppTypography.labelSmall),
                  Text(
                    '\$${_getTotalPrice().toStringAsFixed(2)}',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _getTotalDuration() {
    int total = 0;
    for (final serviceId in _selectedServiceIds) {
      total += _serviceDurationOverrides[serviceId] ?? 30;
    }
    return total > 0 ? total : 30;
  }

  double _getTotalPrice() {
    final db = ref.read(homeHiveProvider);
    double total = 0;
    for (final serviceId in _selectedServiceIds) {
      final service = db.getServiceById(serviceId);
      final price = _servicePriceOverrides[serviceId] ?? service?.cost ?? 0;
      total += price;
    }
    return total;
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

  void _showVoiceInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _VoiceInputSheet(
        onDataParsed: (parsed) {
          if (parsed['phone'] != null) {
            _phoneController.text = parsed['phone'] as String;
            _checkExistingCustomer();
          }
          if (parsed['name'] != null && _existingCustomer == null) {
            _nameController.text = parsed['name'] as String;
          }
          if (parsed['date'] != null) {
            setState(() => _selectedDate = parsed['date'] as DateTime);
          }
          if (parsed['time'] != null) {
            setState(() => _selectedTime = parsed['time'] as TimeOfDay);
          }
          if (parsed['serviceId'] != null) {
            setState(() {
              _selectedServiceIds = [parsed['serviceId'] as int];
            });
          }
        },
      ),
    );
  }

  Widget _buildStationSelection() {
    final stations = ref.watch(serviceStationsProvider);

    return stations.when(
      data: (stationList) {
        if (stationList.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service Station',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: stationList.map((station) {
                final isSelected = _selectedStationId == station.id;
                return ChoiceChip(
                  label: Text(station.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStationId = selected ? station.id : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
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
        final name = _nameController.text.trim();
        final newCustomer = Customer()
          ..phoneNumber = phone
          ..name = name.isNotEmpty ? name : 'New Customer'
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;
        customerId = (await db.insertCustomer(newCustomer))!;
      }

      // Calculate start and end time using total duration from selected services
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final totalDuration = _getTotalDuration();
      final endTime = startTime.add(Duration(minutes: totalDuration));

      // Get primary service ID (first selected)
      final primaryServiceId =
          _selectedServiceIds.isNotEmpty ? _selectedServiceIds.first : null;

      // Determine appointment ID to use
      final isEditMode = widget.appointmentId != null;
      final existingAppointment = isEditMode
          ? db.getAppointmentById(widget.appointmentId!)
          : null;

      // Create or update appointment
      final appointment = Appointment()
        ..customerId = customerId
        ..serviceId = primaryServiceId
        ..stationId = _selectedStationId
        ..startTime = startTime
        ..endTime = endTime
        ..status = isEditMode
            ? (existingAppointment?.status ?? 'upcoming')
            : 'upcoming'
        ..notes = _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null
        ..createdAt = isEditMode
            ? (existingAppointment?.createdAt ?? DateTime.now())
            : DateTime.now()
        ..updatedAt = DateTime.now()
        ..synced = false;

      int appointmentId;
      if (isEditMode) {
        appointment.id = widget.appointmentId;
        await db.updateAppointment(widget.appointmentId!, appointment);
        appointmentId = widget.appointmentId!;
      } else {
        appointmentId = (await db.insertAppointment(appointment))!;
      }

      // Update call log if linked (only for new appointments)
      if (!isEditMode && widget.callLogId != null) {
        final callLog = db.getCallLogById(widget.callLogId!);
        if (callLog != null) {
          callLog
            ..linkedAppointmentId = appointmentId
            ..customerId = customerId
            ..followedUp = true;
          await db.updateCallLog(widget.callLogId!, callLog);
        }
      }

      // Save appointment services (line items) - delete existing and re-insert
      if (isEditMode) {
        await db.deleteAppointmentServicesForAppointment(appointmentId);
      }
      for (final serviceId in _selectedServiceIds) {
        final apptService = AppointmentService()
          ..appointmentId = appointmentId
          ..serviceId = serviceId
          ..priceOverride = _servicePriceOverrides[serviceId]
          ..durationOverride = _serviceDurationOverrides[serviceId]
          ..notes = _serviceNotes[serviceId];
        await db.insertAppointmentService(apptService);
      }

      if (mounted) {
        if (isEditMode) {
          context.goNamed(
            'appointment-detail',
            pathParameters: {'id': appointmentId.toString()},
          );
        } else {
          context.goNamed(
            'booking-confirmation',
            pathParameters: {'appointmentId': appointmentId.toString()},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving appointment: $e'),
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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed('home');
            }
          },
        ),
        title: Text(widget.appointmentId != null ? 'Edit Appointment' : 'New Appointment'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _showVoiceInputSheet,
            tooltip: 'Voice booking',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer Phone
              CompositedTransformTarget(
                link: _layerLink,
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Customer Phone',
                    hintText: 'Enter phone number',
                    prefixIcon: const Icon(Icons.phone),
                    suffixIcon: _existingCustomer != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.all(12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Existing',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _clearExistingCustomer,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    _clearExistingCustomer();
                    if (value.length >= 3) {
                      _searchCustomers(value);
                    } else {
                      _hideSuggestions();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),
              ),

              // Customer Name (only for new customers)
              if (_existingCustomer == null) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    hintText: 'Enter customer name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (_existingCustomer == null &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter a customer name';
                    }
                    return null;
                  },
                ),
              ],

              if (_existingCustomer != null) ...[
                const SizedBox(height: AppSpacing.sm),
                // Customer Info Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 20, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            _existingCustomer!.name,
                            style: AppTypography.bodyLarge,
                          ),
                        ],
                      ),
                      if (_existingCustomer!.address != null &&
                          _existingCustomer!.address!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 20, color: AppColors.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _existingCustomer!.address!,
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () {
                          context.goNamed(
                            'customer-profile',
                            pathParameters: {
                              'id': _existingCustomer!.id.toString()
                            },
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
                        'Services',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: serviceList.map((service) {
                          final isSelected =
                              service.id != null && _selectedServiceIds.contains(service.id);
                          return FilterChip(
                            label: Text(service.title),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (service.id == null) return;
                              setState(() {
                                if (selected) {
                                  _selectedServiceIds.add(service.id!);
                                } else {
                                  _selectedServiceIds.remove(service.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // Selected services cards
                      if (_selectedServiceIds.isNotEmpty)
                        _buildSelectedServicesList(serviceList),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Station Selection
              _buildStationSelection(),

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
                    : Text(widget.appointmentId != null ? 'Update Appointment' : 'Book Appointment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceSelectionCard extends StatefulWidget {
  final Service service;
  final int initialDuration;
  final double initialPrice;
  final String initialNotes;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onRemove;

  const _ServiceSelectionCard({
    required this.service,
    required this.initialDuration,
    required this.initialPrice,
    required this.initialNotes,
    required this.onDurationChanged,
    required this.onPriceChanged,
    required this.onNotesChanged,
    required this.onRemove,
  });

  @override
  State<_ServiceSelectionCard> createState() => _ServiceSelectionCardState();
}

class _ServiceSelectionCardState extends State<_ServiceSelectionCard> {
  late TextEditingController _durationController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.initialDuration.toString(),
    );
    _priceController = TextEditingController(
      text: widget.initialPrice.toStringAsFixed(2),
    );
    _notesController = TextEditingController(
      text: widget.initialNotes,
    );
    _showNotes = widget.initialNotes.isNotEmpty;
  }

  @override
  void dispose() {
    _durationController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.service.title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          prefixText: '\$',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          final price = double.tryParse(value);
                          if (price != null && price >= 0) {
                            widget.onPriceChanged(price);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Duration
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Duration (min)',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          final duration = int.tryParse(value);
                          if (duration != null && duration > 0) {
                            widget.onDurationChanged(duration);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Notes toggle button
          if (!_showNotes)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showNotes = true;
                  });
                },
                icon: const Icon(Icons.note_add, size: 18),
                label: const Text('Add Notes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          // Notes field (shown when _showNotes is true)
          if (_showNotes) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notesController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Service Notes',
                hintText: 'Add notes for this service...',
                alignLabelWithHint: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    setState(() {
                      _showNotes = false;
                      _notesController.clear();
                      widget.onNotesChanged('');
                    });
                  },
                ),
              ),
              onChanged: (value) {
                widget.onNotesChanged(value);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Voice input bottom sheet that parses speech into booking data.
class _VoiceInputSheet extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic> parsed) onDataParsed;

  const _VoiceInputSheet({required this.onDataParsed});

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';
  String _statusText = 'Tap the microphone to speak appointment details';

  // Parsed data
  String? _parsedPhone;
  String? _parsedName;
  DateTime? _parsedDate;
  TimeOfDay? _parsedTime;
  int? _parsedServiceId;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        setState(() {
          _statusText = 'Speech error: ${error.errorMsg}';
          _isListening = false;
        });
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
            if (_lastWords.isNotEmpty) {
              _statusText = 'Processing: "$_lastWords"';
              _parseSpeech(_lastWords);
            }
          });
        }
      },
    );
    setState(() {});
  }

  void _startListening() async {
    if (!_speechAvailable) {
      setState(() {
        _statusText = 'Speech recognition not available on this device';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _statusText = 'Listening...';
      _lastWords = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
          _statusText = _lastWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _parseSpeech(String text) {
    final lower = text.toLowerCase();

    // Parse phone number - look for digit patterns
    final phonePattern = RegExp(r'[\+]?[\d\s\-()]{10,}');
    final phoneMatch = phonePattern.firstMatch(text);
    if (phoneMatch != null) {
      _parsedPhone = phoneMatch.group(0)?.replaceAll(RegExp(r'[^\d+]'), '');
    }

    // Parse name - "with John", "for John", "appointment for John"
    final nameKeywords = ['with ', 'for ', 'appointment for ', 'book appointment for '];
    for (final keyword in nameKeywords) {
      final idx = lower.indexOf(keyword);
      if (idx != -1) {
        final start = idx + keyword.length;
        final end = text.indexOf(' ', start);
        if (end != -1 && end > start) {
          final extractedName = text.substring(start, end).trim();
          if (extractedName.isNotEmpty && extractedName.length <= 30) {
            _parsedName = extractedName;
            break;
          }
        }
      }
    }

    // Parse date - tomorrow, today, specific day names
    if (lower.contains('tomorrow')) {
      _parsedDate = DateTime.now().add(const Duration(days: 1));
    } else if (lower.contains('today')) {
      _parsedDate = DateTime.now();
    } else {
      final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (final day in dayNames) {
        if (lower.contains(day)) {
          _parsedDate = _nextDateForDay(day);
          break;
        }
      }
    }

    // Parse time - "at 3pm", "at 3:30", "in the afternoon"
    final timePatterns = [
      RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)', caseSensitive: false),
      RegExp(r'(?:at|in the)\s*(morning|afternoon|evening)', caseSensitive: false),
    ];
    for (final pattern in timePatterns) {
      final match = pattern.firstMatch(lower);
      if (match != null) {
        if (match.group(1) != null) {
          int hour = int.parse(match.group(1)!);
          final minute = match.group(2) != null ? int.parse(match.group(2)!) : 0;
          final isPM = match.group(3)?.toLowerCase() == 'pm';
          if (isPM && hour < 12) hour += 12;
          _parsedTime = TimeOfDay(hour: hour, minute: minute);
        } else if (match.group(4) != null) {
          final period = match.group(4)!.toLowerCase();
          if (period == 'morning') {
            _parsedTime = const TimeOfDay(hour: 9, minute: 0);
          } else if (period == 'afternoon') {
            _parsedTime = const TimeOfDay(hour: 15, minute: 0);
          } else if (period == 'evening') {
            _parsedTime = const TimeOfDay(hour: 18, minute: 0);
          }
        }
        break;
      }
    }

    // Parse service - match against common service keywords
    final serviceKeywords = ['consultation', 'cut', 'trim', 'style', 'color', 'treatment', 'massage', 'facial', 'cleanup'];
    final services = ref.read(servicesProvider);
    services.whenData((serviceList) {
      for (final keyword in serviceKeywords) {
        if (lower.contains(keyword)) {
          // Find matching service by keyword in title
          for (final service in serviceList) {
            if (service.title.toLowerCase().contains(keyword)) {
              _parsedServiceId = service.id;
              break;
            }
          }
          if (_parsedServiceId != null) break;
        }
      }
    });

    setState(() {
      _statusText = _buildStatusText();
    });
  }

  DateTime _nextDateForDay(String day) {
    final now = DateTime.now();
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final targetDay = days.indexOf(day.toLowerCase());
    if (targetDay == -1) return now;
    final currentDay = now.weekday - 1;
    var daysUntil = targetDay - currentDay;
    if (daysUntil <= 0) daysUntil += 7;
    return now.add(Duration(days: daysUntil));
  }

  String _buildStatusText() {
    final parts = <String>[];
    if (_parsedName != null) parts.add('Customer: $_parsedName');
    if (_parsedDate != null) parts.add('Date: ${DateFormat('MMM d').format(_parsedDate!)}');
    if (_parsedTime != null) parts.add('Time: ${_parsedTime!.format(context)}');
    if (_parsedPhone != null) parts.add('Phone: $_parsedPhone');
    return parts.isEmpty ? 'Say appointment details naturally' : parts.join(' • ');
  }

  void _applyAndClose() {
    final parsed = <String, dynamic>{};
    if (_parsedPhone != null) parsed['phone'] = _parsedPhone;
    if (_parsedName != null) parsed['name'] = _parsedName;
    if (_parsedDate != null) parsed['date'] = _parsedDate;
    if (_parsedTime != null) parsed['time'] = _parsedTime;
    if (_parsedServiceId != null) parsed['serviceId'] = _parsedServiceId;
    widget.onDataParsed(parsed);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text('Voice Booking', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Speak appointment details naturally', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xl),

          // Speech status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isListening ? AppColors.primary : AppColors.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: _isListening ? AppColors.primary : AppColors.secondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(_statusText, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
                if (_lastWords.isNotEmpty && !_isListening) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '"$_lastWords"',
                    style: AppTypography.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.secondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Mic button
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _isListening ? AppColors.primary : AppColors.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: _isListening ? 16 : 8,
                    spreadRadius: _isListening ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: _isListening ? Colors.white : AppColors.primary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_isListening ? 'Tap to stop' : 'Tap to speak', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xl),

          // Parsed results
          if (_parsedName != null || _parsedDate != null || _parsedTime != null || _parsedPhone != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detected:', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (_parsedPhone != null)
                    _ParsedRow(icon: Icons.phone, label: 'Phone', value: _parsedPhone!),
                  if (_parsedName != null)
                    _ParsedRow(icon: Icons.person, label: 'Name', value: _parsedName!),
                  if (_parsedDate != null)
                    _ParsedRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: DateFormat('EEEE, MMM d').format(_parsedDate!),
                    ),
                  if (_parsedTime != null)
                    _ParsedRow(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: _parsedTime!.format(context),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: (_parsedName != null || _parsedDate != null || _parsedTime != null || _parsedPhone != null)
                      ? _applyAndClose
                      : null,
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _ParsedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ParsedRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text('$label: ', style: AppTypography.bodySmall),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
