import 'core/database/hive_service.dart';
import 'core/database/collections/collections.dart';
import 'core/theme/style_preset.dart';
import 'core/theme/service_color_palette.dart';

/// Seeds the Hive database with dummy data for testing the dashboard.
/// Run this function after HiveService.init() to populate sample data.
Future<void> seedDummyData(HiveService hive,
    {bool force = false, String? institutionId}) async {
  // Check if already seeded (skip if force is true)
  if (!force) {
    final existingCustomers = hive.getAllCustomers();
    if (existingCustomers.isNotEmpty) {
      return; // Already seeded
    }
  }

  // Clear all data before seeding fresh
  await hive.clearAllData();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Create institution for this seed data
  final instId =
      institutionId ?? 'demo_institution_${now.millisecondsSinceEpoch}';

  // Seed users with both complete and intentionally sparse optional profiles.
  final ownerUserId = 'owner_${now.millisecondsSinceEpoch}';
  final officerUserId = 'officer_${now.millisecondsSinceEpoch}';
  final sparseOfficerUserId = 'officer_sparse_${now.millisecondsSinceEpoch}';
  final owner = User()
    ..id = ownerUserId
    ..institutionId = instId
    ..email = 'owner@demo.com'
    ..name = 'Maya Patel'
    ..role = 'owner'
    ..address = '42 Market Street'
    ..birthdate = DateTime(1988, 4, 16)
    ..gender = 'female'
    ..phone = '+1-555-0190'
    ..status = 'active';
  await hive.insertUser(owner);

  final officer = User()
    ..id = officerUserId
    ..institutionId = instId
    ..email = 'jordan@demo.com'
    ..name = 'Jordan Lee'
    ..role = 'officer'
    ..phone = '+1-555-0191'
    ..status = 'active';
  await hive.insertUser(officer);

  final sparseOfficer = User()
    ..id = sparseOfficerUserId
    ..institutionId = instId
    ..email = 'sam@demo.com'
    ..name = 'Sam Rivera'
    ..role = 'officer'
    ..address = ''
    ..status = 'pending_leave';
  await hive.insertUser(sparseOfficer);

  // Create institution
  final institution = Institution()
    ..id = instId
    ..name = 'Demo Salon & Spa'
    ..themePreset = StylePreset.solarOrange.name
    ..ownerId = ownerUserId
    ..address = '42 Market Street, Brookfield'
    ..phone = '+1-555-0100'
    ..email = 'hello@demosalon.example';
  await hive.insertInstitution(institution);

  // Seed Customers - track returned IDs
  final customerIds = <int>[];
  CustomerNote customerNote(
    String id,
    String title, {
    String? description,
  }) =>
      CustomerNote(
        id: id,
        title: title,
        description: description,
        createdAt: now,
        updatedAt: now,
      );
  final customers = [
    Customer()
      ..institutionId = instId
      ..name = 'Alice Johnson'
      ..phoneNumber = '+1-555-0101'
      ..email = 'alice@example.com'
      ..address = '18 Pine Avenue'
      ..city = 'Brookfield'
      ..dob = DateTime(1991, 6, 12)
      ..notes = [
        customerNote(
          'seed-customer-note-1',
          'Prefers mornings',
          description: 'Usually available before 11 AM.',
        ),
        customerNote('seed-customer-note-2', 'Text reminders'),
      ],
    Customer()
      ..institutionId = instId
      ..name = 'Bob Smith'
      ..phoneNumber = '+1-555-0102'
      ..email = null
      ..address = '7 Lake Road'
      ..city = 'Riverton'
      ..notes = [customerNote('seed-customer-note-3', 'Text reminders')],
    Customer()
      ..institutionId = instId
      ..name = 'Carol White'
      ..phoneNumber = '+1-555-0103'
      ..email = 'carol@example.com'
      ..city = 'Brookfield'
      ..dob = DateTime(1979, 11, 3)
      ..notes = [
        customerNote(
          'seed-customer-note-4',
          'VIP client',
          description: 'Offer a quiet waiting area when available.',
        ),
      ],
    Customer()
      ..institutionId = instId
      ..name = 'David Brown'
      ..phoneNumber = '+1-555-0104'
      ..email = 'david@example.com'
      ..address = ''
      ..city = '',
    Customer()
      ..institutionId = instId
      ..name = 'Emma Davis'
      ..phoneNumber = '+1-555-0105'
      ..email = null
      ..address = '90 Cedar Lane'
      ..city = 'Fairview'
      ..dob = DateTime(1995, 2, 24)
      ..notes = [
        customerNote(
          'seed-customer-note-5',
          'Product allergy',
          description: 'Avoid products containing almond oil.',
        ),
      ],
    Customer()
      ..institutionId = instId
      ..name = 'Frank Miller'
      ..phoneNumber = '+1-555-0106'
      ..email = '',
    Customer()
      ..institutionId = instId
      ..name = 'Grace Wilson'
      ..phoneNumber = '+1-555-0107'
      ..email = 'grace@example.com'
      ..city = 'Riverton'
      ..notes = [customerNote('seed-customer-note-6', 'Prefers afternoons')],
    Customer()
      ..institutionId = instId
      ..name = 'Henry Taylor'
      ..phoneNumber = '+1-555-0108'
      ..email = 'henry@example.com'
      ..address = '12 Hillcrest Drive'
      ..dob = DateTime(1984, 9, 8),
    Customer()
      ..institutionId = instId
      ..name = 'Walk-in Guest'
      ..phoneNumber = ''
      ..email = null
      ..address = null
      ..city = null
      ..dob = null
      ..notes = <CustomerNote>[],
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
      ..colorValue = ServiceColorPalette.options[5].argbValue
      ..defaultDurationMinutes = 30
      ..cost = 45.00
      ..description = 'Standard haircut and style',
    Service()
      ..institutionId = instId
      ..title = 'Massage'
      ..colorValue = ServiceColorPalette.options[7].argbValue
      ..defaultDurationMinutes = 60
      ..cost = 80.00
      ..description = 'Full body relaxation massage',
    Service()
      ..institutionId = instId
      ..title = 'Manicure'
      ..colorValue = ServiceColorPalette.options[8].argbValue
      ..defaultDurationMinutes = 45
      ..cost = 35.00
      ..description = 'Nail care and polish',
    Service()
      ..institutionId = instId
      ..title = 'Consultation'
      ..colorValue = ServiceColorPalette.options[4].argbValue
      ..defaultDurationMinutes = 20
      ..cost = 0.00
      ..description = null,
    Service()
      ..institutionId = instId
      ..title = 'Facial'
      ..colorValue = ServiceColorPalette.options[1].argbValue
      ..defaultDurationMinutes = 60
      ..cost = 95.00
      ..description = 'Deep cleansing facial treatment',
    Service()
      ..institutionId = instId
      ..title = 'Teeth Whitening'
      ..colorValue = ServiceColorPalette.options[9].argbValue
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
      ..address = '42 Market Street, Brookfield'
      ..phone = '+1-555-0100'
      ..description = 'Main salon and reception desk',
    ServiceStation()
      ..institutionId = instId
      ..name = 'Mall Branch'
      ..address = 'Level 2, River Mall'
      ..phone = null
      ..description = '',
  ];

  for (final station in stations) {
    final id = await hive.insertServiceStation(station);
    stationIds.add(id!);
  }

  // Seed Appointments (today and upcoming)
  AppointmentNote appointmentNote(
    String id,
    String title, {
    String? description,
  }) =>
      AppointmentNote(
        id: id,
        title: title,
        description: description,
        createdAt: now,
        updatedAt: now,
      );

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
      ..notes = [
        appointmentNote(
          'seed-appointment-note-1',
          'Style preference',
          description: 'Prefers short hair',
        ),
      ],
    Appointment()
      ..institutionId = instId
      ..handledByUserId = officerUserId
      ..customerId = customerIds[1] // Bob
      ..serviceId = serviceIds[1] // Massage
      ..startTime = today.add(const Duration(hours: 10))
      ..endTime = today.add(const Duration(hours: 11))
      ..status = 'upcoming'
      ..staffId = 2
      ..stationId = null
      ..notes = [
        appointmentNote('seed-appointment-note-2', 'Unscented products'),
      ],
    Appointment()
      ..institutionId = instId
      ..handledByUserId = officerUserId
      ..customerId = customerIds[2] // Carol
      ..serviceId = serviceIds[4] // Facial
      ..startTime = today.add(const Duration(hours: 14))
      ..endTime = today.add(const Duration(hours: 15, minutes: 45))
      ..status = 'upcoming'
      ..staffId = 2
      ..stationId = stationIds[0]
      ..notes = [
        appointmentNote(
          'seed-appointment-note-3',
          'Combined treatment',
          description: 'Facial followed by a manicure.',
        ),
      ],
    Appointment()
      ..institutionId = instId
      ..handledByUserId = sparseOfficerUserId
      ..customerId = customerIds[4] // Emma
      ..serviceId = serviceIds[2] // Manicure
      ..startTime = today.add(const Duration(hours: 15, minutes: 30))
      ..endTime = today.add(const Duration(hours: 16, minutes: 15))
      ..status = 'upcoming'
      ..stationId = stationIds[1] // Mall Branch
      ..notes = <AppointmentNote>[],
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
      ..handledByUserId = officerUserId
      ..customerId = customerIds[5] // Frank
      ..serviceId = serviceIds[5] // Teeth Whitening
      ..startTime = today.add(const Duration(days: 2, hours: 11))
      ..endTime = today.add(const Duration(days: 2, hours: 11, minutes: 45))
      ..status = 'upcoming'
      ..staffId = 2,
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
      ..handledByUserId = officerUserId
      ..customerId = customerIds[7] // Henry
      ..serviceId = serviceIds[3] // Consultation
      ..startTime = today.add(const Duration(days: 4, hours: 9))
      ..endTime = today.add(const Duration(days: 4, hours: 9, minutes: 20))
      ..status = 'upcoming'
      ..staffId = 2
      ..stationId = stationIds[1]
      ..notes = [
        appointmentNote(
          'seed-appointment-note-4',
          'First visit',
          description: '',
        ),
      ],
    Appointment()
      ..institutionId = instId
      ..handledByUserId = sparseOfficerUserId
      ..customerId = customerIds[0] // Alice
      ..serviceId = serviceIds[4] // Facial
      ..startTime = today.add(const Duration(days: 5, hours: 10))
      ..endTime = today.add(const Duration(days: 5, hours: 11))
      ..status = 'upcoming'
      ..stationId = stationIds[0],
    // Past appointments (done)
    Appointment()
      ..institutionId = instId
      ..handledByUserId = sparseOfficerUserId
      ..customerId = customerIds[1] // Bob
      ..serviceId = serviceIds[2] // Manicure
      ..startTime = today.subtract(const Duration(days: 2)).add(
            const Duration(hours: 11),
          )
      ..endTime = today.subtract(const Duration(days: 2)).add(
            const Duration(hours: 11, minutes: 45),
          )
      ..status = 'done'
      ..stationId = stationIds[1],
    Appointment()
      ..institutionId = instId
      ..handledByUserId = ownerUserId
      ..customerId = customerIds[2] // Carol
      ..serviceId = serviceIds[0] // Haircut
      ..startTime = today.subtract(const Duration(days: 5)).add(
            const Duration(hours: 10),
          )
      ..endTime = today.subtract(const Duration(days: 5)).add(
            const Duration(hours: 10, minutes: 30),
          )
      ..status = 'done'
      ..staffId = 1
      ..stationId = stationIds[0],
    // Cancelled sparse booking exercises allowed empty optional relationships.
    Appointment()
      ..institutionId = instId
      ..handledByUserId = null
      ..customerId = customerIds[8] // Walk-in Guest
      ..serviceId = serviceIds[3] // Consultation
      ..startTime = today.add(const Duration(days: 1, hours: 16))
      ..endTime = today.add(const Duration(days: 1, hours: 16, minutes: 20))
      ..status = 'cancelled'
      ..staffId = null
      ..stationId = null
      ..notes = <AppointmentNote>[],
  ];

  // Track appointment IDs for linking call logs
  final appointmentIds = <int>[];
  for (final appointment in appointments) {
    final id = await hive.insertAppointment(appointment);
    appointmentIds.add(id!);
  }

  // Seed the current multi-service line-item model for every appointment.
  Future<void> addAppointmentService({
    required int appointmentIndex,
    required int serviceIndex,
    double? priceOverride,
    int? durationOverride,
    String? notes,
  }) async {
    final id = await hive.insertAppointmentService(
      AppointmentService()
        ..institutionId = instId
        ..appointmentId = appointmentIds[appointmentIndex]
        ..serviceId = serviceIds[serviceIndex]
        ..priceOverride = priceOverride
        ..durationOverride = durationOverride
        ..notes = notes,
    );
    if (id == null) {
      throw StateError('Failed to seed an appointment service');
    }
  }

  await addAppointmentService(appointmentIndex: 0, serviceIndex: 0);
  await addAppointmentService(
    appointmentIndex: 1,
    serviceIndex: 1,
    notes: 'Use unscented massage oil',
  );
  await addAppointmentService(
    appointmentIndex: 2,
    serviceIndex: 4,
    priceOverride: 90,
    durationOverride: 60,
  );
  await addAppointmentService(
    appointmentIndex: 2,
    serviceIndex: 2,
    priceOverride: 30,
    durationOverride: 45,
    notes: '',
  );
  await addAppointmentService(appointmentIndex: 3, serviceIndex: 2);
  await addAppointmentService(appointmentIndex: 4, serviceIndex: 0);
  await addAppointmentService(appointmentIndex: 5, serviceIndex: 5);
  await addAppointmentService(appointmentIndex: 6, serviceIndex: 1);
  await addAppointmentService(appointmentIndex: 7, serviceIndex: 3);
  await addAppointmentService(appointmentIndex: 8, serviceIndex: 4);
  await addAppointmentService(appointmentIndex: 9, serviceIndex: 2);
  await addAppointmentService(appointmentIndex: 10, serviceIndex: 0);
  await addAppointmentService(appointmentIndex: 11, serviceIndex: 3);

  // Seed Call Logs
  final callLogs = [
    CallLog()
      ..institutionId = instId
      ..handledByUserId = officerUserId
      ..phoneNumber = '+1-555-0101'
      ..timestamp = now.subtract(const Duration(hours: 1))
      ..direction = 'incoming'
      ..durationSeconds = 120
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId =
          appointmentIds.isNotEmpty ? appointmentIds[0] : null,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = sparseOfficerUserId
      ..phoneNumber = '+1-555-0109'
      ..timestamp = now.subtract(const Duration(hours: 2))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = officerUserId
      ..phoneNumber = '+1-555-0102'
      ..timestamp = now.subtract(const Duration(hours: 3))
      ..direction = 'outgoing'
      ..durationSeconds = 60
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId =
          appointmentIds.length > 1 ? appointmentIds[1] : null,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = null
      ..phoneNumber = '+1-555-0110'
      ..timestamp = now.subtract(const Duration(hours: 5))
      ..direction = 'incoming'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = officerUserId
      ..phoneNumber = '+1-555-0103'
      ..timestamp = now.subtract(const Duration(hours: 8))
      ..direction = 'incoming'
      ..durationSeconds = 180
      ..isMissed = false
      ..followedUp = true
      ..linkedAppointmentId =
          appointmentIds.length > 2 ? appointmentIds[2] : null,
    CallLog()
      ..institutionId = instId
      ..handledByUserId = sparseOfficerUserId
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
