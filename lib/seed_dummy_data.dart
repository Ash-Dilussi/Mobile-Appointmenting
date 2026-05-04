import 'core/database/hive_service.dart';
import 'core/database/collections/collections.dart';

/// Seeds the Hive database with dummy data for testing the dashboard.
/// Run this function after HiveService.init() to populate sample data.
Future<void> seedDummyData(HiveService hive, {bool force = false}) async {
  // Check if already seeded (skip if force is true)
  if (!force) {
    final existingCustomers = hive.getAllCustomers();
    if (existingCustomers.isNotEmpty) {
      return; // Already seeded
    }
  }

  // Clear all data before seeding fresh
  await hive.clearAllData();

  // Seed Customers - track returned IDs
  final customerIds = <int>[];
  final customers = [
    Customer()
      ..name = 'Alice Johnson'
      ..phoneNumber = '+1-555-0101'
      ..email = 'alice@example.com'
      ..notes = 'Regular client, prefers morning appointments',
    Customer()
      ..name = 'Bob Smith'
      ..phoneNumber = '+1-555-0102'
      ..email = 'bob@example.com'
      ..notes = 'Prefers text message reminders',
    Customer()
      ..name = 'Carol White'
      ..phoneNumber = '+1-555-0103'
      ..email = 'carol@example.com'
      ..notes = 'VIP client',
    Customer()
      ..name = 'David Brown'
      ..phoneNumber = '+1-555-0104'
      ..email = 'david@example.com',
    Customer()
      ..name = 'Emma Davis'
      ..phoneNumber = '+1-555-0105'
      ..email = 'emma@example.com'
      ..notes = 'Allergic to certain products',
    Customer()
      ..name = 'Frank Miller'
      ..phoneNumber = '+1-555-0106'
      ..email = 'frank@example.com',
    Customer()
      ..name = 'Grace Wilson'
      ..phoneNumber = '+1-555-0107'
      ..email = 'grace@example.com'
      ..notes = 'Prefers afternoon appointments',
    Customer()
      ..name = 'Henry Taylor'
      ..phoneNumber = '+1-555-0108'
      ..email = 'henry@example.com',
  ];

  for (final customer in customers) {
    final id = await hive.insertCustomer(customer);
    customerIds.add(id!);
  }

  // Seed Services - track returned IDs
  final serviceIds = <int>[];
  final services = [
    Service()
      ..title = 'Haircut'
      ..defaultDurationMinutes = 30
      ..cost = 45.00
      ..description = 'Standard haircut and style',
    Service()
      ..title = 'Massage'
      ..defaultDurationMinutes = 60
      ..cost = 80.00
      ..description = 'Full body relaxation massage',
    Service()
      ..title = 'Manicure'
      ..defaultDurationMinutes = 45
      ..cost = 35.00
      ..description = 'Nail care and polish',
    Service()
      ..title = 'Consultation'
      ..defaultDurationMinutes = 20
      ..cost = 0.00
      ..description = 'Free initial consultation',
    Service()
      ..title = 'Facial'
      ..defaultDurationMinutes = 60
      ..cost = 95.00
      ..description = 'Deep cleansing facial treatment',
    Service()
      ..title = 'Teeth Whitening'
      ..defaultDurationMinutes = 45
      ..cost = 150.00
      ..description = 'Professional teeth whitening',
  ];

  for (final service in services) {
    final id = await hive.insertService(service);
    serviceIds.add(id!);
  }

  // Seed Appointments (today and upcoming)
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final appointments = [
    // Today's appointments - use tracked IDs
    Appointment()
      ..customerId = customerIds[0] // Alice
      ..serviceId = serviceIds[0] // Haircut
      ..startTime = today.add(const Duration(hours: 9))
      ..endTime = today.add(const Duration(hours: 9, minutes: 30))
      ..status = 'confirmed'
      ..staffId = 1
      ..notes = 'Prefers short hair',
    Appointment()
      ..customerId = customerIds[1] // Bob
      ..serviceId = serviceIds[1] // Massage
      ..startTime = today.add(const Duration(hours: 10))
      ..endTime = today.add(const Duration(hours: 11))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[2] // Carol
      ..serviceId = serviceIds[4] // Facial
      ..startTime = today.add(const Duration(hours: 14))
      ..endTime = today.add(const Duration(hours: 15))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[4] // Emma
      ..serviceId = serviceIds[2] // Manicure
      ..startTime = today.add(const Duration(hours: 15, minutes: 30))
      ..endTime = today.add(const Duration(hours: 16, minutes: 15))
      ..status = 'upcoming'
      ..staffId = 1,
    // Upcoming appointments (next few days)
    Appointment()
      ..customerId = customerIds[3] // David
      ..serviceId = serviceIds[0] // Haircut
      ..startTime = today.add(const Duration(days: 1, hours: 10))
      ..endTime = today.add(const Duration(days: 1, hours: 10, minutes: 30))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[5] // Frank
      ..serviceId = serviceIds[5] // Teeth Whitening
      ..startTime = today.add(const Duration(days: 2, hours: 11))
      ..endTime = today.add(const Duration(days: 2, hours: 11, minutes: 45))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[6] // Grace
      ..serviceId = serviceIds[1] // Massage
      ..startTime = today.add(const Duration(days: 3, hours: 14))
      ..endTime = today.add(const Duration(days: 3, hours: 15))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[7] // Henry
      ..serviceId = serviceIds[3] // Consultation
      ..startTime = today.add(const Duration(days: 4, hours: 9))
      ..endTime = today.add(const Duration(days: 4, hours: 9, minutes: 20))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[0] // Alice
      ..serviceId = serviceIds[4] // Facial
      ..startTime = today.add(const Duration(days: 5, hours: 10))
      ..endTime = today.add(const Duration(days: 5, hours: 11))
      ..status = 'upcoming'
      ..staffId = 1,
    // Past appointments (done)
    Appointment()
      ..customerId = customerIds[1] // Bob
      ..serviceId = serviceIds[2] // Manicure
      ..startTime = today.subtract(const Duration(days: 2, hours: 11))
      ..endTime = today.subtract(const Duration(days: 2, hours: 11, minutes: 45))
      ..status = 'done'
      ..staffId = 1,
    Appointment()
      ..customerId = customerIds[2] // Carol
      ..serviceId = serviceIds[0] // Haircut
      ..startTime = today.subtract(const Duration(days: 5, hours: 10))
      ..endTime = today.subtract(const Duration(days: 5, hours: 10, minutes: 30))
      ..status = 'done'
      ..staffId = 1,
  ];

  // Track appointment IDs for linking call logs
  final appointmentIds = <int>[];
  for (final appointment in appointments) {
    final id = await hive.insertAppointment(appointment);
    appointmentIds.add(id!);
  }

  // Seed Call Logs
  final callLogs = [
    CallLog()
      ..phoneNumber = '+1-555-0101'
      ..timestamp = now.subtract(const Duration(hours: 1))
      ..direction = 'incoming'
      ..durationSeconds = 120
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId = appointmentIds.isNotEmpty ? appointmentIds[0] : null,
    CallLog()
      ..phoneNumber = '+1-555-0109'
      ..timestamp = now.subtract(const Duration(hours: 2))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..phoneNumber = '+1-555-0102'
      ..timestamp = now.subtract(const Duration(hours: 3))
      ..direction = 'outgoing'
      ..durationSeconds = 60
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId = appointmentIds.length > 1 ? appointmentIds[1] : null,
    CallLog()
      ..phoneNumber = '+1-555-0110'
      ..timestamp = now.subtract(const Duration(hours: 5))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..phoneNumber = '+1-555-0103'
      ..timestamp = now.subtract(const Duration(hours: 8))
      ..direction = 'incoming'
      ..durationSeconds = 180
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId = appointmentIds.length > 2 ? appointmentIds[2] : null,
    CallLog()
      ..phoneNumber = '+1-555-0111'
      ..timestamp = now.subtract(const Duration(days: 1))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..phoneNumber = '+1-555-0104'
      ..timestamp = now.subtract(const Duration(days: 1, hours: 2))
      ..direction = 'outgoing'
      ..durationSeconds = 45
      ..isMissed = false
      ..followedUp = true,
    CallLog()
      ..phoneNumber = '+1-555-0112'
      ..timestamp = now.subtract(const Duration(days: 2))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = true,
  ];

  // Track call log IDs (for potential future linking)
  final callLogIds = <int>[];
  for (final callLog in callLogs) {
    final id = await hive.insertCallLog(callLog);
    callLogIds.add(id!);
  }
}