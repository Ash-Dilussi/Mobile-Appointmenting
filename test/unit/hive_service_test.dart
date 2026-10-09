import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/features/call_log/data/models/call_log_entry.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../helpers/test_helpers.dart';

Future<Box<Service>> _openServiceBoxSnapshot() async {
  final sourceBox = Hive.box<Service>(HiveService.servicesBox);
  await sourceBox.flush();

  final sourcePath = sourceBox.path;
  if (sourcePath == null) {
    throw StateError('Service box does not have a disk path');
  }

  final snapshotName =
      'services_snapshot_${DateTime.now().microsecondsSinceEpoch}';
  final sourceFile = File(sourcePath);
  final snapshotPath =
      '${sourceFile.parent.path}${Platform.pathSeparator}$snapshotName.hive';
  await sourceFile.copy(snapshotPath);
  return Hive.openBox<Service>(snapshotName);
}

Future<Box<ServiceStation>> _openServiceStationBoxSnapshot() async {
  final sourceBox = Hive.box<ServiceStation>(HiveService.serviceStationsBox);
  await sourceBox.flush();

  final sourcePath = sourceBox.path;
  if (sourcePath == null) {
    throw StateError('Service-station box does not have a disk path');
  }

  final snapshotName =
      'service_stations_snapshot_${DateTime.now().microsecondsSinceEpoch}';
  final sourceFile = File(sourcePath);
  final snapshotPath =
      '${sourceFile.parent.path}${Platform.pathSeparator}$snapshotName.hive';
  await sourceFile.copy(snapshotPath);
  return Hive.openBox<ServiceStation>(snapshotName);
}

Future<Box<Appointment>> _openAppointmentBoxSnapshot() async {
  final sourceBox = Hive.box<Appointment>(HiveService.appointmentsBox);
  await sourceBox.flush();

  final sourcePath = sourceBox.path;
  if (sourcePath == null) {
    throw StateError('Appointment box does not have a disk path');
  }

  final snapshotName =
      'appointments_snapshot_${DateTime.now().microsecondsSinceEpoch}';
  final sourceFile = File(sourcePath);
  final snapshotPath =
      '${sourceFile.parent.path}${Platform.pathSeparator}$snapshotName.hive';
  await sourceFile.copy(snapshotPath);
  return Hive.openBox<Appointment>(snapshotName);
}

Future<Box<Customer>> _openCustomerBoxSnapshot() async {
  final sourceBox = Hive.box<Customer>(HiveService.customersBox);
  await sourceBox.flush();
  final sourcePath = sourceBox.path;
  if (sourcePath == null) {
    throw StateError('Customer box does not have a disk path');
  }
  final snapshotName =
      'customers_snapshot_${DateTime.now().microsecondsSinceEpoch}';
  final sourceFile = File(sourcePath);
  final snapshotPath =
      '${sourceFile.parent.path}${Platform.pathSeparator}$snapshotName.hive';
  await sourceFile.copy(snapshotPath);
  return Hive.openBox<Customer>(snapshotName);
}

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
    test('insertAppInitiatedCallLog stores customer and staff attribution',
        () async {
      final customer = TestHiveHelpers.createCustomer(
        phoneNumber: '0712345678',
        institutionId: 'test-inst',
      );
      final customerId = await hiveService.insertCustomer(customer);

      final callLogId = await hiveService.insertAppInitiatedCallLog(
        customerId: customerId!,
        phoneNumber: '0712345678',
        institutionId: 'test-inst',
        handledByUserId: 'test-user',
        timestamp: DateTime(2026, 9, 23, 10, 15),
      );

      final callLog = hiveService.getCallLogById(callLogId!);
      expect(callLog, isNotNull);
      expect(callLog!.customerId, customerId);
      expect(callLog.handledByUserId, 'test-user');
      expect(callLog.institutionId, 'test-inst');
      expect(callLog.origin, CallLog.originAppInitiated);
      expect(callLog.direction, 'outgoing');
      expect(callLog.durationSeconds, 0);
      expect(callLog.isMissed, isFalse);
    });

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

    test(
        'getAllCallLogs should return all inserted call logs sorted by timestamp',
        () async {
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

    test('getMissedCalls should return only missed and not followed up calls',
        () async {
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

    test('structured notes persist across a cold box reload', () async {
      final createdAt = DateTime(2026, 9, 6, 9, 30);
      final updatedAt = DateTime(2026, 9, 6, 10, 15);
      final appointment = TestHiveHelpers.createAppointment(
        notes: [
          AppointmentNote(
            id: 'note-1',
            title: 'Preparation',
            description: 'Arrive ten minutes early',
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          AppointmentNote(
            id: 'note-2',
            title: 'Accessibility',
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        ],
      );

      final key = await hiveService.insertAppointment(appointment);
      final snapshot = await _openAppointmentBoxSnapshot();

      try {
        final restored = snapshot.get(key);
        expect(restored, isNotNull);
        expect(restored!.id, key);
        expect(restored.notes, hasLength(2));
        expect(restored.notes.first.id, 'note-1');
        expect(restored.notes.first.title, 'Preparation');
        expect(
          restored.notes.first.description,
          'Arrive ten minutes early',
        );
        expect(restored.notes.first.createdAt, createdAt);
        expect(restored.notes.first.updatedAt, updatedAt);
        expect(restored.notes.last.title, 'Accessibility');
        expect(restored.notes.last.description, isNull);
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('backfill restores and persists historical missing appointment ids',
        () async {
      final box = Hive.box<Appointment>(HiveService.appointmentsBox);
      final appointment = TestHiveHelpers.createAppointment()..id = null;
      final key = await box.add(appointment);
      await box.flush();

      expect(box.get(key)?.id, isNull);

      await hiveService.backfillAppointmentIds();
      await hiveService.backfillAppointmentIds();

      expect(box.get(key)?.id, key);

      final snapshot = await _openAppointmentBoxSnapshot();
      try {
        expect(snapshot.get(key)?.id, key);
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('legacy free text is retained without automatic conversion', () async {
      final appointment = TestHiveHelpers.createAppointment()
        ..legacyNotes = 'Historical note without a user-authored title';

      final key = await hiveService.insertAppointment(appointment);
      final snapshot = await _openAppointmentBoxSnapshot();

      try {
        final restored = snapshot.get(key);
        expect(restored, isNotNull);
        expect(
          restored!.legacyNotes,
          'Historical note without a user-authored title',
        );
        expect(restored.notes, isEmpty);
      } finally {
        await snapshot.deleteFromDisk();
      }
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

    test(
        'getUpcomingAppointments should return future appointments with upcoming status',
        () async {
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
    test('clearAllData clears subscription and alternate call-log stores',
        () async {
      await hiveService.subscriptionBox.put('sub_test-inst', 'pro');
      final alternateCallLogBox = Hive.box<CallLogEntry>(CallLogBox.boxName);
      final entry = CallLogEntry.create(
        id: 'native-call-1',
        phoneNumber: '+94710000000',
        callType: 'outgoing',
        startTime: DateTime(2026, 9, 23),
        durationSeconds: 30,
        state: 'completed',
      );
      await alternateCallLogBox.put(entry.id, entry);

      await hiveService.clearAllData();

      expect(hiveService.subscriptionBox, isEmpty);
      expect(alternateCallLogBox, isEmpty);
    });

    test('insertCustomer should insert and set id', () async {
      final customer = TestHiveHelpers.createCustomer(
        name: 'John Doe',
        phoneNumber: '+1234567890',
      );

      final key = await hiveService.insertCustomer(customer);

      expect(key, isNotNull);
      expect(customer.id, equals(key));
    });

    test('insertCustomer persists id across a cold box reload', () async {
      final customer = TestHiveHelpers.createCustomer(name: 'Restart-safe');

      final key = await hiveService.insertCustomer(customer);
      final snapshot = await _openCustomerBoxSnapshot();
      try {
        expect(snapshot.get(key)?.id, equals(key));
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('backfillCustomerIds repairs only customers with missing ids',
        () async {
      final box = Hive.box<Customer>(HiveService.customersBox);
      final missingIdCustomer =
          TestHiveHelpers.createCustomer(name: 'Missing id')..id = null;
      final validCustomer = TestHiveHelpers.createCustomer(name: 'Valid id')
        ..id = 999;
      final missingIdKey = await box.add(missingIdCustomer);
      final validKey = await box.add(validCustomer);

      await hiveService.backfillCustomerIds();
      await hiveService.backfillCustomerIds();

      expect(box.get(missingIdKey)?.id, equals(missingIdKey));
      expect(box.get(validKey)?.id, equals(999));

      final snapshot = await _openCustomerBoxSnapshot();
      try {
        expect(snapshot.get(missingIdKey)?.id, equals(missingIdKey));
        expect(snapshot.get(validKey)?.id, equals(999));
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('dob and structured notes persist across a cold box reload', () async {
      final createdAt = DateTime(2026, 9, 6, 9, 30);
      final customer = TestHiveHelpers.createCustomer(
        notes: [
          CustomerNote(
            id: 'customer-note-1',
            title: 'Communication preference',
            description: 'Text before calling',
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        ],
      )
        ..dob = DateTime(1992, 2, 29)
        ..legacyNotes = 'Historical note';

      final key = await hiveService.insertCustomer(customer);
      final snapshot = await _openCustomerBoxSnapshot();
      try {
        final restored = snapshot.get(key);
        expect(restored, isNotNull);
        expect(restored!.dob, DateTime(1992, 2, 29));
        expect(restored.legacyNotes, 'Historical note');
        expect(restored.notes, hasLength(1));
        expect(restored.notes.single.title, 'Communication preference');
        expect(restored.notes.single.description, 'Text before calling');
      } finally {
        await snapshot.deleteFromDisk();
      }
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

    test('getCustomerByPhone matches Sri Lankan formatting variants', () async {
      final customer = TestHiveHelpers.createCustomer(
        name: 'Nimali',
        phoneNumber: '+94 71 234 5678',
      );
      await hiveService.insertCustomer(customer);

      expect(hiveService.getCustomerByPhone('071 234 5678')?.name, 'Nimali');
      expect(hiveService.getCustomerByPhone('(071) 234-5678')?.name, 'Nimali');
    });

    test('getCustomerByPhone should return null for non-existent phone',
        () async {
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

    test('insertService should persist id across a cold box reload', () async {
      const colorValue = 0xFF1565C0;
      final service = TestHiveHelpers.createService(
        title: 'Restart-safe',
        colorValue: colorValue,
      );

      final key = await hiveService.insertService(service);
      final snapshot = await _openServiceBoxSnapshot();

      try {
        expect(snapshot.get(key)?.id, equals(key));
        expect(snapshot.get(key)?.colorValue, equals(colorValue));
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('backfillServiceIds repairs only services with missing ids', () async {
      final box = Hive.box<Service>(HiveService.servicesBox);
      final missingIdService =
          TestHiveHelpers.createService(title: 'Missing id')..id = null;
      final validService = TestHiveHelpers.createService(title: 'Valid id')
        ..id = 999;
      final missingIdKey = await box.add(missingIdService);
      final validKey = await box.add(validService);

      await hiveService.backfillServiceIds();
      await hiveService.backfillServiceIds();

      expect(box.get(missingIdKey)?.id, equals(missingIdKey));
      expect(box.get(validKey)?.id, equals(999));

      final snapshot = await _openServiceBoxSnapshot();
      try {
        expect(snapshot.get(missingIdKey)?.id, equals(missingIdKey));
        expect(snapshot.get(validKey)?.id, equals(999));
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('watchAllServices repairs ids before its initial emission', () async {
      final box = Hive.box<Service>(HiveService.servicesBox);
      final key = await box.add(
        TestHiveHelpers.createService(title: 'Legacy route target')..id = null,
      );

      final initialServices = await hiveService.watchAllServices().first;

      expect(initialServices.single.id, equals(key));
    });

    test('getAllServices should return all services', () async {
      await hiveService
          .insertService(TestHiveHelpers.createService(title: 'Service A'));
      await hiveService
          .insertService(TestHiveHelpers.createService(title: 'Service B'));

      final all = hiveService.getAllServices();

      expect(all.length, equals(2));
    });

    test('getServiceById should return service by id', () async {
      const colorValue = 0xFF1565C0;
      final service = TestHiveHelpers.createService(
        title: 'Haircut',
        colorValue: colorValue,
      );

      final key = await hiveService.insertService(service);
      final found = hiveService.getServiceById(key!);

      expect(found?.title, equals('Haircut'));
      expect(found?.colorValue, equals(colorValue));
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

  group('HiveService Service Station CRUD', () {
    ServiceStation station({String name = 'Main Room'}) => ServiceStation()
      ..name = name
      ..createdAt = DateTime(2026, 9, 15)
      ..updatedAt = DateTime(2026, 9, 15)
      ..synced = false;

    test('insertServiceStation persists id across a cold box reload', () async {
      final serviceStation = station();

      final key = await hiveService.insertServiceStation(serviceStation);
      final snapshot = await _openServiceStationBoxSnapshot();

      try {
        expect(snapshot.get(key)?.id, equals(key));
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('backfillServiceStationIds repairs historical missing ids', () async {
      final box = Hive.box<ServiceStation>(HiveService.serviceStationsBox);
      final missingIdKey =
          await box.add(station(name: 'Legacy Room')..id = null);

      await hiveService.backfillServiceStationIds();
      await hiveService.backfillServiceStationIds();

      expect(box.get(missingIdKey)?.id, equals(missingIdKey));
      final snapshot = await _openServiceStationBoxSnapshot();
      try {
        expect(snapshot.get(missingIdKey)?.id, equals(missingIdKey));
      } finally {
        await snapshot.deleteFromDisk();
      }
    });

    test('watchAllServiceStations repairs ids before Booking receives them',
        () async {
      final box = Hive.box<ServiceStation>(HiveService.serviceStationsBox);
      final key =
          await box.add(station(name: 'Legacy Booking Room')..id = null);

      final initialStations = await hiveService.watchAllServiceStations().first;

      expect(initialStations.single.id, equals(key));
    });
  });

  group('HiveService Stream Methods', () {
    test('watchAllCallLogs should emit initial data immediately', () async {
      // Insert some data first
      await hiveService.insertCallLog(
          TestHiveHelpers.createCallLog(phoneNumber: '+1111111111'));
      await hiveService.insertCallLog(
          TestHiveHelpers.createCallLog(phoneNumber: '+2222222222'));

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

    test('watchUpcomingAppointments should emit upcoming appointments',
        () async {
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

    test('getPendingSyncItems should return items sorted by createdAt',
        () async {
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
      await hiveService.deleteSyncItem(key);

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

  group('HiveService Customer-CallLog Linking', () {
    test('getCustomerByPhone should match normalized phone numbers', () async {
      // Customer stored with formatted phone
      final customer = TestHiveHelpers.createCustomer(
        name: 'John Doe',
        phoneNumber: '+1 (555) 123-4567',
      );
      await hiveService.insertCustomer(customer);

      // Search with different format - should still match
      final found1 = hiveService.getCustomerByPhone('5551234567');
      expect(found1, isNotNull);
      expect(found1?.name, equals('John Doe'));

      // Search with yet another format
      final found2 = hiveService.getCustomerByPhone('+15551234567');
      expect(found2, isNotNull);
      expect(found2?.name, equals('John Doe'));
    });

    test('insertCustomer should auto-link call logs with matching phone',
        () async {
      // Insert call log first (before customer exists)
      final callLog = TestHiveHelpers.createCallLog(
        phoneNumber: '5551112222',
        direction: 'incoming',
      );
      await hiveService.insertCallLog(callLog);

      // Verify call log has no customer link yet
      final unlinkedLog = hiveService.getCallLogById(callLog.id!);
      expect(unlinkedLog?.customerId, isNull);

      // Now insert customer with matching phone
      final customer = TestHiveHelpers.createCustomer(
        name: 'Jane Doe',
        phoneNumber: '5551112222',
      );
      await hiveService.insertCustomer(customer);

      // Verify call log is now linked
      final linkedLog = hiveService.getCallLogById(callLog.id!);
      expect(linkedLog?.customerId, equals(customer.id));
    });

    test('insertCallLog should auto-link to existing customer', () async {
      // Insert customer first
      final customer = TestHiveHelpers.createCustomer(
        name: 'Bob Smith',
        phoneNumber: '5553334444',
      );
      await hiveService.insertCustomer(customer);

      // Insert call log with matching phone
      final callLog = TestHiveHelpers.createCallLog(
        phoneNumber: '5553334444',
        direction: 'outgoing',
      );
      await hiveService.insertCallLog(callLog);

      // Verify call log is linked to customer
      final linkedLog = hiveService.getCallLogById(callLog.id!);
      expect(linkedLog?.customerId, equals(customer.id));
    });

    test('linkCallLogsToCustomer should link all matching unlinked logs',
        () async {
      // Create customer
      final customer = TestHiveHelpers.createCustomer(
        name: 'Alice',
        phoneNumber: '5556667777',
      );
      await hiveService.insertCustomer(customer);

      // Insert multiple call logs (some before customer exists)
      final log1 = TestHiveHelpers.createCallLog(phoneNumber: '5556667777');
      final log2 = TestHiveHelpers.createCallLog(phoneNumber: '5556667777');
      final log3 = TestHiveHelpers.createCallLog(phoneNumber: '5556667777');
      await hiveService.insertCallLog(log1);
      await hiveService.insertCallLog(log2);
      await hiveService.insertCallLog(log3);

      // Manually call linkCallLogsToCustomer
      await hiveService.linkCallLogsToCustomer(customer);

      // All logs should be linked
      final linkedLog1 = hiveService.getCallLogById(log1.id!);
      final linkedLog2 = hiveService.getCallLogById(log2.id!);
      final linkedLog3 = hiveService.getCallLogById(log3.id!);
      expect(linkedLog1?.customerId, equals(customer.id));
      expect(linkedLog2?.customerId, equals(customer.id));
      expect(linkedLog3?.customerId, equals(customer.id));
    });

    test('backfillCallLogCustomerLinks should link all unlinked logs',
        () async {
      // Insert call logs first (no customers exist)
      final log1 = TestHiveHelpers.createCallLog(phoneNumber: '5558889999');
      final log2 = TestHiveHelpers.createCallLog(phoneNumber: '5558889999');
      await hiveService.insertCallLog(log1);
      await hiveService.insertCallLog(log2);

      // Now create customer
      final customer = TestHiveHelpers.createCustomer(
        name: 'Charlie',
        phoneNumber: '5558889999',
      );
      await hiveService.insertCustomer(customer);

      // Call backfill
      await hiveService.backfillCallLogCustomerLinks();

      // All logs should be linked
      final linkedLog1 = hiveService.getCallLogById(log1.id!);
      final linkedLog2 = hiveService.getCallLogById(log2.id!);
      expect(linkedLog1?.customerId, equals(customer.id));
      expect(linkedLog2?.customerId, equals(customer.id));
    });

    test('linkCallLogsToCustomer should not re-link already linked logs',
        () async {
      // Create first customer
      final customer1 = TestHiveHelpers.createCustomer(
        name: 'First',
        phoneNumber: '5550001111',
      );
      await hiveService.insertCustomer(customer1);

      // Insert and link a call log
      final callLog = TestHiveHelpers.createCallLog(phoneNumber: '5550001111');
      await hiveService.insertCallLog(callLog);

      // Verify linked
      final linkedLog = hiveService.getCallLogById(callLog.id!);
      expect(linkedLog?.customerId, equals(customer1.id));

      // Create second customer with same phone (edge case)
      final customer2 = TestHiveHelpers.createCustomer(
        name: 'Second',
        phoneNumber: '5550001111',
      );
      await hiveService.insertCustomer(customer2);

      // Link second customer - should not change already linked log
      await hiveService.linkCallLogsToCustomer(customer2);

      // Log should still be linked to first customer
      final stillLinkedLog = hiveService.getCallLogById(callLog.id!);
      expect(stillLinkedLog?.customerId, equals(customer1.id));
    });
  });
}
