import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'collections/collections.dart';
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
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(ServiceAdapter());
    Hive.registerAdapter(AppointmentAdapter());
    Hive.registerAdapter(CallLogAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());
    Hive.registerAdapter(ServiceStationAdapter());
    Hive.registerAdapter(AppointmentServiceAdapter());
    Hive.registerAdapter(InstitutionAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(LeaveRequestAdapter());
    Hive.registerAdapter(CallLogEntryAdapter());

    // Open boxes
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

    // Open CallLogEntry box for new call log feature
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

  Future<int?> insertCustomer(Customer customer) async {
    try {
      customer.createdAt = DateTime.now();
      customer.updatedAt = DateTime.now();
      customer.synced = false;
      final key = await _customersBox.add(customer);
      customer.id = key;
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
    if (customer.id == null || customer.phoneNumber.isEmpty) return;

    final unlinkedLogs = _callLogsBox.values.where((log) =>
        log.customerId == null &&
        phoneNumbersMatch(log.phoneNumber, customer.phoneNumber));

    for (final log in unlinkedLogs) {
      log.customerId = customer.id;
      log.synced = false;
      await log.save();
    }
  }

  /// Idempotent backfill: links all unlinked call logs to their customers.
  /// Safe to call on every app launch - only touches rows where customerId is null.
  Future<void> backfillCallLogCustomerLinks() async {
    for (final log in _callLogsBox.values) {
      if (log.customerId != null) continue;

      final customer = getCustomerByPhone(log.phoneNumber);
      if (customer != null && customer.id != null) {
        log.customerId = customer.id;
        log.synced = false;
        await log.save();
      }
    }
  }

  // Service operations
  List<Service> getAllServices() =>
      _servicesBox.values.where((s) => s.isActive == true).toList();

  Stream<List<Service>> watchAllServices() {
    final controller = StreamController<List<Service>>();
    // Emit current value first (only active services)
    controller.add(getAllServices());
    // Then listen to changes
    final subscription = _servicesBox.watch().listen((_) {
      controller.add(getAllServices());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
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

  Stream<List<Appointment>> watchAppointmentsForDate(DateTime date) {
    final controller = StreamController<List<Appointment>>();
    controller.add(getAppointmentsForDate(date));
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getAppointmentsForDate(date));
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

  Stream<List<Appointment>> watchUpcomingAppointments() {
    final controller = StreamController<List<Appointment>>();
    controller.add(getUpcomingAppointments());
    final subscription = _appointmentsBox.watch().listen((_) {
      controller.add(getUpcomingAppointments());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
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

  Stream<List<CallLog>> watchMissedCalls() {
    final controller = StreamController<List<CallLog>>();
    controller.add(getMissedCalls());
    final subscription = _callLogsBox.watch().listen((_) {
      controller.add(getMissedCalls());
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
      final customer = getCustomerByPhone(callLog.phoneNumber);
      if (customer != null) {
        callLog.customerId = customer.id;
      }
      final key = await _callLogsBox.add(callLog);
      callLog.id = key;
      return key;
    } catch (e) {
      return null;
    }
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
  List<ServiceStation> getAllServiceStations() =>
      _serviceStationsBox.values.toList();

  Stream<List<ServiceStation>> watchAllServiceStations() {
    final controller = StreamController<List<ServiceStation>>();
    controller.add(getAllServiceStations());
    final subscription = _serviceStationsBox.watch().listen((_) {
      controller.add(getAllServiceStations());
    });
    controller.onCancel = () => subscription.cancel();
    return controller.stream;
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
