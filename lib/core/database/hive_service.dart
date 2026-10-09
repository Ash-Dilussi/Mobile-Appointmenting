import 'dart:async';
import 'dart:developer' as developer;

import 'package:hive_flutter/hive_flutter.dart';
import 'collections/collections.dart';
import 'insights_data.dart';
import '../../features/call_log/data/models/call_log_entry.dart';
import '../utils/phone_number_utils.dart';

class HiveService {
  static final HiveService _instance = HiveService._();
  static HiveService get instance => _instance;
  factory HiveService() => _instance;
  HiveService._();

  static const String customersBox = 'customers';
  static const String servicesBox = 'services';
  static const String appointmentsBox = 'appointments';
  static const String callLogsBox = 'callLogs';
  static const String syncQueueBox = 'syncQueue';
  static const String serviceStationsBox = 'serviceStations';
  static const String appointmentServicesBox = 'appointmentServices';
  static const String institutionsBox = 'institutions';
  static const String usersBox = 'users';
  static const String leaveRequestsBox = 'leaveRequests';
  static const String subscriptionBoxName = 'subscription';

  late Box<Customer> _customersBox;
  late Box<Service> _servicesBox;
  late Box<Appointment> _appointmentsBox;
  late Box<CallLog> _callLogsBox;
  late Box<SyncQueueItem> _syncQueueBox;
  late Box<ServiceStation> _serviceStationsBox;
  late Box<AppointmentService> _appointmentServicesBox;
  late Box<Institution> _institutionsBox;
  late Box<User> _usersBox;
  late Box<LeaveRequest> _leaveRequestsBox;
  late Box<String> _subscriptionBox;

  Future<void> init() async {
    // Provide explicit subdirectory for Android 11+ (API 30+) scoped storage compliance
    await Hive.initFlutter('bookly_hive');

    // Register adapters
    Hive.registerAdapter(CustomerNoteAdapter());
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(ServiceAdapter());
    Hive.registerAdapter(AppointmentNoteAdapter());
    Hive.registerAdapter(AppointmentAdapter());
    Hive.registerAdapter(CallLogAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());
    Hive.registerAdapter(ServiceStationAdapter());
    Hive.registerAdapter(AppointmentServiceAdapter());
    Hive.registerAdapter(InstitutionAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(LeaveRequestAdapter());
    Hive.registerAdapter(CallLogEntryAdapter());

    // Hive box initialization is intentionally serial. Concurrent openBox
    // calls can contend on Hive's shared initialization/file locks.
    _customersBox = await Hive.openBox<Customer>(customersBox);
    _servicesBox = await Hive.openBox<Service>(servicesBox);
    _appointmentsBox = await Hive.openBox<Appointment>(appointmentsBox);
    _callLogsBox = await Hive.openBox<CallLog>(callLogsBox);
    _syncQueueBox = await Hive.openBox<SyncQueueItem>(syncQueueBox);
    _serviceStationsBox =
        await Hive.openBox<ServiceStation>(serviceStationsBox);
    _appointmentServicesBox =
        await Hive.openBox<AppointmentService>(appointmentServicesBox);
    _institutionsBox = await Hive.openBox<Institution>(institutionsBox);
    _usersBox = await Hive.openBox<User>(usersBox);
    _leaveRequestsBox = await Hive.openBox<LeaveRequest>(leaveRequestsBox);
    _subscriptionBox = await Hive.openBox<String>(subscriptionBoxName);
    await Hive.openBox<CallLogEntry>(CallLogBox.boxName);
  }

  /// Public getter for subscription box — use after [init()] has completed.
  Box<String> get subscriptionBox => _subscriptionBox;

  Future<void> clearAllData() async {
    await _customersBox.clear();
    await _servicesBox.clear();
    await _appointmentsBox.clear();
    await _callLogsBox.clear();
    await _syncQueueBox.clear();
    await _serviceStationsBox.clear();
    await _appointmentServicesBox.clear();
    await _institutionsBox.clear();
    await _usersBox.clear();
    await _leaveRequestsBox.clear();
    await _subscriptionBox.clear();
    if (Hive.isBoxOpen(CallLogBox.boxName)) {
      await Hive.box<CallLogEntry>(CallLogBox.boxName).clear();
    }
  }

  // Customer operations
  List<Customer> getAllCustomers() => _customersBox.values.toList();

  Stream<List<Customer>> watchAllCustomers() {
    final controller = StreamController<List<Customer>>();
    controller.add(getAllCustomers());
    final subscription = _customersBox.watch().listen((_) {
      controller.add(getAllCustomers());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  Customer? getCustomerById(int id) {
    try {
      return _customersBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Customer? getCustomerByPhone(String phone) {
    try {
      return _customersBox.values.firstWhere(
        (c) => phoneNumbersMatch(c.phoneNumber, phone),
      );
    } catch (e) {
      return null;
    }
  }

  Customer? getCustomerByPhoneForInstitution(
    String phone,
    String institutionId,
  ) {
    try {
      return _customersBox.values.firstWhere(
        (customer) =>
            customer.institutionId == institutionId &&
            phoneNumbersMatch(customer.phoneNumber, phone),
      );
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertCustomer(Customer customer) async {
    try {
      customer.createdAt = DateTime.now();
      customer.updatedAt = DateTime.now();
      customer.synced = false;
      final key = await _customersBox.add(customer);
      customer.id = key;
      await customer.save();
      // Link any existing call logs to this new customer
      await linkCallLogsToCustomer(customer);
      return key;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateCustomer(int id, Customer customer) async {
    try {
      customer.id = id;
      customer.updatedAt = DateTime.now();
      customer.synced = false;
      await _customersBox.put(id, customer);
      // Re-link call logs in case phone number changed
      await linkCallLogsToCustomer(customer);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    try {
      await _customersBox.delete(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Links all unlinked call logs to a customer based on phone number match.
  /// Called after insertCustomer or updateCustomer (in case phone number changed).
  Future<void> linkCallLogsToCustomer(Customer customer) async {
    final institutionId = customer.institutionId;
    if (customer.id == null ||
        customer.phoneNumber.isEmpty ||
        institutionId == null ||
        institutionId.isEmpty) {
      return;
    }

    final unlinkedLogs = _callLogsBox.values.where((log) =>
        log.customerId == null &&
        log.institutionId == institutionId &&
        phoneNumbersMatch(log.phoneNumber, customer.phoneNumber));

    for (final log in unlinkedLogs) {
      log.customerId = customer.id;
      log.synced = false;
      await log.save();
    }
  }

  /// Repairs customer ids that older insert logic assigned only in memory.
  ///
  /// The integer Hive box key is the canonical local customer id. This is
  /// idempotent and deliberately leaves already-populated ids unchanged.
  Future<void> backfillCustomerIds() async {
    for (final customer in _customersBox.values) {
      if (customer.id != null) continue;

      final boxKey = customer.key;
      if (boxKey is int) {
        customer.id = boxKey;
        await customer.save();
      }
    }
  }

  /// Idempotent backfill: links all unlinked call logs to their customers.
  /// Safe to call on every app launch - only touches rows where customerId is null.
  Future<void> backfillCallLogCustomerLinks() async {
    for (final log in _callLogsBox.values) {
      if (log.customerId != null) continue;
      final institutionId = log.institutionId;
      if (institutionId == null || institutionId.isEmpty) continue;

      final customer = getCustomerByPhoneForInstitution(
        log.phoneNumber,
        institutionId,
      );
      if (customer != null && customer.id != null) {
        log.customerId = customer.id;
        log.synced = false;
        await log.save();
      }
    }
  }

  /// Repairs service ids that were not persisted by older app versions.
  ///
  /// Safe to run repeatedly: only services with a missing id are updated, and
  /// the Hive box key is the id that [insertService] originally intended to
  /// store on the model.
  Future<void> backfillServiceIds() async {
    for (final service in _servicesBox.values) {
      if (service.id != null) continue;

      final boxKey = service.key;
      if (boxKey is int) {
        service.id = boxKey;
        await service.save();
      }
    }
  }

  // Service operations
  List<Service> getAllServices() =>
      _servicesBox.values.where((s) => s.isActive == true).toList();

  Stream<List<Service>> watchAllServices() async* {
    // Repair historical records before exposing them to route-building UI.
    // This closes the startup race where a list could briefly receive a
    // service whose generated Hive key had not yet been mirrored into `id`.
    await backfillServiceIds();
    yield getAllServices();
    yield* _servicesBox.watch().map((_) => getAllServices());
  }

  Service? getServiceById(int id) {
    try {
      return _servicesBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertService(Service service) async {
    try {
      service.createdAt = DateTime.now();
      service.updatedAt = DateTime.now();
      service.synced = false;
      final key = await _servicesBox.add(service);
      service.id = key;
      await service.save();
      return key;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateService(int id, Service service) async {
    try {
      service.id = id;
      service.updatedAt = DateTime.now();
      service.synced = false;
      await _servicesBox.put(id, service);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteService(int id) async {
    try {
      await _servicesBox.delete(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> softDeleteService(int id) async {
    final service = getServiceById(id);
    if (service != null) {
      service.isActive = false;
      await updateService(id, service);
    }
  }

  // Appointment operations
  List<Appointment> getAllAppointments() => _appointmentsBox.values.toList();

  Stream<List<Appointment>> watchAllAppointments() {
    final controller = StreamController<List<Appointment>>();
    controller.add(getAllAppointments());
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getAllAppointments());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<Appointment> getAppointmentsForCustomer(int customerId) {
    return _appointmentsBox.values
        .where((a) => a.customerId == customerId)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime)); // Most recent first
  }

  List<Appointment> getAppointmentsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _appointmentsBox.values.where((a) {
      return a.startTime.isAfter(startOfDay) && a.startTime.isBefore(endOfDay);
    }).toList();
  }

  List<Appointment> getAppointmentsForDateForInstitution(
    DateTime date,
    String institutionId,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _appointmentsBox.values.where((appointment) {
      return appointment.institutionId == institutionId &&
          !appointment.startTime.isBefore(startOfDay) &&
          appointment.startTime.isBefore(endOfDay);
    }).toList();
  }

  Stream<List<Appointment>> watchAppointmentsForDate(DateTime date) {
    final controller = StreamController<List<Appointment>>();
    controller.add(getAppointmentsForDate(date));
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getAppointmentsForDate(date));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  Stream<List<Appointment>> watchAppointmentsForDateForInstitution(
    DateTime date,
    String institutionId,
  ) {
    final controller = StreamController<List<Appointment>>();
    controller.add(getAppointmentsForDateForInstitution(date, institutionId));
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(
        getAppointmentsForDateForInstitution(date, institutionId),
      );
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<Appointment> getUpcomingAppointments() {
    final now = DateTime.now();
    return _appointmentsBox.values
        .where((a) => a.startTime.isAfter(now) && a.status == 'upcoming')
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<Appointment> getUpcomingAppointmentsForInstitution(
    String institutionId,
  ) {
    final now = DateTime.now();
    return _appointmentsBox.values
        .where(
          (appointment) =>
              appointment.institutionId == institutionId &&
              appointment.startTime.isAfter(now) &&
              appointment.status == 'upcoming',
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  Stream<List<Appointment>> watchUpcomingAppointments() {
    final controller = StreamController<List<Appointment>>();
    controller.add(getUpcomingAppointments());
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getUpcomingAppointments());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  Stream<List<Appointment>> watchUpcomingAppointmentsForInstitution(
    String institutionId,
  ) {
    final controller = StreamController<List<Appointment>>();
    controller.add(getUpcomingAppointmentsForInstitution(institutionId));
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getUpcomingAppointmentsForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  /// Repairs appointment ids that older insert logic assigned only in memory.
  ///
  /// The integer Hive box key is the canonical local appointment id. This is
  /// safe to run repeatedly and leaves already-populated ids unchanged.
  Future<void> backfillAppointmentIds() async {
    for (final appointment in _appointmentsBox.values) {
      if (appointment.id != null) continue;

      final boxKey = appointment.key;
      if (boxKey is int) {
        appointment.id = boxKey;
        await appointment.save();
      }
    }
  }

  Appointment? getAppointmentById(int id) {
    try {
      return _appointmentsBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertAppointment(Appointment appointment) async {
    try {
      appointment.createdAt = DateTime.now();
      appointment.updatedAt = DateTime.now();
      appointment.synced = false;
      final key = await _appointmentsBox.add(appointment);
      appointment.id = key;
      await appointment.save();
      return key;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateAppointment(int id, Appointment appointment) async {
    try {
      appointment.id = id;
      appointment.updatedAt = DateTime.now();
      appointment.synced = false;
      await _appointmentsBox.put(id, appointment);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAppointment(int id) async {
    try {
      await _appointmentsBox.delete(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Call log operations
  List<CallLog> getAllCallLogs() {
    final logs = _callLogsBox.values.toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  Stream<List<CallLog>> watchAllCallLogs() {
    final controller = StreamController<List<CallLog>>();
    controller.add(getAllCallLogs());
    final subscription = _callLogsBox.watch().listen((_) {
      controller.add(getAllCallLogs());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<CallLog> getMissedCalls() {
    final logs =
        _callLogsBox.values.where((c) => c.isMissed && !c.followedUp).toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  List<CallLog> getMissedCallsForInstitution(String institutionId) {
    final logs = _callLogsBox.values
        .where(
          (call) =>
              call.institutionId == institutionId &&
              call.isMissed &&
              !call.followedUp,
        )
        .toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  Stream<List<CallLog>> watchMissedCalls() {
    final controller = StreamController<List<CallLog>>();
    controller.add(getMissedCalls());
    final subscription = _callLogsBox.watch().listen((_) {
      controller.add(getMissedCalls());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  Stream<List<CallLog>> watchMissedCallsForInstitution(
    String institutionId,
  ) {
    final controller = StreamController<List<CallLog>>();
    controller.add(getMissedCallsForInstitution(institutionId));
    final subscription = _callLogsBox.watch().listen((_) {
      controller.add(getMissedCallsForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  CallLog? getCallLogById(int id) {
    try {
      return _callLogsBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertCallLog(CallLog callLog) async {
    try {
      callLog.createdAt = DateTime.now();
      callLog.synced = false;
      // Auto-link to customer if phone number matches
      final institutionId = callLog.institutionId;
      final customer = institutionId == null || institutionId.isEmpty
          ? null
          : getCustomerByPhoneForInstitution(
              callLog.phoneNumber,
              institutionId,
            );
      if (callLog.customerId == null && customer != null) {
        callLog.customerId = customer.id;
      }
      final key = await _callLogsBox.add(callLog);
      callLog.id = key;
      return key;
    } catch (e) {
      return null;
    }
  }

  /// Records an outbound call action initiated from a known Bookly customer.
  ///
  /// The caller must provide tenant and staff attribution. The row is written
  /// before the platform dialer is opened by the application layer.
  Future<int?> insertAppInitiatedCallLog({
    required int customerId,
    required String phoneNumber,
    required String institutionId,
    required String handledByUserId,
    DateTime? timestamp,
  }) async {
    final normalizedPhone = phoneNumber.trim();
    if (normalizedPhone.isEmpty ||
        institutionId.isEmpty ||
        handledByUserId.isEmpty) {
      return null;
    }

    final customer = getCustomerById(customerId);
    if (customer == null || customer.institutionId != institutionId) {
      return null;
    }

    final callLog = CallLog()
      ..phoneNumber = normalizedPhone
      ..timestamp = timestamp ?? DateTime.now()
      ..direction = 'outgoing'
      ..durationSeconds = 0
      ..customerId = customerId
      ..isMissed = false
      ..followedUp = false
      ..institutionId = institutionId
      ..handledByUserId = handledByUserId
      ..origin = CallLog.originAppInitiated;

    return insertCallLog(callLog);
  }

  Future<bool> updateCallLog(int id, CallLog callLog) async {
    try {
      callLog.id = id;
      await _callLogsBox.put(id, callLog);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCallLog(int id) async {
    try {
      await _callLogsBox.delete(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Sync queue operations
  List<SyncQueueItem> getPendingSyncItems() {
    final items = _syncQueueBox.values.toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<int> insertSyncItem(SyncQueueItem item) async {
    final key = await _syncQueueBox.add(item);
    item.id = key;
    return key;
  }

  Future<void> deleteSyncItem(int id) async {
    await _syncQueueBox.delete(id);
  }

  Future<void> clearSyncQueue() async {
    await _syncQueueBox.clear();
  }

  // Service Station operations
  /// Repairs service-station ids omitted by older app versions.
  ///
  /// The canonical integer Hive box key is the id that
  /// [insertServiceStation] intended to persist on the model.
  Future<void> backfillServiceStationIds() async {
    for (final station in _serviceStationsBox.values) {
      if (station.id != null) continue;

      final boxKey = station.key;
      if (boxKey is int) {
        station.id = boxKey;
        await station.save();
      }
    }
  }

  List<ServiceStation> getAllServiceStations() =>
      _serviceStationsBox.values.toList();

  Stream<List<ServiceStation>> watchAllServiceStations() async* {
    // Booking filters out stations without stable ids, so complete the legacy
    // repair before publishing the initial list.
    await backfillServiceStationIds();
    yield getAllServiceStations();
    yield* _serviceStationsBox.watch().map((_) => getAllServiceStations());
  }

  ServiceStation? getServiceStationById(int id) {
    try {
      return _serviceStationsBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertServiceStation(ServiceStation station) async {
    station.createdAt = DateTime.now();
    station.updatedAt = DateTime.now();
    station.synced = false;
    final key = await _serviceStationsBox.add(station);
    station.id = key;
    await station.save();
    return key;
  }

  Future<void> updateServiceStation(int id, ServiceStation station) async {
    station.id = id;
    station.updatedAt = DateTime.now();
    station.synced = false;
    await _serviceStationsBox.put(id, station);
  }

  Future<void> deleteServiceStation(int id) async {
    await _serviceStationsBox.delete(id);
  }

  // AppointmentService (line items) operations
  List<AppointmentService> getAppointmentServicesForAppointment(
      int appointmentId) {
    return _appointmentServicesBox.values
        .where((a) => a.appointmentId == appointmentId)
        .toList();
  }

  Stream<List<AppointmentService>> watchAppointmentServicesForAppointment(
      int appointmentId) {
    final controller = StreamController<List<AppointmentService>>();
    controller.add(getAppointmentServicesForAppointment(appointmentId));
    final subscription = _appointmentServicesBox.watch().listen((_) {
      controller.add(getAppointmentServicesForAppointment(appointmentId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  AppointmentService? getAppointmentServiceById(int id) {
    try {
      return _appointmentServicesBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertAppointmentService(
      AppointmentService appointmentService) async {
    final key = await _appointmentServicesBox.add(appointmentService);
    appointmentService.id = key;
    return key;
  }

  Future<void> updateAppointmentService(
      int id, AppointmentService appointmentService) async {
    appointmentService.id = id;
    await _appointmentServicesBox.put(id, appointmentService);
  }

  Future<void> deleteAppointmentService(int id) async {
    await _appointmentServicesBox.delete(id);
  }

  Future<void> deleteAppointmentServicesForAppointment(
      int appointmentId) async {
    final toDelete = _appointmentServicesBox.values
        .where((a) => a.appointmentId == appointmentId)
        .map((a) => a.id)
        .where((id) => id != null)
        .cast<int>()
        .toList();
    for (final id in toDelete) {
      await _appointmentServicesBox.delete(id);
    }
  }

  // Theme preference operations
  static const String settingsBox = 'settings';
  static const String themeModeKey = 'themeMode';

  Future<void> saveThemeMode(String mode) async {
    final box = await Hive.openBox(settingsBox);
    await box.put(themeModeKey, mode);
  }

  String getThemeMode() {
    try {
      final box = Hive.box(settingsBox);
      return box.get(themeModeKey, defaultValue: 'system') as String;
    } catch (e) {
      return 'system';
    }
  }

  // Institution operations
  List<Institution> getAllInstitutions() => _institutionsBox.values.toList();

  Institution? getInstitutionById(String id) {
    try {
      return _institutionsBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Institution? getInstitutionByOwnerId(String ownerId) {
    try {
      return _institutionsBox.values.firstWhere((i) => i.ownerId == ownerId);
    } catch (e) {
      return null;
    }
  }

  Future<String?> insertInstitution(Institution institution) async {
    institution.createdAt = DateTime.now();
    institution.updatedAt = DateTime.now();
    final key = await _institutionsBox.put(institution.id, institution);
    return key as String?;
  }

  Future<void> updateInstitution(String id, Institution institution) async {
    institution.updatedAt = DateTime.now();
    await _institutionsBox.put(id, institution);
  }

  // User operations
  List<User> getAllUsers() => _usersBox.values.toList();

  List<User> getUsersForInstitution(String institutionId) {
    return _usersBox.values
        .where((u) => u.institutionId == institutionId)
        .toList();
  }

  User? getUserById(String id) {
    try {
      return _usersBox.get(id);
    } catch (e) {
      return null;
    }
  }

  User? getUserByEmail(String email) {
    try {
      return _usersBox.values.firstWhere((u) => u.email == email);
    } catch (e) {
      return null;
    }
  }

  Future<void> insertUser(User user) async {
    user.createdAt = DateTime.now();
    user.updatedAt = DateTime.now();
    await _usersBox.put(user.id, user);
  }

  Future<void> updateUser(String id, User user) async {
    user.updatedAt = DateTime.now();
    await _usersBox.put(id, user);
  }

  Future<void> deleteUser(String id) async {
    await _usersBox.delete(id);
  }

  // Institution-scoped queries (filter by institutionId)
  List<Customer> getCustomersForInstitution(String institutionId) {
    return _customersBox.values
        .where((c) => c.institutionId == institutionId)
        .toList();
  }

  Stream<List<Customer>> watchCustomersForInstitution(String institutionId) {
    final controller = StreamController<List<Customer>>();
    controller.add(getCustomersForInstitution(institutionId));
    final subscription = _customersBox.watch().listen((_) {
      controller.add(getCustomersForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<Service> getServicesForInstitution(String institutionId) {
    return _servicesBox.values
        .where((s) => s.institutionId == institutionId && s.isActive == true)
        .toList();
  }

  Stream<List<Service>> watchServicesForInstitution(String institutionId) {
    final controller = StreamController<List<Service>>();
    controller.add(getServicesForInstitution(institutionId));
    final subscription = _servicesBox.watch().listen((_) {
      controller.add(getServicesForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<Appointment> getAppointmentsForInstitution(String institutionId) {
    return _appointmentsBox.values
        .where((a) => a.institutionId == institutionId)
        .toList();
  }

  Stream<List<Appointment>> watchAppointmentsForInstitution(
      String institutionId) {
    final controller = StreamController<List<Appointment>>();
    controller.add(getAppointmentsForInstitution(institutionId));
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getAppointmentsForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<CallLog> getCallLogsForInstitution(String institutionId) {
    return _callLogsBox.values
        .where((c) => c.institutionId == institutionId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Stream<List<CallLog>> watchCallLogsForInstitution(String institutionId) {
    final controller = StreamController<List<CallLog>>();
    controller.add(getCallLogsForInstitution(institutionId));
    final subscription = _callLogsBox.watch().listen((_) {
      controller.add(getCallLogsForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  List<ServiceStation> getStationsForInstitution(String institutionId) {
    return _serviceStationsBox.values
        .where((s) => s.institutionId == institutionId)
        .toList();
  }

  Stream<List<ServiceStation>> watchStationsForInstitution(
      String institutionId) {
    final controller = StreamController<List<ServiceStation>>();
    controller.add(getStationsForInstitution(institutionId));
    final subscription = _serviceStationsBox.watch().listen((_) {
      controller.add(getStationsForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  // Insights aggregations
  AppointmentInsights getAppointmentInsights(InsightsQuery query) {
    try {
      final current = _appointmentsInRange(query, query.start, query.end);
      final previousStart = query.start.subtract(query.duration);
      final previous = _appointmentsInRange(query, previousStart, query.start);
      return AppointmentInsights(
        booked: _countMetric(current, previous, (_) => true),
        completed: _countMetric(
          current,
          previous,
          (appointment) => appointment.status == Appointment.statusDone,
        ),
        cancelled: _countMetric(
          current,
          previous,
          (appointment) => appointment.status == Appointment.statusCancelled,
        ),
        noShow: _countMetric(
          current,
          previous,
          (appointment) => appointment.status == Appointment.statusNoShow,
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to aggregate appointment insights',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<AppointmentInsights> watchAppointmentInsights(InsightsQuery query) =>
      _watchAggregation(
        () => getAppointmentInsights(query),
        [_appointmentsBox.watch()],
      );

  CustomerInsights getCustomerInsights(InsightsQuery query) {
    try {
      CustomerInsights calculate(DateTime start, DateTime end) {
        final customers = _customersBox.values
            .where((customer) => customer.institutionId == query.institutionId)
            .toList();
        final appointments = _appointmentsBox.values
            .where((appointment) =>
                appointment.institutionId == query.institutionId)
            .toList();
        final activeCustomerIds = appointments
            .where((appointment) =>
                _isWithin(appointment.startTime, start, end) &&
                appointment.customerId != null)
            .map((appointment) => appointment.customerId!)
            .toSet();
        final newCount = customers.where((customer) {
          final createdAt = customer.createdAt;
          return createdAt != null && _isWithin(createdAt, start, end);
        }).length;
        final returningCount = activeCustomerIds.where((customerId) {
          return appointments.any((appointment) =>
              appointment.customerId == customerId &&
              appointment.startTime.isBefore(start));
        }).length;
        return CustomerInsights(
          newCustomers: InsightMetric(value: newCount, previousValue: 0),
          returningCustomers:
              InsightMetric(value: returningCount, previousValue: 0),
        );
      }

      final current = calculate(query.start, query.end);
      final previous =
          calculate(query.start.subtract(query.duration), query.start);
      return CustomerInsights(
        newCustomers: InsightMetric(
          value: current.newCustomers.value,
          previousValue: previous.newCustomers.value,
        ),
        returningCustomers: InsightMetric(
          value: current.returningCustomers.value,
          previousValue: previous.returningCustomers.value,
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to aggregate customer insights',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<CustomerInsights> watchCustomerInsights(InsightsQuery query) =>
      _watchAggregation(
        () => getCustomerInsights(query),
        [_customersBox.watch(), _appointmentsBox.watch()],
      );

  List<RankedInsight> getHotServiceInsights(InsightsQuery query) {
    try {
      final appointments = _appointmentsInRange(query, query.start, query.end);
      final counts = <int, int>{};
      for (final appointment in appointments) {
        final appointmentId = appointment.id;
        final lineItems = appointmentId == null
            ? const <AppointmentService>[]
            : _appointmentServicesBox.values
                .where((item) =>
                    item.institutionId == query.institutionId &&
                    item.appointmentId == appointmentId)
                .toList();
        if (lineItems.isNotEmpty) {
          for (final item in lineItems) {
            final serviceId = item.serviceId;
            if (serviceId != null) {
              counts.update(serviceId, (count) => count + 1, ifAbsent: () => 1);
            }
          }
        } else if (appointment.serviceId != null) {
          counts.update(appointment.serviceId!, (count) => count + 1,
              ifAbsent: () => 1);
        }
      }
      final ranked = counts.entries.map((entry) {
        final service = _servicesBox.get(entry.key);
        return RankedInsight(
          id: entry.key.toString(),
          label: service?.institutionId == query.institutionId
              ? service!.title
              : 'Unavailable service',
          value: entry.value,
        );
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return ranked.take(5).toList(growable: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to aggregate hot service insights',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<List<RankedInsight>> watchHotServiceInsights(InsightsQuery query) =>
      _watchAggregation(
        () => getHotServiceInsights(query),
        [
          _appointmentsBox.watch(),
          _appointmentServicesBox.watch(),
          _servicesBox.watch(),
        ],
      );

  CallInsights getCallInsights(InsightsQuery query) {
    try {
      CallInsights calculate(DateTime start, DateTime end) {
        final calls = _callLogsBox.values
            .where((call) =>
                call.institutionId == query.institutionId &&
                _isWithin(call.timestamp, start, end))
            .toList();
        final answered = calls.where((call) => !call.isMissed).toList();
        final missed = calls.where((call) => call.isMissed).length;
        final averageDuration = answered.isEmpty
            ? 0.0
            : answered.fold<int>(0, (sum, call) => sum + call.durationSeconds) /
                answered.length;
        final converted =
            calls.where((call) => call.linkedAppointmentId != null).length;
        return CallInsights(
          total: InsightMetric(value: calls.length, previousValue: 0),
          answered: InsightMetric(value: answered.length, previousValue: 0),
          missed: InsightMetric(value: missed, previousValue: 0),
          averageDurationSeconds:
              InsightMetric(value: averageDuration, previousValue: 0),
          converted: InsightMetric(value: converted, previousValue: 0),
        );
      }

      final current = calculate(query.start, query.end);
      final previous =
          calculate(query.start.subtract(query.duration), query.start);
      return CallInsights(
        total: _withPrevious(current.total, previous.total),
        answered: _withPrevious(current.answered, previous.answered),
        missed: _withPrevious(current.missed, previous.missed),
        averageDurationSeconds: _withPrevious(
          current.averageDurationSeconds,
          previous.averageDurationSeconds,
        ),
        converted: _withPrevious(current.converted, previous.converted),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to aggregate call insights',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<CallInsights> watchCallInsights(InsightsQuery query) =>
      _watchAggregation(
        () => getCallInsights(query),
        [_callLogsBox.watch()],
      );

  BookedValueInsights getBookedValueInsights(InsightsQuery query) {
    try {
      ({double total, int appointments, Map<int, double> byService}) calculate(
        DateTime start,
        DateTime end,
      ) {
        final appointments = _appointmentsInRange(query, start, end)
            .where((appointment) =>
                appointment.status != Appointment.statusCancelled &&
                appointment.status != Appointment.statusNoShow)
            .toList();
        final byService = <int, double>{};
        var total = 0.0;
        for (final appointment in appointments) {
          final appointmentId = appointment.id;
          final items = appointmentId == null
              ? const <AppointmentService>[]
              : _appointmentServicesBox.values
                  .where((item) =>
                      item.institutionId == query.institutionId &&
                      item.appointmentId == appointmentId)
                  .toList();
          if (items.isNotEmpty) {
            for (final item in items) {
              final serviceId = item.serviceId;
              if (serviceId == null) continue;
              final service = _servicesBox.get(serviceId);
              if (service?.institutionId != query.institutionId) continue;
              final value = item.priceOverride ?? service!.cost;
              total += value;
              byService.update(serviceId, (sum) => sum + value,
                  ifAbsent: () => value);
            }
          } else {
            final serviceId = appointment.serviceId;
            if (serviceId == null) continue;
            final service = _servicesBox.get(serviceId);
            if (service?.institutionId != query.institutionId) continue;
            total += service!.cost;
            byService.update(serviceId, (sum) => sum + service.cost,
                ifAbsent: () => service.cost);
          }
        }
        return (
          total: total,
          appointments: appointments.length,
          byService: byService,
        );
      }

      final current = calculate(query.start, query.end);
      final previous =
          calculate(query.start.subtract(query.duration), query.start);
      final ranked = current.byService.entries.map((entry) {
        final service = _servicesBox.get(entry.key);
        return RankedInsight(
          id: entry.key.toString(),
          label: service?.title ?? 'Unavailable service',
          value: entry.value,
        );
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return BookedValueInsights(
        total: InsightMetric(
          value: current.total,
          previousValue: previous.total,
        ),
        averagePerAppointment: InsightMetric(
          value: current.appointments == 0
              ? 0
              : current.total / current.appointments,
          previousValue: previous.appointments == 0
              ? 0
              : previous.total / previous.appointments,
        ),
        byService: ranked,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to aggregate booked value insights',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<BookedValueInsights> watchBookedValueInsights(InsightsQuery query) =>
      _watchAggregation(
        () => getBookedValueInsights(query),
        [
          _appointmentsBox.watch(),
          _appointmentServicesBox.watch(),
          _servicesBox.watch(),
        ],
      );

  StaffInsights getStaffInsights(InsightsQuery query) {
    try {
      final appointments = _appointmentsInRange(query, query.start, query.end);
      final calls = _callLogsBox.values
          .where((call) =>
              call.institutionId == query.institutionId &&
              _isWithin(call.timestamp, query.start, query.end))
          .toList();
      final people = getUsersForInstitution(query.institutionId).map((user) {
        final handledAppointments = appointments
            .where((appointment) => appointment.handledByUserId == user.id)
            .length;
        final handledCalls =
            calls.where((call) => call.handledByUserId == user.id).toList();
        final averageSeconds = handledCalls.isEmpty
            ? 0
            : handledCalls.fold<int>(
                    0, (sum, call) => sum + call.durationSeconds) /
                handledCalls.length;
        final conversions = handledCalls
            .where((call) => call.linkedAppointmentId != null)
            .length;
        final conversionRate = handledCalls.isEmpty
            ? 0.0
            : conversions / handledCalls.length * 100;
        return RankedInsight(
          id: user.id,
          label: user.name,
          value: handledAppointments,
          secondaryValue:
              '${averageSeconds.round()}s avg call • ${conversionRate.toStringAsFixed(0)}% conversion',
        );
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return StaffInsights(people: people);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to aggregate staff insights',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<StaffInsights> watchStaffInsights(InsightsQuery query) =>
      _watchAggregation(
        () => getStaffInsights(query),
        [_appointmentsBox.watch(), _callLogsBox.watch(), _usersBox.watch()],
      );

  LegacyExclusionInsights getLegacyExclusionInsights() {
    try {
      final count = _customersBox.values
              .where((record) => record.institutionId == null)
              .length +
          _servicesBox.values
              .where((record) => record.institutionId == null)
              .length +
          _appointmentsBox.values
              .where((record) => record.institutionId == null)
              .length +
          _callLogsBox.values
              .where((record) => record.institutionId == null)
              .length +
          _serviceStationsBox.values
              .where((record) => record.institutionId == null)
              .length +
          _appointmentServicesBox.values
              .where((record) => record.institutionId == null)
              .length;
      return LegacyExclusionInsights(recordCount: count);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to count excluded legacy records',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Stream<LegacyExclusionInsights> watchLegacyExclusionInsights() =>
      _watchAggregation(
        getLegacyExclusionInsights,
        [
          _customersBox.watch(),
          _servicesBox.watch(),
          _appointmentsBox.watch(),
          _callLogsBox.watch(),
          _serviceStationsBox.watch(),
          _appointmentServicesBox.watch(),
        ],
      );

  List<Appointment> _appointmentsInRange(
    InsightsQuery query,
    DateTime start,
    DateTime end,
  ) {
    return _appointmentsBox.values
        .where((appointment) =>
            appointment.institutionId == query.institutionId &&
            _isWithin(appointment.startTime, start, end))
        .toList();
  }

  InsightMetric _countMetric(
    List<Appointment> current,
    List<Appointment> previous,
    bool Function(Appointment appointment) predicate,
  ) {
    return InsightMetric(
      value: current.where(predicate).length,
      previousValue: previous.where(predicate).length,
    );
  }

  InsightMetric _withPrevious(InsightMetric current, InsightMetric previous) {
    return InsightMetric(
      value: current.value,
      previousValue: previous.value,
    );
  }

  bool _isWithin(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && value.isBefore(end);

  Stream<T> _watchAggregation<T>(
    T Function() compute,
    List<Stream<BoxEvent>> sources,
  ) {
    late StreamController<T> controller;
    final subscriptions = <StreamSubscription<BoxEvent>>[];

    void emit() {
      try {
        controller.add(compute());
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        emit();
        for (final source in sources) {
          subscriptions.add(source.listen((_) => emit()));
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  // Leave Request operations
  List<LeaveRequest> getLeaveRequestsForInstitution(String institutionId) {
    return _leaveRequestsBox.values
        .where((r) => r.institutionId == institutionId)
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  List<LeaveRequest> getPendingLeaveRequests(String institutionId) {
    return _leaveRequestsBox.values
        .where((r) => r.institutionId == institutionId && r.status == 'pending')
        .toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Stream<List<LeaveRequest>> watchLeaveRequestsForInstitution(
      String institutionId) {
    final controller = StreamController<List<LeaveRequest>>();
    controller.add(getLeaveRequestsForInstitution(institutionId));
    final subscription = _leaveRequestsBox.watch().listen((_) {
      controller.add(getLeaveRequestsForInstitution(institutionId));
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
  }

  LeaveRequest? getLeaveRequestById(String id) {
    try {
      return _leaveRequestsBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertLeaveRequest(LeaveRequest request) async {
    request.requestedAt = DateTime.now();
    final key = await _leaveRequestsBox.add(request);
    request.id = key.toString();
    return key;
  }

  Future<void> updateLeaveRequest(String id, LeaveRequest request) async {
    request.id = id;
    if (request.status != 'pending') {
      request.processedAt = DateTime.now();
    }
    await _leaveRequestsBox.put(id, request);
  }

  Future<void> deleteLeaveRequest(String id) async {
    await _leaveRequestsBox.delete(id);
  }

  int getPendingLeaveRequestCount(String institutionId) {
    return _leaveRequestsBox.values
        .where((r) => r.institutionId == institutionId && r.status == 'pending')
        .length;
  }
}
