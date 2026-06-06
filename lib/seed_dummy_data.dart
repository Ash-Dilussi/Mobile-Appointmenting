import 'core/database/hive_service.dart';
import 'core/database/collections/collections.dart';
import 'core/theme/style_preset.dart';

/// Seeds the Hive database with dummy data for testing the dashboard.
/// Run this function after HiveService.init() to populate sample data.
Future<void> seedDummyData(HiveService hive, {bool force = false, String? institutionId}) async {
  // Check if already seeded (skip if force is true)
  if (!force) {
    final existingCustomers = hive.getAllCustomers();
    if (existingCustomers.isNotEmpty) {
      return; // Already seeded
    }
  }

  // Clear all data before seeding fresh
  await hive.clearAllData();

  // Create institution for this seed data
  final instId = institutionId ?? 'demo_institution_${DateTime.now().millisecondsSinceEpoch}';

  // Create owner user
  final ownerUserId = 'owner_${DateTime.now().millisecondsSinceEpoch}';
  final owner = User()
    ..id = ownerUserId
    ..institutionId = instId
    ..email = 'owner@demo.com'
    ..name = 'Demo Owner'
    ..role = 'owner';
  await hive.insertUser(owner);

  // Create institution
  final institution = Institution()
    ..id = instId
    ..name = 'Demo Salon & Spa'
    ..themePreset = StylePreset.solarOrange.name
    ..ownerId = ownerUserId;
  await hive.insertInstitution(institution);

  // Seed Customers - track returned IDs
  final customerIds = <int>[];
  final customers = [
    Customer()
      ..institutionId = instId
      ..name = 'Alice Johnson'
      ..phoneNumber = '+1-555-0101'
      ..email = 'alice@example.com'
      ..notes = 'Regular client, prefers morning appointments',
    Customer()
      ..institutionId = instId
      ..name = 'Bob Smith'
      ..phoneNumber = '+1-555-0102'
      ..email = 'bob@example.com'
      ..notes = 'Prefers text message reminders',
    Customer()
      ..institutionId = instId
      ..name = 'Carol White'
      ..phoneNumber = '+1-555-0103'
      ..email = 'carol@example.com'
      ..notes = 'VIP client',
    Customer()
      ..institutionId = instId
      ..name = 'David Brown'
      ..phoneNumber = '+1-555-0104'
      ..email = 'david@example.com',
    Customer()
      ..institutionId = instId
      ..name = 'Emma Davis'
      ..phoneNumber = '+1-555-0105'
      ..email = 'emma@example.com'
      ..notes = 'Allergic to certain products',
    Customer()
      ..institutionId = instId
      ..name = 'Frank Miller'
      ..phoneNumber = '+1-555-0106'
      ..email = 'frank@example.com',
    Customer()
      ..institutionId = instId
      ..name = 'Grace Wilson'
      ..phoneNumber = '+1-555-0107'
      ..email = 'grace@example.com'
      ..notes = 'Prefers afternoon appointments',
    Customer()
      ..institutionId = instId
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
      ..institutionId = instId
      ..title = 'Haircut'
      ..defaultDurationMinutes = 30
      ..cost = 45.00
      ..description = 'Standard haircut and style',
    Service()
      ..institutionId = instId
      ..title = 'Massage'
      ..defaultDurationMinutes = 60
      ..cost = 80.00
      ..description = 'Full body relaxation massage',
    Service()
      ..institutionId = instId
      ..title = 'Manicure'
      ..defaultDurationMinutes = 45
      ..cost = 35.00
      ..description = 'Nail care and polish',
    Service()
      ..institutionId = instId
      ..title = 'Consultation'
      ..defaultDurationMinutes = 20
      ..cost = 0.00
      ..description = 'Free initial consultation',
    Service()
      ..institutionId = instId
      ..title = 'Facial'
      ..defaultDurationMinutes = 60
      ..cost = 95.00
      ..description = 'Deep cleansing facial treatment',
    Service()
      ..institutionId = instId
      ..title = 'Teeth Whitening'
      ..defaultDurationMinutes = 45
      ..cost = 150.00
      ..description = 'Professional teeth whitening',
  ];

  for (final service in services) {
    final id = await hive.insertService(service);
    serviceIds.add(id!);
  }

  // Seed Service Stations - two locations
  final stationIds = <int>[];
  final stations = [
    ServiceStation()
      ..institutionId = instId
      ..name = 'Downtown Location'
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false,
    ServiceStation()
      ..institutionId = instId
      ..name = 'Mall Branch'
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false,
  ];

  for (final station in stations) {
    final id = await hive.insertServiceStation(station);
    stationIds.add(id!);
  }

  // Seed Appointments (today and upcoming)
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final appointments = [
    // Today's appointments - use tracked IDs
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[0] // Alice
      ..serviceId = serviceIds[0] // Haircut
      ..startTime = today.add(const Duration(hours: 9))
      ..endTime = today.add(const Duration(hours: 9, minutes: 30))
      ..status = 'confirmed'
      ..staffId = 1
      ..stationId = stationIds[0] // Downtown
      ..notes = 'Prefers short hair',
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[1] // Bob
      ..serviceId = serviceIds[1] // Massage
      ..startTime = today.add(const Duration(hours: 10))
      ..endTime = today.add(const Duration(hours: 11))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[2] // Carol
      ..serviceId = serviceIds[4] // Facial
      ..startTime = today.add(const Duration(hours: 14))
      ..endTime = today.add(const Duration(hours: 15))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[4] // Emma
      ..serviceId = serviceIds[2] // Manicure
      ..startTime = today.add(const Duration(hours: 15, minutes: 30))
      ..endTime = today.add(const Duration(hours: 16, minutes: 15))
      ..status = 'upcoming'
      ..staffId = 1
      ..stationId = stationIds[1], // Mall Branch
    // Upcoming appointments (next few days)
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[3] // David
      ..serviceId = serviceIds[0] // Haircut
      ..startTime = today.add(const Duration(days: 1, hours: 10))
      ..endTime = today.add(const Duration(days: 1, hours: 10, minutes: 30))
      ..status = 'upcoming'
      ..staffId = 1
      ..stationId = stationIds[0], // Downtown
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[5] // Frank
      ..serviceId = serviceIds[5] // Teeth Whitening
      ..startTime = today.add(const Duration(days: 2, hours: 11))
      ..endTime = today.add(const Duration(days: 2, hours: 11, minutes: 45))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[6] // Grace
      ..serviceId = serviceIds[1] // Massage
      ..startTime = today.add(const Duration(days: 3, hours: 14))
      ..endTime = today.add(const Duration(days: 3, hours: 15))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[7] // Henry
      ..serviceId = serviceIds[3] // Consultation
      ..startTime = today.add(const Duration(days: 4, hours: 9))
      ..endTime = today.add(const Duration(days: 4, hours: 9, minutes: 20))
      ..status = 'upcoming'
      ..staffId = 1,
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[0] // Alice
      ..serviceId = serviceIds[4] // Facial
      ..startTime = today.add(const Duration(days: 5, hours: 10))
      ..endTime = today.add(const Duration(days: 5, hours: 11))
      ..status = 'upcoming'
      ..staffId = 1,
    // Past appointments (done)
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[1] // Bob
      ..serviceId = serviceIds[2] // Manicure
      ..startTime = today.subtract(const Duration(days: 2, hours: 11))
      ..endTime = today.subtract(const Duration(days: 2, hours: 11, minutes: 45))
      ..status = 'done'
      ..staffId = 1,
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
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
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0101'
      ..timestamp = now.subtract(const Duration(hours: 1))
      ..direction = 'incoming'
      ..durationSeconds = 120
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId = appointmentIds.isNotEmpty ? appointmentIds[0] : null,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0109'
      ..timestamp = now.subtract(const Duration(hours: 2))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0102'
      ..timestamp = now.subtract(const Duration(hours: 3))
      ..direction = 'outgoing'
      ..durationSeconds = 60
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId = appointmentIds.length > 1 ? appointmentIds[1] : null,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0110'
      ..timestamp = now.subtract(const Duration(hours: 5))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0103'
      ..timestamp = now.subtract(const Duration(hours: 8))
      ..direction = 'incoming'
      ..durationSeconds = 180
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId = appointmentIds.length > 2 ? appointmentIds[2] : null,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0111'
      ..timestamp = now.subtract(const Duration(days: 1))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..phoneNumber = '+1-555-0104'
      ..timestamp = now.subtract(const Duration(days: 1, hours: 2))
      ..direction = 'outgoing'
      ..durationSeconds = 45
      ..isMissed = false
      ..followedUp = true,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
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