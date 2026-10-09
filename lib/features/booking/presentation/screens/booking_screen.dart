import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
// Voice booking is intentionally outside the MVP release scope. The package
// and dormant implementation remain commented/preserved for future work.
// import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/config/release_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/service_color_palette.dart';
import '../../../../core/database/collections/collections.dart';
import '../../../../core/utils/age_utils.dart';
import '../../../../core/utils/appointment_notes_formatter.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../auth/presentation/providers/auth_session_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../../core/providers/auth_providers.dart';
import '../../../../core/providers/calendar_providers.dart';
import '../../../../shared/widgets/app_surface_card.dart';
import '../../../../shared/widgets/app_date_picker_sheet.dart';
import '../widgets/appointment_note_card.dart';
import '../../../customers/presentation/widgets/customer_note_card.dart';

class BookingScreen extends ConsumerStatefulWidget {
  final String? prefilledPhone;
  final int? prefilledCustomerId;
  final int? callLogId;
  final DateTime? prefilledDate;
  final int? prefilledServiceId;
  final int? appointmentId; // For edit mode

  const BookingScreen({
    super.key,
    this.prefilledPhone,
    this.prefilledCustomerId,
    this.callLogId,
    this.prefilledDate,
    this.prefilledServiceId,
    this.appointmentId,
  });

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen>
    with UnsavedChangesGuard<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _townController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<int> _selectedServiceIds = [];
  int? _selectedStationId;
  bool _showStationValidationError = false;
  final GlobalKey _stationSectionKey = GlobalKey();
  Customer? _existingCustomer;
  bool _showQuickAdd = false;
  DateTime? _quickAddDob;
  bool _isLoading = false;

  // Customer search suggestions
  List<Customer> _customerSuggestions = [];
  // Retained with the overlay state for the existing suggestion flow.
  // ignore: unused_field
  bool _showSuggestions = false;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _phoneFieldAnchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // Service duration overrides (per appointment, not stored in service defaults)
  final Map<int, int> _serviceDurationOverrides = {};

  // Service price overrides (per appointment)
  final Map<int, double> _servicePriceOverrides = {};

  // Raw drafts ensure an emptied/temporarily invalid override is still dirty.
  final Map<int, String> _serviceDurationDrafts = {};
  final Map<int, String> _servicePriceDrafts = {};

  // Service notes (per appointment)
  final Map<int, String> _serviceNotes = {};

  final List<AppointmentNote> _notes = [];

  bool _syncWithGoogle = false;
  late _BookingFormSnapshot _baseline;
  bool _baselineReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.appointmentId != null) {
      _loadAppointmentForEdit();
    } else {
      final resolvedById = widget.prefilledCustomerId != null &&
          _loadPrefilledCustomer(widget.prefilledCustomerId!);
      if (!resolvedById && widget.prefilledPhone != null) {
        _phoneController.text = widget.prefilledPhone!;
        _checkExistingCustomer();
      }
      if (widget.prefilledDate != null) {
        _selectedDate = widget.prefilledDate!;
        _selectedTime = TimeOfDay.fromDateTime(widget.prefilledDate!);
      }
      if (widget.prefilledServiceId != null) {
        _loadPrefilledService(widget.prefilledServiceId!);
      }
      _captureBaseline();
    }
    for (final controller in [
      _phoneController,
      _nameController,
      _townController,
    ]) {
      controller.addListener(_refreshDirtyState);
    }
  }

  void _refreshDirtyState() {
    if (mounted) setState(() {});
  }

  void _captureBaseline() {
    _baseline = _currentSnapshot();
    _baselineReady = true;
  }

  _BookingFormSnapshot _currentSnapshot() => _BookingFormSnapshot(
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        town: _townController.text.trim(),
        date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ),
        time: _selectedTime,
        selectedServiceIds: List<int>.of(_selectedServiceIds),
        selectedStationId: _selectedStationId,
        existingCustomerId: _existingCustomer?.id,
        existingCustomerPhone: _existingCustomer?.phoneNumber.trim(),
        showQuickAdd: _showQuickAdd,
        quickAddDob: _quickAddDob,
        durationOverrides: Map<int, int>.of(_serviceDurationOverrides),
        priceOverrides: Map<int, double>.of(_servicePriceOverrides),
        durationDrafts: _serviceDurationDrafts.map(
          (key, value) => MapEntry(key, value.trim()),
        ),
        priceDrafts: _servicePriceDrafts.map(
          (key, value) => MapEntry(key, value.trim()),
        ),
        serviceNotes: _serviceNotes.map(
          (key, value) => MapEntry(key, value.trim()),
        ),
        notes: List<AppointmentNote>.of(_notes),
        syncWithGoogle: _syncWithGoogle,
      );

  @override
  bool get hasUnsavedChanges =>
      _baselineReady && !_baseline.matches(_currentSnapshot());

  Future<void> _leaveScreen() async {
    _hideSuggestions();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('home');
    }
  }

  bool _loadPrefilledCustomer(int customerId) {
    final customer = ref.read(homeHiveProvider).getCustomerById(customerId);
    if (customer == null) return false;

    _existingCustomer = customer;
    _showQuickAdd = false;
    _phoneController.clear();
    return true;
  }

  void _loadPrefilledService(int serviceId) {
    final service = ref.read(homeHiveProvider).getServiceById(serviceId);
    if (service == null || service.isActive != true) return;

    _selectedServiceIds = [serviceId];
    _serviceDurationDrafts[serviceId] =
        service.defaultDurationMinutes.toString();
    _servicePriceDrafts[serviceId] = service.cost.toStringAsFixed(2);
  }

  Future<void> _loadAppointmentForEdit() async {
    final db = ref.read(homeHiveProvider);
    final appointment = db.getAppointmentById(widget.appointmentId!);
    if (appointment == null) {
      _captureBaseline();
      return;
    }

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
        final duration =
            appointment.endTime.difference(appointment.startTime).inMinutes;
        _serviceDurationOverrides[appointment.serviceId!] = duration;
        _serviceDurationDrafts[appointment.serviceId!] = duration.toString();
        _servicePriceDrafts[appointment.serviceId!] =
            service.cost.toStringAsFixed(2);
      }
    }

    // Populate station
    _selectedStationId = appointment.stationId;

    // Legacy free-text notes intentionally remain unmigrated. Only structured
    // notes are loaded into the current editor.
    _notes
      ..clear()
      ..addAll(appointment.notes);

    // Populate appointment services (line items)
    final appointmentServices =
        db.getAppointmentServicesForAppointment(appointment.id!);
    for (final apptService in appointmentServices) {
      final serviceId = apptService.serviceId;
      if (serviceId != null &&
          (_selectedServiceIds.isEmpty ||
              _selectedServiceIds.single == serviceId)) {
        // Booking now supports exactly one service. Prefer the appointment's
        // primary service; legacy records without one use their first line
        // item and are normalized to one service when next saved.
        if (_selectedServiceIds.isEmpty) {
          _selectedServiceIds = [serviceId];
        }
        if (apptService.durationOverride != null) {
          _serviceDurationOverrides[serviceId] = apptService.durationOverride!;
        }
        if (apptService.priceOverride != null) {
          _servicePriceOverrides[serviceId] = apptService.priceOverride!;
        }
        if (apptService.notes != null && apptService.notes!.isNotEmpty) {
          _serviceNotes[serviceId] = apptService.notes!;
        }
        final service = db.getServiceById(serviceId);
        final duration = apptService.durationOverride ??
            service?.defaultDurationMinutes ??
            30;
        final price = apptService.priceOverride ?? service?.cost ?? 0;
        _serviceDurationDrafts[serviceId] = duration.toString();
        _servicePriceDrafts[serviceId] = price.toStringAsFixed(2);
        break;
      }
    }

    _captureBaseline();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _townController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingCustomer() async {
    final db = ref.read(homeHiveProvider);
    final institutionId = ref.read(authSessionProvider)?.institutionId;
    final customer = institutionId == null
        ? null
        : db.getCustomerByPhoneForInstitution(
            _phoneController.text,
            institutionId,
          );
    if (!mounted) return;

    if (customer != null) {
      setState(() {
        _existingCustomer = customer;
        _showQuickAdd = false;
      });
    } else {
      // Routed-in phone numbers bypass the manual search dropdown. If no
      // customer matches, open the same deferred quick-add flow as its Add
      // action instead of falling back to the legacy name-only field.
      setState(() {
        _existingCustomer = null;
        _showQuickAdd = true;
        _nameController.clear();
        _townController.clear();
        _quickAddDob = null;
      });
    }
    _hideSuggestions();
  }

  Future<void> _searchCustomers(String query) async {
    if (query.length < 3) {
      _hideSuggestions();
      return;
    }

    final db = ref.read(homeHiveProvider);
    final institutionId = ref.read(authSessionProvider)?.institutionId;
    final allCustomers = institutionId == null
        ? const <Customer>[]
        : db.getCustomersForInstitution(institutionId);
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
        _showSuggestions = true;
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
    final renderBox =
        _phoneFieldAnchorKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final typedPhone = _phoneController.text.trim();
    final digitCount = RegExp(r'\d').allMatches(typedPhone).length;
    final showAddRow = digitCount >= 3 &&
        !ref
            .read(homeHiveProvider)
            .getCustomersForInstitution(
              ref.read(authSessionProvider)?.institutionId ?? '',
            )
            .any((customer) =>
                phoneNumbersMatch(customer.phoneNumber, typedPhone));

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
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _customerSuggestions.length + (showAddRow ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _customerSuggestions.length) {
                    final colors = Theme.of(context).colorScheme;
                    return Container(
                      key: const Key('booking-add-customer-row'),
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              color: colors.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              typedPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton.tonal(
                            key: const Key('booking-add-customer-pill'),
                            onPressed: () => _startQuickAdd(typedPhone),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 48),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                  }
                  final customer = _customerSuggestions[index];
                  final name = customer.name.trim();
                  final phone = customer.phoneNumber.trim();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(name.isEmpty ? 'Unnamed customer' : name),
                    subtitle: phone.isEmpty ? null : Text(phone),
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
    setState(() {
      _existingCustomer = customer;
      _showQuickAdd = false;
      _showSuggestions = false;
    });
    // The resolved customer card is now the source of truth. Clear the search
    // query because this screen does not edit the customer record itself.
    _phoneController.clear();
    _hideSuggestions();
  }

  void _clearExistingCustomer() {
    setState(() {
      _existingCustomer = null;
      _showQuickAdd = false;
    });
  }

  void _startQuickAdd(String phone) {
    _hideSuggestions();
    setState(() {
      _phoneController.text = phone;
      _showQuickAdd = true;
      _nameController.clear();
      _townController.clear();
      _quickAddDob = null;
    });
  }

  Future<void> _selectQuickAddDob() async {
    final now = DateTime.now();
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _quickAddDob ?? DateTime(now.year - 25),
      minimumDate: DateTime(1900),
      maximumDate: DateTime(now.year, now.month, now.day),
      title: 'Select date of birth',
    );
    if (selected != null && mounted) {
      setState(() => _quickAddDob = selected);
    }
  }

  Widget _buildQuickAddCustomerCard() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('booking-quick-add-card'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.person_add_outlined, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Quick-add customer',
                  style: AppTypography.titleMedium.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(Icons.phone_outlined,
                  size: 18, color: colors.onSecondaryContainer),
              label: Text(_phoneController.text.trim()),
              backgroundColor: colors.secondaryContainer,
              labelStyle: AppTypography.labelMedium.copyWith(
                color: colors.onSecondaryContainer,
              ),
              side: BorderSide.none,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const Key('booking-quick-add-name-field'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name *',
              hintText: 'Enter customer name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (_showQuickAdd && (value == null || value.trim().isEmpty)) {
                return 'Please enter a customer name';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const Key('booking-quick-add-town-field'),
            controller: _townController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Town (optional)',
              hintText: 'Enter town',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            button: true,
            label: _quickAddDob == null
                ? 'Select date of birth, optional'
                : 'Date of birth ${DateFormat.yMMMMd().format(_quickAddDob!)}',
            child: InkWell(
              key: const Key('booking-quick-add-dob-field'),
              onTap: _selectQuickAddDob,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of birth (optional)',
                  prefixIcon: Icon(Icons.cake_outlined),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _quickAddDob == null
                      ? 'Select date'
                      : DateFormat.yMMMd().format(_quickAddDob!),
                  style: AppTypography.bodyLarge.copyWith(
                    color: _quickAddDob == null
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingCustomerCard(Customer customer) {
    final colors = Theme.of(context).colorScheme;
    final name = customer.name.trim();
    final phone = customer.phoneNumber.trim();
    final city = customer.city?.trim() ?? '';
    final dob = customer.dob;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final notesRailHeight = 132.0 + ((textScale - 1).clamp(0.0, 2.0) * 64.0);
    return AppSurfaceCard(
      key: const Key('booking-existing-customer-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name.isEmpty ? 'Unnamed customer' : name,
                  style: AppTypography.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (phone.isNotEmpty)
                Chip(
                  avatar: Icon(Icons.phone_outlined,
                      size: 18, color: colors.onSecondaryContainer),
                  label: Text(phone),
                  backgroundColor: colors.secondaryContainer,
                  labelStyle: AppTypography.labelMedium.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                  side: BorderSide.none,
                ),
              if (dob != null)
                Chip(
                  avatar: Icon(Icons.cake_outlined,
                      size: 18, color: colors.onTertiaryContainer),
                  label: Text('Age ${currentAge(dob)}'),
                  backgroundColor: colors.tertiaryContainer,
                  labelStyle: AppTypography.labelMedium.copyWith(
                    color: colors.onTertiaryContainer,
                  ),
                  side: BorderSide.none,
                ),
            ],
          ),
          if (city.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 20, color: colors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(city, style: AppTypography.bodyMedium)),
              ],
            ),
          ],
          if (customer.notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Customer notes',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (customer.notes.length > 1)
                  Text(
                    '${customer.notes.length} notes • Swipe',
                    style: AppTypography.labelSmall.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (customer.notes.length == 1)
              CustomerNoteCard(note: customer.notes.single)
            else
              SizedBox(
                height: notesRailHeight,
                child: ListView.separated(
                  key: const Key('booking-customer-notes-carousel'),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  itemCount: customer.notes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final note = customer.notes[index];
                    return SizedBox(
                      width: 248,
                      child: CustomerNoteCard(
                        note: note,
                        titleMaxLines: 1,
                        descriptionMaxLines: 3,
                      ),
                    );
                  },
                ),
              ),
          ],
          if (customer.id != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () {
                context.goNamed(
                  'customer-profile',
                  pathParameters: {'id': customer.id.toString()},
                );
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'View Customer Profile',
                    style: AppTypography.labelMedium.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedServicesList(List<Service> allServices) {
    final colors = Theme.of(context).colorScheme;
    final selectedServices = allServices
        .where((s) => s.id != null && _selectedServiceIds.contains(s.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Service',
          style: AppTypography.labelMedium.copyWith(
            color: colors.onSurfaceVariant,
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
              onDurationTextChanged: (duration) {
                setState(() {
                  _serviceDurationDrafts[service.id!] = duration;
                });
              },
              onPriceChanged: (price) {
                setState(() {
                  _servicePriceOverrides[service.id!] = price;
                });
              },
              onPriceTextChanged: (price) {
                setState(() {
                  _servicePriceDrafts[service.id!] = price;
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
                  _serviceDurationDrafts.remove(service.id);
                  _servicePriceDrafts.remove(service.id);
                  _serviceNotes.remove(service.id);
                });
              },
            )),
        const SizedBox(height: AppSpacing.md),
        // Total summary
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.3),
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
                      color: colors.primary,
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
                      color: colors.primary,
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

  void _selectSingleService(Service service) {
    final serviceId = service.id;
    if (serviceId == null ||
        (_selectedServiceIds.length == 1 &&
            _selectedServiceIds.first == serviceId)) {
      return;
    }

    setState(() {
      final previousIds = List<int>.of(_selectedServiceIds);
      _selectedServiceIds = [serviceId];

      for (final previousId in previousIds) {
        if (previousId == serviceId) continue;
        _serviceDurationOverrides.remove(previousId);
        _servicePriceOverrides.remove(previousId);
        _serviceDurationDrafts.remove(previousId);
        _servicePriceDrafts.remove(previousId);
        _serviceNotes.remove(previousId);
      }

      _serviceDurationDrafts.putIfAbsent(
        serviceId,
        () => service.defaultDurationMinutes.toString(),
      );
      _servicePriceDrafts.putIfAbsent(
        serviceId,
        () => service.cost.toStringAsFixed(2),
      );
    });
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
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _selectedDate,
      minimumDate: now,
      maximumDate: now.add(const Duration(days: 365)),
      title: 'Select appointment date',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: _selectedTime,
      title: 'Select time',
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _showVoiceInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0),
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
    final colors = Theme.of(context).colorScheme;
    final stations = ref.watch(serviceStationsProvider);

    return Column(
      key: _stationSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location (Service Station) *',
          style: AppTypography.labelMedium.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select where this appointment will take place.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        stations.when(
          data: (stationList) {
            final selectableStations =
                stationList.where((station) => station.id != null).toList();
            if (selectableStations.isEmpty) {
              return Text(
                'No service stations are available. Add one before booking.',
                style: AppTypography.bodySmall.copyWith(color: colors.error),
              );
            }
            return Column(
              children: selectableStations.map((station) {
                return RadioListTile<int>(
                  key: ValueKey('booking-station-${station.id}'),
                  value: station.id!,
                  groupValue: _selectedStationId,
                  onChanged: (stationId) {
                    if (stationId == null) return;
                    setState(() {
                      _selectedStationId = stationId;
                      _showStationValidationError = false;
                    });
                  },
                  title: Text(station.name),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LinearProgressIndicator(),
          ),
          error: (_, __) => Text(
            'Service stations could not be loaded. Try again.',
            style: AppTypography.bodySmall.copyWith(color: colors.error),
          ),
        ),
        if (_showStationValidationError)
          Semantics(
            liveRegion: true,
            child: Text(
              'Select a service station to continue.',
              style: AppTypography.bodySmall.copyWith(color: colors.error),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<bool> _validateStationSelection() async {
    final selectedStationId = _selectedStationId;
    final availableStations = ref.read(serviceStationsProvider).asData?.value ??
        const <ServiceStation>[];
    final hasAvailableSelection = selectedStationId != null &&
        availableStations.any((station) => station.id == selectedStationId);
    if (hasAvailableSelection) return true;

    setState(() {
      _selectedStationId = null;
      _showStationValidationError = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;

    final stationContext = _stationSectionKey.currentContext;
    if (stationContext != null && stationContext.mounted) {
      await Scrollable.ensureVisible(
        stationContext,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('A service station is required.'),
        ),
      );
    return false;
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
              style: AppTypography.labelMedium.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Semantics(
              label: '${_notes.length} appointment notes',
              child: Container(
                key: const Key('appointment-notes-count'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '${_notes.length}',
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final note in _notes) ...[
            AppointmentNoteCard(
              note: note,
              truncateDescription: true,
              onEdit: () => _showNoteEditor(note: note),
              onDelete: () => _deleteNote(note),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ] else
          const SizedBox(height: AppSpacing.sm),
        AddAppointmentNoteButton(
          onPressed: _showNoteEditor,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _showNoteEditor({AppointmentNote? note}) async {
    final colors = Theme.of(context).colorScheme;
    final result = await showModalBottomSheet<AppointmentNote>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => _AppointmentNoteEditorSheet(note: note),
    );

    if (result == null || !mounted) return;

    setState(() {
      final existingIndex = _notes.indexWhere((item) => item.id == result.id);
      if (existingIndex == -1) {
        _notes.add(result);
      } else {
        _notes[existingIndex] = result;
      }
    });
  }

  void _deleteNote(AppointmentNote note) {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    setState(() => _notes.removeAt(index));

    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${note.title}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted || _notes.any((item) => item.id == note.id)) return;
            setState(() {
              final restoredIndex =
                  index > _notes.length ? _notes.length : index;
              _notes.insert(restoredIndex, note);
            });
          },
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Create mode must resolve free-form search text through a suggestion or
    // quick-add. Otherwise a typed name could be persisted as a phone number.
    // Edit mode already resolves its customer from the loaded appointment.
    if (widget.appointmentId == null &&
        _existingCustomer == null &&
        !_showQuickAdd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a customer from the list, or tap "Add" to create a new one.',
          ),
        ),
      );
      return;
    }

    if (!await _validateStationSelection()) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final db = ref.read(homeHiveProvider);
      final session = ref.read(authSessionProvider);
      final sessionInstitutionId = session?.institutionId;
      if (sessionInstitutionId == null || sessionInstitutionId.isEmpty) {
        throw StateError('An institution is required to save an appointment.');
      }
      final phone = _phoneController.text.trim();

      // Get or create customer
      int customerId;
      Customer? customer;
      final matchedCustomer = _existingCustomer == null
          ? db.getCustomerByPhoneForInstitution(phone, sessionInstitutionId)
          : null;
      if (_existingCustomer != null || matchedCustomer != null) {
        final resolvedCustomer = _existingCustomer ?? matchedCustomer!;
        customerId = resolvedCustomer.id!;
        customer = resolvedCustomer;
      } else {
        // Create new customer
        final name = _nameController.text.trim();
        final newCustomer = Customer()
          ..institutionId = sessionInstitutionId
          ..phoneNumber = phone
          ..name = name.isNotEmpty ? name : 'New Customer'
          ..city = _showQuickAdd && _townController.text.trim().isNotEmpty
              ? _townController.text.trim()
              : null
          ..dob = _showQuickAdd ? _quickAddDob : null
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now()
          ..synced = false;
        customerId = (await db.insertCustomer(newCustomer))!;
        customer = newCustomer;
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
      final existingAppointment =
          isEditMode ? db.getAppointmentById(widget.appointmentId!) : null;

      // Create or update appointment
      final appointment = Appointment()
        ..institutionId = isEditMode
            ? existingAppointment?.institutionId
            : sessionInstitutionId
        ..handledByUserId =
            isEditMode ? existingAppointment?.handledByUserId : session!.userId
        ..customerId = customerId
        ..serviceId = primaryServiceId
        ..stationId = _selectedStationId
        ..startTime = startTime
        ..endTime = endTime
        ..status = isEditMode
            ? (existingAppointment?.status ?? 'upcoming')
            : 'upcoming'
        ..notes = List<AppointmentNote>.of(_notes)
        ..createdAt = isEditMode
            ? (existingAppointment?.createdAt ?? DateTime.now())
            : DateTime.now()
        ..updatedAt = DateTime.now()
        ..synced = false
        ..syncWithGoogle =
            ReleaseScope.googleCalendarSyncEnabled && _syncWithGoogle;

      int appointmentId;
      if (isEditMode) {
        appointment.id = widget.appointmentId;
        await db.updateAppointment(widget.appointmentId!, appointment);
        appointmentId = widget.appointmentId!;
      } else {
        appointmentId = (await db.insertAppointment(appointment))!;

        // Google Calendar sync (non-blocking - local save always succeeds)
        if (ReleaseScope.googleCalendarSyncEnabled && _syncWithGoogle) {
          final authService = ref.read(googleAuthServiceProvider);
          if (authService.isSignedIn) {
            try {
              final googleEventId =
                  await ref.read(googleCalendarServiceProvider).createEvent(
                        title:
                            'Appointment: ${customer.name.trim().isEmpty ? 'Unnamed customer' : customer.name.trim()}',
                        start: startTime,
                        end: endTime,
                        description: formatAppointmentNotesForCalendar(_notes),
                      );
              // Update appointment with Google Event ID
              appointment.googleEventId = googleEventId;
              await db.updateAppointment(appointmentId, appointment);
            } catch (e) {
              // Google sync failed - appointment already saved to Hive
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved locally. Google sync failed: $e'),
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                );
              }
            }
          }
        }
      }

      // Update call log if linked (only for new appointments)
      if (!isEditMode && widget.callLogId != null) {
        final callLog = db.getCallLogById(widget.callLogId!);
        if (callLog != null &&
            callLog.institutionId == appointment.institutionId) {
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
          ..institutionId = appointment.institutionId
          ..appointmentId = appointmentId
          ..serviceId = serviceId
          ..priceOverride = _servicePriceOverrides[serviceId]
          ..durationOverride = _serviceDurationOverrides[serviceId]
          ..notes = _serviceNotes[serviceId];
        await db.insertAppointmentService(apptService);
      }

      await allowPopWithoutPrompt();
      if (mounted) {
        if (isEditMode) {
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.goNamed(
              'appointment-detail',
              pathParameters: {'id': appointmentId.toString()},
            );
          }
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

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final colors = Theme.of(context).colorScheme;

    return PopScope<Object?>(
      canPop: canPopWithoutDiscardConfirmation,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await handleCloseRequest(_leaveScreen);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => handleCloseRequest(_leaveScreen),
          ),
          title: Text(widget.appointmentId != null
              ? 'Edit Appointment'
              : 'New Appointment'),
          centerTitle: true,
          actions: [
            // Intentionally hidden for the MVP. Keep the entry point wired so a
            // future release can restore it through the central release scope.
            if (ReleaseScope.voiceBookingEnabled)
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
                // Customer search. A suggestion selection or the phone-only Add
                // action resolves the customer shown below this field.
                CompositedTransformTarget(
                  key: _phoneFieldAnchorKey,
                  link: _layerLink,
                  child: TextFormField(
                    key: const Key('booking-phone-field'),
                    controller: _phoneController,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText: 'Customer name or phone',
                      hintText: 'Search by name or phone number',
                      prefixIcon: const Icon(Icons.search),
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
                                    color: colors.primaryContainer
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Existing',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: _clearExistingCustomer,
                                  tooltip: 'Clear selected customer',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
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
                      if (_existingCustomer != null || _showQuickAdd) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name or phone number';
                      }
                      return null;
                    },
                  ),
                ),

                if (_showQuickAdd) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildQuickAddCustomerCard(),
                ],

                if (_existingCustomer != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildExistingCustomerCard(_existingCustomer!),
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
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: serviceList.map((service) {
                            final isSelected = service.id != null &&
                                _selectedServiceIds.contains(service.id);
                            return _ServiceRadioPill(
                              key: ValueKey('booking-service-${service.id}'),
                              service: service,
                              selected: isSelected,
                              onSelected: service.id == null
                                  ? null
                                  : () => _selectSingleService(service),
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
                _buildNotesSection(),

                // Google Calendar Sync (outside the first iOS release scope)
                if (ReleaseScope.googleCalendarSyncEnabled)
                  Consumer(
                    builder: (context, ref, _) {
                      final authService = ref.watch(googleAuthServiceProvider);
                      if (!authService.isSignedIn) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          CheckboxListTile(
                            value: _syncWithGoogle,
                            onChanged: (value) {
                              setState(() {
                                _syncWithGoogle = value ?? false;
                              });
                            },
                            title: const Text('Add to Google Calendar'),
                            subtitle: const Text(
                              'Creates an event in your primary Google Calendar',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      );
                    },
                  ),

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
                      : Text(widget.appointmentId != null
                          ? 'Update Appointment'
                          : 'Book Appointment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingFormSnapshot {
  final String phone;
  final String name;
  final String town;
  final DateTime date;
  final TimeOfDay time;
  final List<int> selectedServiceIds;
  final int? selectedStationId;
  final int? existingCustomerId;
  final String? existingCustomerPhone;
  final bool showQuickAdd;
  final DateTime? quickAddDob;
  final Map<int, int> durationOverrides;
  final Map<int, double> priceOverrides;
  final Map<int, String> durationDrafts;
  final Map<int, String> priceDrafts;
  final Map<int, String> serviceNotes;
  final List<AppointmentNote> notes;
  final bool syncWithGoogle;

  const _BookingFormSnapshot({
    required this.phone,
    required this.name,
    required this.town,
    required this.date,
    required this.time,
    required this.selectedServiceIds,
    required this.selectedStationId,
    required this.existingCustomerId,
    required this.existingCustomerPhone,
    required this.showQuickAdd,
    required this.quickAddDob,
    required this.durationOverrides,
    required this.priceOverrides,
    required this.durationDrafts,
    required this.priceDrafts,
    required this.serviceNotes,
    required this.notes,
    required this.syncWithGoogle,
  });

  bool matches(_BookingFormSnapshot other) =>
      phone == other.phone &&
      name == other.name &&
      town == other.town &&
      date == other.date &&
      time == other.time &&
      orderedListsEqual(selectedServiceIds, other.selectedServiceIds,
          (first, second) => first == second) &&
      selectedStationId == other.selectedStationId &&
      existingCustomerId == other.existingCustomerId &&
      existingCustomerPhone == other.existingCustomerPhone &&
      showQuickAdd == other.showQuickAdd &&
      quickAddDob == other.quickAddDob &&
      mapsEqualByValue(durationOverrides, other.durationOverrides) &&
      mapsEqualByValue(priceOverrides, other.priceOverrides) &&
      mapsEqualByValue(durationDrafts, other.durationDrafts) &&
      mapsEqualByValue(priceDrafts, other.priceDrafts) &&
      mapsEqualByValue(serviceNotes, other.serviceNotes) &&
      orderedListsEqual(notes, other.notes, _notesEqual) &&
      syncWithGoogle == other.syncWithGoogle;

  static bool _notesEqual(AppointmentNote first, AppointmentNote second) =>
      first.id == second.id &&
      first.title.trim() == second.title.trim() &&
      (first.description ?? '').trim() == (second.description ?? '').trim() &&
      first.createdAt == second.createdAt;
}

class _AppointmentNoteEditorSheet extends StatefulWidget {
  final AppointmentNote? note;

  const _AppointmentNoteEditorSheet({this.note});

  @override
  State<_AppointmentNoteEditorSheet> createState() =>
      _AppointmentNoteEditorSheetState();
}

class _AppointmentNoteEditorSheetState
    extends State<_AppointmentNoteEditorSheet> {
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
    final note = widget.note == null
        ? AppointmentNote(
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

    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
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
                key: const Key('appointment-note-title-field'),
                controller: _titleController,
                autofocus: !_isEditing,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Preparation instructions',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a note title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('appointment-note-description-field'),
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
                      key: const Key('cancel-appointment-note'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      key: const Key('save-appointment-note'),
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

class _ServiceRadioPill extends StatelessWidget {
  const _ServiceRadioPill({
    super.key,
    required this.service,
    required this.selected,
    required this.onSelected,
  });

  final Service service;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final savedAccent = ServiceColorPalette.resolveOrNull(service.colorValue);
    // Curated service colors intentionally preserve domain identity across
    // institution presets. Their foregrounds are contrast-checked; legacy
    // services fall back to the active semantic theme colors.
    final accentColor = savedAccent?.color ?? colors.primary;
    final onAccentColor = savedAccent?.onColor ?? colors.onPrimary;
    final foregroundColor = selected ? onAccentColor : colors.onSurface;

    return Semantics(
      container: true,
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onSelected != null,
      label: service.title,
      value: selected ? 'Selected' : 'Not selected',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? accentColor : colors.surfaceContainerLowest,
          shape: StadiumBorder(
            side: BorderSide(
              color:
                  selected ? accentColor : accentColor.withValues(alpha: 0.62),
              width: selected ? 0 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSelected,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? onAccentColor : accentColor,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        service.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium.copyWith(
                          color: foregroundColor,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
  final ValueChanged<String> onDurationTextChanged;
  final ValueChanged<double> onPriceChanged;
  final ValueChanged<String> onPriceTextChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onRemove;

  const _ServiceSelectionCard({
    required this.service,
    required this.initialDuration,
    required this.initialPrice,
    required this.initialNotes,
    required this.onDurationChanged,
    required this.onDurationTextChanged,
    required this.onPriceChanged,
    required this.onPriceTextChanged,
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: colors.outlineVariant,
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
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          prefixText: '\$',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          widget.onPriceTextChanged(value);
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
                        color: colors.onSurfaceVariant,
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
                          widget.onDurationTextChanged(value);
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
                  foregroundColor: colors.onSurfaceVariant,
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

/// Dormant voice-input prototype retained for a post-MVP release.
///
/// Do not expose this UI by changing [ReleaseScope.voiceBookingEnabled] until
/// speech dependencies, permissions, parsing behavior, and native builds have
/// been revalidated as a separately planned feature.
class _VoiceInputSheet extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic> parsed) onDataParsed;

  const _VoiceInputSheet({required this.onDataParsed});

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet> {
  // speech_to_text is not included in the MVP dependency set.
  bool _isListening = false;
  // Retained for the dormant post-MVP voice-booking implementation.
  // ignore: unused_field
  bool _speechAvailable = false;
  final String _lastWords = '';
  String _statusText = 'Voice booking is planned for a future release';

  // Parsed data
  String? _parsedPhone;
  String? _parsedName;
  DateTime? _parsedDate;
  TimeOfDay? _parsedTime;
  int? _parsedServiceId;

  @override
  void initState() {
    super.initState();
    // Intentionally dormant for the MVP release.
  }

  // ignore: unused_element
  Future<void> _initSpeech() async {
    setState(() {
      _speechAvailable = false;
      _statusText = 'Voice booking is planned for a future release';
    });
  }

  void _startListening() async {
    setState(() {
      _statusText = 'Voice booking is planned for a future release';
    });
  }

  void _stopListening() async {
    setState(() {
      _isListening = false;
    });
  }

  // ignore: unused_element
  void _parseSpeech(String text) {
    // Dormant until voice booking is formally brought into release scope.
  }

  // ignore: unused_element
  DateTime _nextDateForDay(String day) {
    final now = DateTime.now();
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final targetDay = days.indexOf(day.toLowerCase());
    if (targetDay == -1) return now;
    final currentDay = now.weekday - 1;
    var daysUntil = targetDay - currentDay;
    if (daysUntil <= 0) daysUntil += 7;
    return now.add(Duration(days: daysUntil));
  }

  // ignore: unused_element
  String _buildStatusText() {
    final parts = <String>[];
    if (_parsedName != null) parts.add('Customer: $_parsedName');
    if (_parsedDate != null) {
      parts.add('Date: ${DateFormat('MMM d').format(_parsedDate!)}');
    }
    if (_parsedTime != null) parts.add('Time: ${_parsedTime!.format(context)}');
    if (_parsedPhone != null) parts.add('Phone: $_parsedPhone');
    return parts.isEmpty
        ? 'Say appointment details naturally'
        : parts.join(' • ');
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Title
          Text('Voice Booking', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Speak appointment details naturally',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xl),

          // Speech status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: _isListening ? colors.primary : colors.outlineVariant,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color:
                      _isListening ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(_statusText,
                    style: AppTypography.bodyMedium,
                    textAlign: TextAlign.center),
                if (_lastWords.isNotEmpty && !_isListening) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '"$_lastWords"',
                    style: AppTypography.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colors.onSurfaceVariant,
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
                color: _isListening ? colors.primary : colors.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: AppShadows.activeIndicator(
                  colors.primary,
                  active: _isListening,
                ),
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                color: _isListening ? colors.onPrimary : colors.primary,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_isListening ? 'Tap to stop' : 'Tap to speak',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xl),

          // Parsed results
          if (_parsedName != null ||
              _parsedDate != null ||
              _parsedTime != null ||
              _parsedPhone != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detected:', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  if (_parsedPhone != null)
                    _ParsedRow(
                        icon: Icons.phone,
                        label: 'Phone',
                        value: _parsedPhone!),
                  if (_parsedName != null)
                    _ParsedRow(
                        icon: Icons.person, label: 'Name', value: _parsedName!),
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
                  onPressed: (_parsedName != null ||
                          _parsedDate != null ||
                          _parsedTime != null ||
                          _parsedPhone != null)
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

  const _ParsedRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text('$label: ', style: AppTypography.bodySmall),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
