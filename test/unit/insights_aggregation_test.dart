import 'dart:io';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/database/insights_data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late HiveService service;
  late Directory tempDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDirectory = await Directory.systemTemp.createTemp('insights_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tempDirectory.path,
    );
    await Hive.initFlutter(tempDirectory.path);
    service = HiveService();
    await service.init();
  });

  setUp(() => service.clearAllData());

  tearDownAll(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  InsightsQuery query() => InsightsQuery(
        institutionId: 'business-a',
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 10, 1),
        grouping: InsightsGrouping.weekly,
      );

  Appointment appointment({
    required String? institutionId,
    required String status,
    required DateTime start,
    int? customerId,
    int? serviceId,
  }) {
    return Appointment()
      ..institutionId = institutionId
      ..handledByUserId = 'owner-a'
      ..customerId = customerId
      ..serviceId = serviceId
      ..startTime = start
      ..endTime = start.add(const Duration(hours: 1))
      ..status = status
      ..createdAt = start
      ..updatedAt = start
      ..synced = false;
  }

  test('zero activity returns real zero metrics', () {
    final result = service.getAppointmentInsights(query());

    expect(result.booked.value, 0);
    expect(result.completed.value, 0);
    expect(result.cancelled.value, 0);
    expect(result.noShow.value, 0);
  });

  test('appointment aggregation is tenant scoped and supports no-show',
      () async {
    await service.insertAppointment(appointment(
      institutionId: 'business-a',
      status: Appointment.statusDone,
      start: DateTime(2026, 9, 4),
    ));
    await service.insertAppointment(appointment(
      institutionId: 'business-a',
      status: Appointment.statusNoShow,
      start: DateTime(2026, 9, 5),
    ));
    await service.insertAppointment(appointment(
      institutionId: 'business-b',
      status: Appointment.statusCancelled,
      start: DateTime(2026, 9, 6),
    ));
    await service.insertAppointment(appointment(
      institutionId: null,
      status: Appointment.statusDone,
      start: DateTime(2026, 9, 7),
    ));

    final result = service.getAppointmentInsights(query());

    expect(result.booked.value, 2);
    expect(result.completed.value, 1);
    expect(result.cancelled.value, 0);
    expect(result.noShow.value, 1);
  });

  test('hot services and booked value use scoped line items', () async {
    final hair = Service()
      ..institutionId = 'business-a'
      ..title = 'Haircut'
      ..defaultDurationMinutes = 30
      ..cost = 40
      ..createdAt = DateTime(2026, 8, 1)
      ..updatedAt = DateTime(2026, 8, 1)
      ..synced = false;
    final hairId = await service.insertService(hair);
    final booking = appointment(
      institutionId: 'business-a',
      status: Appointment.statusDone,
      start: DateTime(2026, 9, 10),
      serviceId: hairId,
    );
    final appointmentId = await service.insertAppointment(booking);
    await service.insertAppointmentService(
      AppointmentService()
        ..institutionId = 'business-a'
        ..appointmentId = appointmentId
        ..serviceId = hairId
        ..priceOverride = 50,
    );

    final hotServices = service.getHotServiceInsights(query());
    final bookedValue = service.getBookedValueInsights(query());

    expect(hotServices.single.label, 'Haircut');
    expect(hotServices.single.value, 1);
    expect(bookedValue.total.value, 50);
    expect(bookedValue.averagePerAppointment.value, 50);
  });

  test('customer insights distinguish new and returning customers', () async {
    final returning = Customer()
      ..institutionId = 'business-a'
      ..name = 'Returning'
      ..phoneNumber = '200'
      ..synced = false;
    final returningId = await service.insertCustomer(returning);
    returning.createdAt = DateTime(2026, 7, 1);
    await service.updateCustomer(returningId!, returning);

    final newcomer = Customer()
      ..institutionId = 'business-a'
      ..name = 'New'
      ..phoneNumber = '201'
      ..synced = false;
    final newcomerId = await service.insertCustomer(newcomer);
    newcomer.createdAt = DateTime(2026, 9, 3);
    await service.updateCustomer(newcomerId!, newcomer);

    await service.insertAppointment(appointment(
      institutionId: 'business-a',
      status: Appointment.statusDone,
      start: DateTime(2026, 8, 15),
      customerId: returningId,
    ));
    await service.insertAppointment(appointment(
      institutionId: 'business-a',
      status: Appointment.statusUpcoming,
      start: DateTime(2026, 9, 15),
      customerId: returningId,
    ));

    final result = service.getCustomerInsights(query());

    expect(result.newCustomers.value, 1);
    expect(result.returningCustomers.value, 1);
    expect(result.repeatVisitRate, 50);
  });

  test('call and staff insights use explicit links and handlers', () async {
    await service.insertUser(User()
      ..id = 'owner-a'
      ..institutionId = 'business-a'
      ..email = 'owner@example.com'
      ..name = 'Owner A'
      ..role = 'owner');
    final convertedCall = CallLog()
      ..institutionId = 'business-a'
      ..handledByUserId = 'owner-a'
      ..phoneNumber = '300'
      ..timestamp = DateTime(2026, 9, 12)
      ..direction = 'incoming'
      ..durationSeconds = 120
      ..linkedAppointmentId = 99
      ..isMissed = false
      ..followedUp = true;
    final missedCall = CallLog()
      ..institutionId = 'business-a'
      ..handledByUserId = 'owner-a'
      ..phoneNumber = '301'
      ..timestamp = DateTime(2026, 9, 13)
      ..direction = 'missed'
      ..durationSeconds = 0
      ..isMissed = true
      ..followedUp = false;
    await service.insertCallLog(convertedCall);
    await service.insertCallLog(missedCall);
    await service.insertCallLog(CallLog()
      ..institutionId = 'business-b'
      ..handledByUserId = 'owner-a'
      ..phoneNumber = '302'
      ..timestamp = DateTime(2026, 9, 14)
      ..direction = 'incoming'
      ..durationSeconds = 600
      ..isMissed = false
      ..followedUp = false);
    await service.insertAppointment(appointment(
      institutionId: 'business-a',
      status: Appointment.statusDone,
      start: DateTime(2026, 9, 14),
    ));

    final calls = service.getCallInsights(query());
    final staff = service.getStaffInsights(query());

    expect(calls.total.value, 2);
    expect(calls.answered.value, 1);
    expect(calls.missed.value, 1);
    expect(calls.averageDurationSeconds.value, 120);
    expect(calls.converted.value, 1);
    expect(calls.conversionRate, 50);
    expect(staff.people.single.value, 1);
  });

  test('legacy records are counted for the visible exclusion notice', () async {
    final customer = Customer()
      ..institutionId = null
      ..name = 'Legacy'
      ..phoneNumber = '100'
      ..createdAt = DateTime(2025)
      ..updatedAt = DateTime(2025)
      ..synced = false;
    await service.insertCustomer(customer);
    await service.insertAppointment(appointment(
      institutionId: null,
      status: Appointment.statusUpcoming,
      start: DateTime(2026, 9, 9),
    ));

    expect(service.getLegacyExclusionInsights().recordCount, 2);
  });
}
