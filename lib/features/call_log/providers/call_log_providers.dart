import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/call_log_entry.dart';
import '../data/repositories/call_log_repository.dart';
import '../domain/contact_suite_data.dart';
import '../../home/presentation/providers/home_provider.dart';
import '../../../core/database/collections/appointment.dart';
import '../../../core/database/collections/customer.dart';

// Repository provider
final callLogRepositoryProvider = Provider<CallLogRepository>((ref) {
  return CallLogRepository();
});

// Reactive list — rebuilds when Hive box changes
final callLogEntriesProvider = StreamProvider<List<CallLogEntry>>((ref) {
  final repo = ref.watch(callLogRepositoryProvider);
  return repo
      .watchAllEntries(); // Hive box.watch() stream, ordered by startTime desc
});

// Active call state — drives the persistent call banner in the app shell
enum ActiveCallState { none, ringing, ongoing }

final activeCallStateProvider =
    StateNotifierProvider<ActiveCallNotifier, ActiveCallState>(
  (ref) => ActiveCallNotifier(ref.watch(callLogRepositoryProvider)),
);

// Contact Suite Provider - loads customer + appointments for a given customerId
final contactSuiteProvider = FutureProvider.family<ContactSuiteData?, int?>(
  (ref, customerId) async {
    if (customerId == null) return null;

    final db = ref.watch(homeHiveProvider);
    final customer = db.getCustomerById(customerId);
    if (customer == null) return null;

    // Load all appointments for this customer
    final allAppointments = db.getAppointmentsForCustomer(customerId);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Separate upcoming and past appointments
    final upcoming = allAppointments
        .where((a) =>
            a.startTime.isAfter(today) ||
            (a.startTime.year == today.year &&
                a.startTime.month == today.month &&
                a.startTime.day == today.day))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime)); // soonest first

    final past = allAppointments
        .where((a) => a.startTime.isBefore(today))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime)); // most recent first

    return ContactSuiteData(
      customer: customer,
      upcomingAppointments: upcoming,
      pastAppointments: past,
    );
  },
);

class ActiveCallNotifier extends StateNotifier<ActiveCallState> {
  final CallLogRepository _repository;
  StreamSubscription? _eventSubscription;
  String? _currentEntryId;
  String _lastState = 'idle'; // Track previous state to detect missed calls

  ActiveCallNotifier(this._repository) : super(ActiveCallState.none) {
    _initEventChannel();
  }

  void _initEventChannel() {
    const eventChannel = EventChannel('com.ashDilussi.bookly/call_events');

    _eventSubscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          final number = event['number'] as String? ?? '';

          if (type == 'ringing') {
            _handleRinging(number);
          } else if (type == 'offhook') {
            _handleOffhook();
          } else if (type == 'idle') {
            _handleIdle();
          }
        }
      },
      onError: (error) {
        // Handle error silently - phone events may not be available in all contexts
      },
    );
  }

  Future<void> _handleRinging(String phoneNumber) async {
    state = ActiveCallState.ringing;
    _lastState = 'ringing';

    // Create new CallLogEntry with state = 'ringing'
    final entry = CallLogEntry.create(
      id: '',
      phoneNumber: phoneNumber,
      callType: 'incoming',
      startTime: DateTime.now(),
      state: 'ringing',
    );

    await _repository.saveEntry(entry);

    // Get the entry id after save (the entry gets a UUID before save)
    final allEntries = _repository.getAllEntries();
    if (allEntries.isNotEmpty) {
      _currentEntryId = allEntries.first.id;
    }
  }

  Future<void> _handleOffhook() async {
    state = ActiveCallState.ongoing;
    _lastState = 'offhook';

    if (_currentEntryId != null) {
      await _repository.updateEntry(_currentEntryId!, state: 'ongoing');
    }
  }

  Future<void> _handleIdle() async {
    state = ActiveCallState.none;

    if (_currentEntryId != null) {
      final now = DateTime.now();

      // If state was ringing and never went offhook, it's a missed call
      if (_lastState == 'ringing') {
        await _repository.updateEntry(
          _currentEntryId!,
          state: 'missed',
          endTime: now,
          durationSeconds: 0,
        );
      } else {
        // Call was answered and ended
        await _repository.updateEntry(
          _currentEntryId!,
          state: 'completed',
          endTime: now,
        );
      }

      _currentEntryId = null;
    }

    _lastState = 'idle';
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
