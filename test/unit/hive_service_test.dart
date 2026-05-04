import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers/test_helpers.dart';

/// Unit tests for HiveService CRUD operations
/// These tests use actual Hive in-memory boxes for integration testing
void main() {
  late HiveService hiveService;
  late Directory tempDir;

  setUpAll(() async {
    // Initialize Flutter binding for path_provider
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create a temp directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test_');

    // Set up mock path provider to use the temp directory
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      // Return the temp directory path for any path_provider method
      return tempDir.path;
    });

    // Also set up mock for any platform views channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/platform'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Initialize Hive with temp directory
    await Hive.initFlutter(tempDir.path);

    // Initialize HiveService once - this registers adapters and opens boxes
    hiveService = HiveService();
    await hiveService.init();
  });

  tearDownAll(() async {
    // Close Hive to allow cleanup
    await Hive.close();
    // Clean up temp directory
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    // Clear all boxes before each test
    await hiveService.clearAllData();
  });

  group('HiveService CallLog CRUD', () {
    test('insertCallLog should insert and return key', () async {
      final callLog = TestHiveHelpers.createCallLog(
        phoneNumber: '+1234567890',
        direction: 'incoming',
        durationSeconds: 120,
        isMissed: false,
      );

      final key = await hiveService.insertCallLog(callLog);

      expect(key, isNotNull);
      expect(callLog.id, equals(key));
    });

    test('getAllCallLogs should return all inserted call logs sorted by timestamp', () async {
      final now = DateTime.now();

      final callLog1 = TestHiveHelpers.createCallLog(
        phoneNumber: '+1111111111',
        timestamp: now.subtract(const Duration(hours: 2)),
      );
      final callLog2 = TestHiveHelpers.createCallLog(
        phoneNumber: '+2222222222',
        timestamp: now.subtract(const Duration(hours: 1)),
      );
      final callLog3 = TestHiveHelpers.createCallLog(
        phoneNumber: '+3333333333',
        timestamp: now,
      );

      await hiveService.insertCallLog(callLog1);
      await hiveService.insertCallLog(callLog2);
      await hiveService.insertCallLog(callLog3);

      final allLogs = hiveService.getAllCallLogs();

      expect(allLogs.length, equals(3));
      // Should be sorted descending by timestamp (most recent first)
      expect(allLogs[0].phoneNumber, equals('+3333333333'));
      expect(allLogs[1].phoneNumber, equals('+2222222222'));
      expect(allLogs[2].phoneNumber, equals('+1111111111'));
    });

    test('getMissedCalls should return only missed and not followed up calls', () async {
      final now = DateTime.now();

      final missedCall1 = TestHiveHelpers.createCallLog(
        phoneNumber: '+1111111111',
        isMissed: true,
        followedUp: false,
        timestamp: now,
      );
      final missedCall2 = TestHiveHelpers.createCallLog(
        phoneNumber: '+2222222222',
        isMissed: true,
        followedUp: false,
        timestamp: now.subtract(const Duration(minutes: 5)),
      );
      final answeredCall = TestHiveHelpers.createCallLog(
        phoneNumber: '+3333333333',
        isMissed: false,
        followedUp: false,
        timestamp: now.subtract(const Duration(minutes: 10)),
      );
      final followedUpCall = TestHiveHelpers.createCallLog(
        phoneNumber: '+4444444444',
        isMissed: true,
        followedUp: true,
        timestamp: now.subtract(const Duration(minutes: 15)),
      );

      await hiveService.insertCallLog(missedCall1);
      await hiveService.insertCallLog(missedCall2);
      await hiveService.insertCallLog(answeredCall);
      await hiveService.insertCallLog(followedUpCall);

      final missedCalls = hiveService.getMissedCalls();

      expect(missedCalls.length, equals(2));
      expect(missedCalls.every((c) => c.isMissed && !c.followedUp), isTrue);
    });

    test('updateCallLog should mark call as followed up', () async {
      final callLog = TestHiveHelpers.createCallLog(
        phoneNumber: '+1234567890',
        isMissed: true,
        followedUp: false,
      );

      final key = await hiveService.insertCallLog(callLog);
      expect(key, isNotNull);

      callLog.followedUp = true;
      await hiveService.updateCallLog(key!, callLog);

      final updated = hiveService.getCallLogById(key);
      expect(updated?.followedUp, isTrue);
    });

    test('deleteCallLog should remove call log', () async {
      final callLog = TestHiveHelpers.createCallLog(
        phoneNumber: '+1234567890',
      );

      final key = await hiveService.insertCallLog(callLog);
      await hiveService.deleteCallLog(key!);

      final deleted = hiveService.getCallLogById(key);
      expect(deleted, isNull);
    });
  });

  group('HiveService Appointment CRUD', () {
    test('insertAppointment should insert and set id', () async {
      final appointment = TestHiveHelpers.createAppointment(
        customerId: 1,
        serviceId: 1,
        startTime: DateTime.now().add(const Duration(hours: 1)),
        status: 'upcoming',
      );

      final key = await hiveService.insertAppointment(appointment);

      expect(key, isNotNull);
      expect(appointment.id, equals(key));
    });

    test('getAllAppointments should return all appointments', () async {
      final appointment1 = TestHiveHelpers.createAppointment(customerId: 1);
      final appointment2 = TestHiveHelpers.createAppointment(customerId: 2);

      await hiveService.insertAppointment(appointment1);
      await hiveService.insertAppointment(appointment2);

      final all = hiveService.getAllAppointments();

      expect(all.length, equals(2));
    });

    test('getAppointmentsForDate should filter by date', () async {
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      final todayAppointment = TestHiveHelpers.createAppointment(
        startTime: DateTime(today.year, today.month, today.day, 10, 0),
        status: 'upcoming',
      );
      final tomorrowAppointment = TestHiveHelpers.createAppointment(
        startTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
        status: 'upcoming',
      );

      await hiveService.insertAppointment(todayAppointment);
      await hiveService.insertAppointment(tomorrowAppointment);

      final todayAppointments = hiveService.getAppointmentsForDate(today);
      final tomorrowAppointments = hiveService.getAppointmentsForDate(tomorrow);

      expect(todayAppointments.length, equals(1));
      expect(tomorrowAppointments.length, equals(1));
    });

    test('getUpcomingAppointments should return future appointments with upcoming status', () async {
      final now = DateTime.now();

      final upcomingFuture = TestHiveHelpers.createAppointment(
        startTime: now.add(const Duration(hours: 2)),
        status: 'upcoming',
      );
      final upcomingPast = TestHiveHelpers.createAppointment(
        startTime: now.subtract(const Duration(hours: 2)),
        status: 'upcoming',
      );
      final doneFuture = TestHiveHelpers.createAppointment(
        startTime: now.add(const Duration(hours: 3)),
        status: 'done',
      );

      await hiveService.insertAppointment(upcomingFuture);
      await hiveService.insertAppointment(upcomingPast);
      await hiveService.insertAppointment(doneFuture);

      final upcoming = hiveService.getUpcomingAppointments();

      expect(upcoming.length, equals(1));
      expect(upcoming[0].id, equals(upcomingFuture.id));
      // Should be sorted by startTime
      expect(upcoming[0].startTime.isAfter(now), isTrue);
    });

    test('updateAppointment should update status', () async {
      final appointment = TestHiveHelpers.createAppointment(
        status: 'upcoming',
      );

      final key = await hiveService.insertAppointment(appointment);
      appointment.status = 'confirmed';
      await hiveService.updateAppointment(key!, appointment);

      final updated = hiveService.getAppointmentById(key);
      expect(updated?.status, equals('confirmed'));
    });

    test('deleteAppointment should remove appointment', () async {
      final appointment = TestHiveHelpers.createAppointment();

      final key = await hiveService.insertAppointment(appointment);
      await hiveService.deleteAppointment(key!);

      final deleted = hiveService.getAppointmentById(key);
      expect(deleted, isNull);
    });
  });

  group('HiveService Customer CRUD', () {
    test('insertCustomer should insert and set id', () async {
      final customer = TestHiveHelpers.createCustomer(
        name: 'John Doe',
        phoneNumber: '+1234567890',
      );

      final key = await hiveService.insertCustomer(customer);

      expect(key, isNotNull);
      expect(customer.id, equals(key));
    });

    test('getCustomerByPhone should find customer by phone number', () async {
      final customer = TestHiveHelpers.createCustomer(
        name: 'John Doe',
        phoneNumber: '+1234567890',
      );

      await hiveService.insertCustomer(customer);

      final found = hiveService.getCustomerByPhone('+1234567890');

      expect(found, isNotNull);
      expect(found?.name, equals('John Doe'));
    });

    test('getCustomerByPhone should return null for non-existent phone', () async {
      final found = hiveService.getCustomerByPhone('+9999999999');

      expect(found, isNull);
    });

    test('updateCustomer should update customer data', () async {
      final customer = TestHiveHelpers.createCustomer(
        name: 'Original Name',
      );

      final key = await hiveService.insertCustomer(customer);
      customer.name = 'Updated Name';
      await hiveService.updateCustomer(key!, customer);

      final updated = hiveService.getCustomerById(key);
      expect(updated?.name, equals('Updated Name'));
    });

    test('deleteCustomer should remove customer', () async {
      final customer = TestHiveHelpers.createCustomer();

      final key = await hiveService.insertCustomer(customer);
      await hiveService.deleteCustomer(key!);

      final deleted = hiveService.getCustomerById(key);
      expect(deleted, isNull);
    });
  });

  group('HiveService Service CRUD', () {
    test('insertService should insert and set id', () async {
      final service = TestHiveHelpers.createService(
        title: 'Haircut',
        defaultDurationMinutes: 60,
        cost: 50.0,
      );

      final key = await hiveService.insertService(service);

      expect(key, isNotNull);
      expect(service.id, equals(key));
    });

    test('getAllServices should return all services', () async {
      await hiveService.insertService(TestHiveHelpers.createService(title: 'Service A'));
      await hiveService.insertService(TestHiveHelpers.createService(title: 'Service B'));

      final all = hiveService.getAllServices();

      expect(all.length, equals(2));
    });

    test('getServiceById should return service by id', () async {
      final service = TestHiveHelpers.createService(title: 'Haircut');

      final key = await hiveService.insertService(service);
      final found = hiveService.getServiceById(key!);

      expect(found?.title, equals('Haircut'));
    });

    test('updateService should update service', () async {
      final service = TestHiveHelpers.createService(title: 'Haircut');

      final key = await hiveService.insertService(service);
      service.title = 'Deluxe Haircut';
      await hiveService.updateService(key!, service);

      final updated = hiveService.getServiceById(key);
      expect(updated?.title, equals('Deluxe Haircut'));
    });

    test('deleteService should remove service', () async {
      final service = TestHiveHelpers.createService();

      final key = await hiveService.insertService(service);
      await hiveService.deleteService(key!);

      final deleted = hiveService.getServiceById(key);
      expect(deleted, isNull);
    });
  });

  group('HiveService Stream Methods', () {
    test('watchAllCallLogs should emit initial data immediately', () async {
      // Insert some data first
      await hiveService.insertCallLog(TestHiveHelpers.createCallLog(phoneNumber: '+1111111111'));
      await hiveService.insertCallLog(TestHiveHelpers.createCallLog(phoneNumber: '+2222222222'));

      // Create stream
      final stream = hiveService.watchAllCallLogs();

      // Collect first value - should have data immediately (buffered pattern)
      final logs = await stream.first;

      expect(logs.length, greaterThanOrEqualTo(2));
    });

    test('watchMissedCalls should emit filtered data', () async {
      // Insert some data
      await hiveService.insertCallLog(TestHiveHelpers.createCallLog(
        phoneNumber: '+1111111111',
        isMissed: true,
        followedUp: false,
      ));
      await hiveService.insertCallLog(TestHiveHelpers.createCallLog(
        phoneNumber: '+2222222222',
        isMissed: false,
      ));

      final stream = hiveService.watchMissedCalls();
      final missed = await stream.first;

      expect(missed.length, equals(1));
      expect(missed[0].phoneNumber, equals('+1111111111'));
    });

    test('watchUpcomingAppointments should emit upcoming appointments', () async {
      final now = DateTime.now();

      await hiveService.insertAppointment(TestHiveHelpers.createAppointment(
        startTime: now.add(const Duration(hours: 1)),
        status: 'upcoming',
      ));
      await hiveService.insertAppointment(TestHiveHelpers.createAppointment(
        startTime: now.subtract(const Duration(hours: 1)),
        status: 'upcoming',
      ));

      final stream = hiveService.watchUpcomingAppointments();
      final upcoming = await stream.first;

      expect(upcoming.length, equals(1));
    });
  });

  group('HiveService SyncQueueItem CRUD', () {
    test('insertSyncItem should set id and track for later sync', () async {
      final syncItem = SyncQueueItem()
        ..entityType = 'Customer'
        ..recordId = 1
        ..operation = 'insert'
        ..payload = '{}'
        ..createdAt = DateTime.now()
        ..retryCount = 0;

      final key = await hiveService.insertSyncItem(syncItem);

      expect(key, isNotNull);
      expect(syncItem.id, equals(key));
    });

    test('getPendingSyncItems should return items sorted by createdAt', () async {
      final item1 = SyncQueueItem()
        ..entityType = 'Customer'
        ..recordId = 1
        ..operation = 'insert'
        ..payload = '{}'
        ..createdAt = DateTime.now().subtract(const Duration(hours: 1))
        ..retryCount = 0;

      final item2 = SyncQueueItem()
        ..entityType = 'Appointment'
        ..recordId = 2
        ..operation = 'update'
        ..payload = '{}'
        ..createdAt = DateTime.now()
        ..retryCount = 0;

      await hiveService.insertSyncItem(item1);
      await hiveService.insertSyncItem(item2);

      final items = hiveService.getPendingSyncItems();

      expect(items.length, equals(2));
      // Should be sorted ascending by createdAt (oldest first for sync order)
      expect(items[0].entityType, equals('Customer'));
      expect(items[1].entityType, equals('Appointment'));
    });

    test('deleteSyncItem should remove item', () async {
      final syncItem = SyncQueueItem()
        ..entityType = 'Customer'
        ..recordId = 1
        ..operation = 'insert'
        ..payload = '{}'
        ..createdAt = DateTime.now()
        ..retryCount = 0;

      final key = await hiveService.insertSyncItem(syncItem);
      await hiveService.deleteSyncItem(key!);

      final items = hiveService.getPendingSyncItems();
      expect(items.any((i) => i.id == key), isFalse);
    });

    test('clearSyncQueue should remove all items', () async {
      await hiveService.insertSyncItem(SyncQueueItem()
        ..entityType = 'Customer'
        ..recordId = 1
        ..operation = 'insert'
        ..payload = '{}'
        ..createdAt = DateTime.now()
        ..retryCount = 0);
      await hiveService.insertSyncItem(SyncQueueItem()
        ..entityType = 'Appointment'
        ..recordId = 2
        ..operation = 'update'
        ..payload = '{}'
        ..createdAt = DateTime.now()
        ..retryCount = 0);

      await hiveService.clearSyncQueue();

      final items = hiveService.getPendingSyncItems();
      expect(items, isEmpty);
    });
  });
}
