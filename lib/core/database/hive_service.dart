import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import '../logging/logger_service.dart';
import 'collections/collections.dart';

class HiveService {
  static const String customersBox = 'customers';
  static const String servicesBox = 'services';
  static const String appointmentsBox = 'appointments';
  static const String callLogsBox = 'callLogs';
  static const String syncQueueBox = 'syncQueue';
  static const String serviceStationsBox = 'serviceStations';
  static const String appointmentServicesBox = 'appointmentServices';

  late Box<Customer> _customersBox;
  late Box<Service> _servicesBox;
  late Box<Appointment> _appointmentsBox;
  late Box<CallLog> _callLogsBox;
  late Box<SyncQueueItem> _syncQueueBox;
  late Box<ServiceStation> _serviceStationsBox;
  late Box<AppointmentService> _appointmentServicesBox;

  Future<void> init() async {
    logger.info('HiveService', 'Initializing Hive database...');

    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(ServiceAdapter());
    Hive.registerAdapter(AppointmentAdapter());
    Hive.registerAdapter(CallLogAdapter());
    Hive.registerAdapter(SyncQueueItemAdapter());
    Hive.registerAdapter(ServiceStationAdapter());
    Hive.registerAdapter(AppointmentServiceAdapter());

    // Open boxes
    _customersBox = await Hive.openBox<Customer>(customersBox);
    _servicesBox = await Hive.openBox<Service>(servicesBox);
    _appointmentsBox = await Hive.openBox<Appointment>(appointmentsBox);
    _callLogsBox = await Hive.openBox<CallLog>(callLogsBox);
    _syncQueueBox = await Hive.openBox<SyncQueueItem>(syncQueueBox);
    _serviceStationsBox = await Hive.openBox<ServiceStation>(serviceStationsBox);
    _appointmentServicesBox = await Hive.openBox<AppointmentService>(appointmentServicesBox);

    logger.info('HiveService', 'Hive database initialized successfully');
  }

  Future<void> clearAllData() async {
    await _customersBox.clear();
    await _servicesBox.clear();
    await _appointmentsBox.clear();
    await _callLogsBox.clear();
    await _syncQueueBox.clear();
    await _serviceStationsBox.clear();
    await _appointmentServicesBox.clear();
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
        (c) => c.phoneNumber == phone,
      );
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertCustomer(Customer customer) async {
    customer.createdAt = DateTime.now();
    customer.updatedAt = DateTime.now();
    customer.synced = false;
    final key = await _customersBox.add(customer);
    customer.id = key;
    return key;
  }

  Future<void> updateCustomer(int id, Customer customer) async {
    customer.id = id;
    customer.updatedAt = DateTime.now();
    customer.synced = false;
    await _customersBox.put(id, customer);
  }

  Future<void> deleteCustomer(int id) async {
    await _customersBox.delete(id);
  }

  // Service operations
  List<Service> getAllServices() => _servicesBox.values.where((s) => s.isActive).toList();

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
    service.createdAt = DateTime.now();
    service.updatedAt = DateTime.now();
    service.synced = false;
    final key = await _servicesBox.add(service);
    service.id = key; // Hive uses key as id
    return key;
  }

  Future<void> updateService(int id, Service service) async {
    service.id = id; // Ensure id is set
    service.updatedAt = DateTime.now();
    service.synced = false;
    await _servicesBox.put(id, service);
  }

  Future<void> deleteService(int id) async {
    await _servicesBox.delete(id);
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
    appointment.createdAt = DateTime.now();
    appointment.updatedAt = DateTime.now();
    appointment.synced = false;
    final key = await _appointmentsBox.add(appointment);
    appointment.id = key;
    return key;
  }

  Future<void> updateAppointment(int id, Appointment appointment) async {
    appointment.id = id;
    appointment.updatedAt = DateTime.now();
    appointment.synced = false;
    await _appointmentsBox.put(id, appointment);
  }

  Future<void> deleteAppointment(int id) async {
    await _appointmentsBox.delete(id);
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
    final logs = _callLogsBox.values
        .where((c) => c.isMissed && !c.followedUp)
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

  CallLog? getCallLogById(int id) {
    try {
      return _callLogsBox.get(id);
    } catch (e) {
      return null;
    }
  }

  Future<int?> insertCallLog(CallLog callLog) async {
    callLog.createdAt = DateTime.now();
    callLog.synced = false;
    final key = await _callLogsBox.add(callLog);
    callLog.id = key;
    return key;
  }

  Future<void> updateCallLog(int id, CallLog callLog) async {
    callLog.id = id;
    await _callLogsBox.put(id, callLog);
  }

  Future<void> deleteCallLog(int id) async {
    await _callLogsBox.delete(id);
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
  List<ServiceStation> getAllServiceStations() => _serviceStationsBox.values.toList();

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
  List<AppointmentService> getAppointmentServicesForAppointment(int appointmentId) {
    return _appointmentServicesBox.values
        .where((a) => a.appointmentId == appointmentId)
        .toList();
  }

  Stream<List<AppointmentService>> watchAppointmentServicesForAppointment(int appointmentId) {
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

  Future<int?> insertAppointmentService(AppointmentService appointmentService) async {
    final key = await _appointmentServicesBox.add(appointmentService);
    appointmentService.id = key;
    return key;
  }

  Future<void> updateAppointmentService(int id, AppointmentService appointmentService) async {
    appointmentService.id = id;
    await _appointmentServicesBox.put(id, appointmentService);
  }

  Future<void> deleteAppointmentService(int id) async {
    await _appointmentServicesBox.delete(id);
  }

  Future<void> deleteAppointmentServicesForAppointment(int appointmentId) async {
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
}
