import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';

/// Test helpers for HiveService tests
class TestHiveHelpers {
  /// Creates a HiveService with in-memory boxes for testing
  static Future<HiveService> createServiceWithInMemoryBoxes() async {
    final service = HiveService();

    // Override the init to use in-memory boxes
    // Note: In real tests, we'd use Hive.openBox with inMemory = true
    // but since HiveService uses late Box fields, we need integration tests
    // For unit tests, we mock the service

    return service;
  }

  /// Creates a CallLog for testing
  static CallLog createCallLog({
    int? id,
    String phoneNumber = '+1234567890',
    DateTime? timestamp,
    String direction = 'incoming',
    int durationSeconds = 60,
    bool isMissed = false,
    bool followedUp = false,
  }) {
    return CallLog()
      ..id = id
      ..phoneNumber = phoneNumber
      ..timestamp = timestamp ?? DateTime.now()
      ..direction = direction
      ..durationSeconds = durationSeconds
      ..isMissed = isMissed
      ..followedUp = followedUp
      ..createdAt = DateTime.now()
      ..synced = false;
  }

  /// Creates an Appointment for testing
  static Appointment createAppointment({
    int? id,
    int? customerId,
    int? serviceId,
    DateTime? startTime,
    DateTime? endTime,
    String status = 'upcoming',
    String? notes,
  }) {
    final start = startTime ?? DateTime.now().add(const Duration(hours: 1));
    return Appointment()
      ..id = id
      ..customerId = customerId
      ..serviceId = serviceId
      ..startTime = start
      ..endTime = endTime ?? start.add(const Duration(hours: 1))
      ..status = status
      ..notes = notes
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;
  }

  /// Creates a Customer for testing
  static Customer createCustomer({
    int? id,
    String name = 'Test Customer',
    String phoneNumber = '+1234567890',
    String? email,
    String? notes,
  }) {
    return Customer()
      ..id = id
      ..name = name
      ..phoneNumber = phoneNumber
      ..email = email
      ..notes = notes
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;
  }

  /// Creates a Service for testing
  static Service createService({
    int? id,
    String title = 'Test Service',
    int defaultDurationMinutes = 60,
    double cost = 99.99,
    String? description,
  }) {
    return Service()
      ..id = id
      ..title = title
      ..defaultDurationMinutes = defaultDurationMinutes
      ..cost = cost
      ..description = description
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;
  }
}
