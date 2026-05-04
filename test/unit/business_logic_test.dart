import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/core/database/collections/collections.dart';

/// Unit tests for business logic
/// Tests appointment conflict detection and status transitions
void main() {
  group('Appointment Conflict Detection', () {
    test('should detect overlapping appointments on same time slot', () {
      final baseTime = DateTime(2026, 4, 20, 10, 0);

      final appointment1 = _createAppointment(
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 1)),
      );

      final appointment2 = _createAppointment(
        startTime: baseTime.add(const Duration(minutes: 30)),
        endTime: baseTime.add(const Duration(minutes: 90)),
      );

      expect(_doAppointmentsOverlap(appointment1, appointment2), isTrue);
    });

    test('should not detect conflict for adjacent time slots', () {
      final baseTime = DateTime(2026, 4, 20, 10, 0);

      final appointment1 = _createAppointment(
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 1)),
      );

      final appointment2 = _createAppointment(
        startTime: baseTime.add(const Duration(hours: 1)),
        endTime: baseTime.add(const Duration(hours: 2)),
      );

      expect(_doAppointmentsOverlap(appointment1, appointment2), isFalse);
    });

    test('should detect conflict when one appointment contains another', () {
      final baseTime = DateTime(2026, 4, 20, 10, 0);

      final appointment1 = _createAppointment(
        startTime: baseTime,
        endTime: baseTime.add(const Duration(hours: 2)),
      );

      final appointment2 = _createAppointment(
        startTime: baseTime.add(const Duration(minutes: 30)),
        endTime: baseTime.add(const Duration(minutes: 90)),
      );

      expect(_doAppointmentsOverlap(appointment1, appointment2), isTrue);
    });

    test('should detect conflict across midnight boundary', () {
      final day1 = DateTime(2026, 4, 20, 23, 30);
      final day2 = DateTime(2026, 4, 21, 0, 30);

      final appointment1 = _createAppointment(
        startTime: day1,
        endTime: day1.add(const Duration(hours: 2)),
      );

      final appointment2 = _createAppointment(
        startTime: day2,
        endTime: day2.add(const Duration(hours: 1)),
      );

      expect(_doAppointmentsOverlap(appointment1, appointment2), isTrue);
    });
  });

  group('Appointment Status Transitions', () {
    test('upcoming can transition to confirmed', () {
      expect(_isValidStatusTransition('upcoming', 'confirmed'), isTrue);
    });

    test('upcoming can transition to ongoing', () {
      expect(_isValidStatusTransition('upcoming', 'ongoing'), isTrue);
    });

    test('upcoming can transition to cancelled', () {
      expect(_isValidStatusTransition('upcoming', 'cancelled'), isTrue);
    });

    test('upcoming can transition to done', () {
      expect(_isValidStatusTransition('upcoming', 'done'), isTrue);
    });

    test('confirmed can transition to ongoing', () {
      expect(_isValidStatusTransition('confirmed', 'ongoing'), isTrue);
    });

    test('confirmed can transition to cancelled', () {
      expect(_isValidStatusTransition('confirmed', 'cancelled'), isTrue);
    });

    test('ongoing can transition to done', () {
      expect(_isValidStatusTransition('ongoing', 'done'), isTrue);
    });

    test('ongoing can transition to cancelled', () {
      expect(_isValidStatusTransition('ongoing', 'cancelled'), isTrue);
    });

    test('done cannot transition to any status', () {
      expect(_isValidStatusTransition('done', 'upcoming'), isFalse);
      expect(_isValidStatusTransition('done', 'confirmed'), isFalse);
      expect(_isValidStatusTransition('done', 'ongoing'), isFalse);
      expect(_isValidStatusTransition('done', 'cancelled'), isFalse);
    });

    test('cancelled cannot transition to any status', () {
      expect(_isValidStatusTransition('cancelled', 'upcoming'), isFalse);
      expect(_isValidStatusTransition('cancelled', 'confirmed'), isFalse);
      expect(_isValidStatusTransition('cancelled', 'ongoing'), isFalse);
      expect(_isValidStatusTransition('cancelled', 'done'), isFalse);
    });
  });

  group('Service Duration Calculation', () {
    test('should calculate end time based on service default duration', () {
      final service = _createService(defaultDurationMinutes: 60);
      final startTime = DateTime(2026, 4, 20, 10, 0);

      final endTime = _calculateEndTime(startTime, service);

      expect(endTime, equals(startTime.add(const Duration(minutes: 60))));
    });

    test('should handle custom duration', () {
      final service = _createService(defaultDurationMinutes: 45);
      final startTime = DateTime(2026, 4, 20, 10, 0);

      final endTime = _calculateEndTime(startTime, service);

      expect(endTime, equals(startTime.add(const Duration(minutes: 45))));
    });
  });

  group('CallLog Classification', () {
    test('should classify incoming call with duration > 0 as answered', () {
      final callLog = _createCallLog(
        direction: 'incoming',
        durationSeconds: 120,
        isMissed: false,
      );

      expect(_isCallAnswered(callLog), isTrue);
    });

    test('should classify incoming call with duration = 0 as missed', () {
      final callLog = _createCallLog(
        direction: 'incoming',
        durationSeconds: 0,
        isMissed: true,
      );

      expect(_isCallMissed(callLog), isTrue);
    });

    test('should classify outgoing call as not missed', () {
      final callLog = _createCallLog(
        direction: 'outgoing',
        durationSeconds: 60,
        isMissed: false,
      );

      expect(_isCallMissed(callLog), isFalse);
    });
  });
}

// Helper functions that implement business logic

Appointment _createAppointment({
  DateTime? startTime,
  DateTime? endTime,
  String status = 'upcoming',
}) {
  final start = startTime ?? DateTime.now();
  return Appointment()
    ..startTime = start
    ..endTime = endTime ?? start.add(const Duration(hours: 1))
    ..status = status
    ..createdAt = DateTime.now()
    ..updatedAt = DateTime.now()
    ..synced = false;
}

Service _createService({int defaultDurationMinutes = 60}) {
  return Service()
    ..title = 'Test Service'
    ..defaultDurationMinutes = defaultDurationMinutes
    ..cost = 50.0
    ..createdAt = DateTime.now()
    ..updatedAt = DateTime.now()
    ..synced = false;
}

CallLog _createCallLog({
  String direction = 'incoming',
  int durationSeconds = 0,
  bool isMissed = false,
}) {
  return CallLog()
    ..phoneNumber = '+1234567890'
    ..timestamp = DateTime.now()
    ..direction = direction
    ..durationSeconds = durationSeconds
    ..isMissed = isMissed
    ..followedUp = false
    ..createdAt = DateTime.now()
    ..synced = false;
}

/// Check if two appointments overlap in time
bool _doAppointmentsOverlap(Appointment a, Appointment b) {
  return a.startTime.isBefore(b.endTime) && a.endTime.isAfter(b.startTime);
}

/// Validate status transitions based on appointment lifecycle
bool _isValidStatusTransition(String from, String to) {
  const validTransitions = {
    'upcoming': ['confirmed', 'ongoing', 'done', 'cancelled'],
    'confirmed': ['ongoing', 'cancelled'],
    'ongoing': ['done', 'cancelled'],
    'done': <String>[], // Terminal state
    'cancelled': <String>[], // Terminal state
  };

  return validTransitions[from]?.contains(to) ?? false;
}

/// Calculate end time based on service duration
DateTime _calculateEndTime(DateTime startTime, Service service) {
  return startTime.add(Duration(minutes: service.defaultDurationMinutes));
}

/// Check if call was answered (had duration > 0)
bool _isCallAnswered(CallLog callLog) {
  return callLog.direction == 'incoming' && callLog.durationSeconds > 0;
}

/// Check if call was missed
bool _isCallMissed(CallLog callLog) {
  return callLog.isMissed && !callLog.followedUp;
}
