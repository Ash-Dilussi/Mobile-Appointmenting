#!/usr/bin/env dart
/// Seed Dummy Data - Populate Hive database with test data for dashboard
/// Usage: dart run scripts/seed_data.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../lib/core/database/collections/collections.dart';

Future<void> main() async {
  // Initialize Hive (same as app)
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(CustomerAdapter());
  Hive.registerAdapter(ServiceAdapter());
  Hive.registerAdapter(AppointmentAdapter());
  Hive.registerAdapter(CallLogAdapter());
  Hive.registerAdapter(SyncQueueItemAdapter());
  Hive.registerAdapter(ServiceStationAdapter());

  // Open boxes
  final customersBox = await Hive.openBox<Customer>('customers');
  final servicesBox = await Hive.openBox<Service>('services');
  final appointmentsBox = await Hive.openBox<Appointment>('appointments');
  final callLogsBox = await Hive.openBox<CallLog>('callLogs');

  // Check if already seeded
  if (customersBox.isNotEmpty) {
    print('ℹ️  Database already has ${customersBox.length} customers. Skipping seed.');
    print('   To re-seed, first clear the database with: flutter clean');
    await Hive.close();
    return;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  print('🌱 Seeding dummy data...');

  // Seed Customers
  final customerData = [
    {'name': 'Alice Johnson', 'phone': '+1-555-0101', 'email': 'alice@example.com', 'notes': 'Regular client, prefers morning appointments'},
    {'name': 'Bob Smith', 'phone': '+1-555-0102', 'email': 'bob@example.com', 'notes': 'Prefers text message reminders'},
    {'name': 'Carol White', 'phone': '+1-555-0103', 'email': 'carol@example.com', 'notes': 'VIP client'},
    {'name': 'David Brown', 'phone': '+1-555-0104', 'email': 'david@example.com', 'notes': ''},
    {'name': 'Emma Davis', 'phone': '+1-555-0105', 'email': 'emma@example.com', 'notes': 'Allergic to certain products'},
    {'name': 'Frank Miller', 'phone': '+1-555-0106', 'email': 'frank@example.com', 'notes': ''},
    {'name': 'Grace Wilson', 'phone': '+1-555-0107', 'email': 'grace@example.com', 'notes': 'Prefers afternoon appointments'},
    {'name': 'Henry Taylor', 'phone': '+1-555-0108', 'email': 'henry@example.com', 'notes': ''},
  ];

  for (final data in customerData) {
    final customer = Customer()
      ..name = data['name']!
      ..phoneNumber = data['phone']!
      ..email = data['email']!
      ..notes = data['notes']!
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    await customersBox.add(customer);
  }
  print('   ✓ Added ${customerData.length} customers');

  // Seed Services
  final serviceData = <Map<String, dynamic>>[
    {'title': 'Haircut', 'duration': 30, 'cost': 45.0, 'desc': 'Standard haircut and style'},
    {'title': 'Massage', 'duration': 60, 'cost': 80.0, 'desc': 'Full body relaxation massage'},
    {'title': 'Manicure', 'duration': 45, 'cost': 35.0, 'desc': 'Nail care and polish'},
    {'title': 'Consultation', 'duration': 20, 'cost': 0.0, 'desc': 'Free initial consultation'},
    {'title': 'Facial', 'duration': 60, 'cost': 95.0, 'desc': 'Deep cleansing facial treatment'},
    {'title': 'Teeth Whitening', 'duration': 45, 'cost': 150.0, 'desc': 'Professional teeth whitening'},
  ];

  for (final data in serviceData) {
    final service = Service()
      ..title = data['title'] as String
      ..defaultDurationMinutes = data['duration'] as int
      ..cost = data['cost'] as double
      ..description = data['desc'] as String
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    await servicesBox.add(service);
  }
  print('   ✓ Added ${serviceData.length} services');

  // Seed Appointments
  final appointmentData = [
    // Today's appointments
    {'customerId': 0, 'serviceId': 0, 'startOffset': const Duration(hours: 9), 'endOffset': const Duration(hours: 9, minutes: 30), 'status': 'confirmed'},
    {'customerId': 1, 'serviceId': 1, 'startOffset': const Duration(hours: 10), 'endOffset': const Duration(hours: 11), 'status': 'upcoming'},
    {'customerId': 2, 'serviceId': 4, 'startOffset': const Duration(hours: 14), 'endOffset': const Duration(hours: 15), 'status': 'upcoming'},
    {'customerId': 4, 'serviceId': 2, 'startOffset': const Duration(hours: 15, minutes: 30), 'endOffset': const Duration(hours: 16, minutes: 15), 'status': 'upcoming'},
    // Upcoming
    {'customerId': 3, 'serviceId': 0, 'startOffset': const Duration(days: 1, hours: 10), 'endOffset': const Duration(days: 1, hours: 10, minutes: 30), 'status': 'upcoming'},
    {'customerId': 5, 'serviceId': 5, 'startOffset': const Duration(days: 2, hours: 11), 'endOffset': const Duration(days: 2, hours: 11, minutes: 45), 'status': 'upcoming'},
    {'customerId': 6, 'serviceId': 1, 'startOffset': const Duration(days: 3, hours: 14), 'endOffset': const Duration(days: 3, hours: 15), 'status': 'upcoming'},
    {'customerId': 7, 'serviceId': 3, 'startOffset': const Duration(days: 4, hours: 9), 'endOffset': const Duration(days: 4, hours: 9, minutes: 20), 'status': 'upcoming'},
    {'customerId': 0, 'serviceId': 4, 'startOffset': const Duration(days: 5, hours: 10), 'endOffset': const Duration(days: 5, hours: 11), 'status': 'upcoming'},
    // Past
    {'customerId': 1, 'serviceId': 2, 'startOffset': const Duration(days: -2, hours: 11), 'endOffset': const Duration(days: -2, hours: 11, minutes: 45), 'status': 'done'},
    {'customerId': 2, 'serviceId': 0, 'startOffset': const Duration(days: -5, hours: 10), 'endOffset': const Duration(days: -5, hours: 10, minutes: 30), 'status': 'done'},
  ];

  for (final data in appointmentData) {
    final appointment = Appointment()
      ..customerId = data['customerId'] as int
      ..serviceId = data['serviceId'] as int
      ..startTime = today.add(data['startOffset'] as Duration)
      ..endTime = today.add(data['endOffset'] as Duration)
      ..status = data['status'] as String
      ..staffId = 1
      ..notes = ''
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    await appointmentsBox.add(appointment);
  }
  print('   ✓ Added ${appointmentData.length} appointments');

  // Seed Call Logs
  final callLogData = [
    {'phone': '+1-555-0101', 'offset': const Duration(hours: 1), 'direction': 'incoming', 'duration': 120, 'missed': false, 'followedUp': true, 'apptId': 0},
    {'phone': '+1-555-0109', 'offset': const Duration(hours: 2), 'direction': 'incoming', 'duration': 0, 'missed': true, 'followedUp': false, 'apptId': null},
    {'phone': '+1-555-0102', 'offset': const Duration(hours: 3), 'direction': 'outgoing', 'duration': 60, 'missed': false, 'followedUp': true, 'apptId': 1},
    {'phone': '+1-555-0110', 'offset': const Duration(hours: 5), 'direction': 'incoming', 'duration': 0, 'missed': true, 'followedUp': false, 'apptId': null},
    {'phone': '+1-555-0103', 'offset': const Duration(hours: 8), 'direction': 'incoming', 'duration': 180, 'missed': false, 'followedUp': true, 'apptId': 2},
    {'phone': '+1-555-0111', 'offset': const Duration(days: 1), 'direction': 'incoming', 'duration': 0, 'missed': true, 'followedUp': false, 'apptId': null},
    {'phone': '+1-555-0104', 'offset': const Duration(days: 1, hours: 2), 'direction': 'outgoing', 'duration': 45, 'missed': false, 'followedUp': true, 'apptId': null},
    {'phone': '+1-555-0112', 'offset': const Duration(days: 2), 'direction': 'incoming', 'duration': 0, 'missed': true, 'followedUp': true, 'apptId': null},
  ];

  for (final data in callLogData) {
    final callLog = CallLog()
      ..phoneNumber = data['phone'] as String
      ..timestamp = now.subtract(data['offset'] as Duration)
      ..direction = data['direction'] as String
      ..durationSeconds = data['duration'] as int
      ..isMissed = data['missed'] as bool
      ..followedUp = data['followedUp'] as bool
      ..linkedAppointmentId = data['apptId'] as int?
      ..createdAt = now
      ..synced = false;
    await callLogsBox.add(callLog);
  }
  print('   ✓ Added ${callLogData.length} call logs');

  print('✅ Seed complete! ${customersBox.length} customers, ${servicesBox.length} services, ${appointmentsBox.length} appointments, ${callLogsBox.length} call logs');
  await Hive.close();
}