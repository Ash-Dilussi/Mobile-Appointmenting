import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/call_log_entry.dart';
import '../data/repositories/call_log_repository.dart';
import '../domain/contact_suite_data.dart';
import '../../../core/database/collections/call_log.dart';
import '../../../core/database/hive_service.dart';
import '../../auth/presentation/providers/auth_session_provider.dart';
import '../../home/presentation/providers/home_provider.dart';

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
  (ref) => ActiveCallNotifier(
    ref.watch(homeHiveProvider),
    ref.watch(authSessionProvider),
  ),
);

// Contact Suite Provider - loads customer + appointments for a given customerId
final contactSuiteProvider = FutureProvider.family<ContactSuiteData?, int?>(
  (ref, customerId) async {
    if (customerId == null) return null;

    final db = ref.watch(homeHiveProvider);
    final institutionId = ref.watch(authSessionProvider)?.institutionId;
    if (institutionId == null || institutionId.isEmpty) return null;
    final customer = db.getCustomerById(customerId);
    if (customer == null || customer.institutionId != institutionId) {
      return null;
    }

    // Load all appointments for this customer
    final allAppointments = db
        .getAppointmentsForCustomer(customerId)
        .where((appointment) => appointment.institutionId == institutionId)
        .toList();

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
  final HiveService _hiveService;
  final AuthSession? _session;
  StreamSubscription? _eventSubscription;

  ActiveCallNotifier(this._hiveService, this._session)
      : super(ActiveCallState.none) {
    _initEventChannel();
  }

  void _initEventChannel() {
    const eventChannel = EventChannel('com.ashDilussi.bookly/call_events');

    _eventSubscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;

          if (type == 'ringing') {
            state = ActiveCallState.ringing;
          } else if (type == 'offhook') {
            state = ActiveCallState.ongoing;
          } else if (type == 'idle') {
            state = ActiveCallState.none;
          } else if (type == 'completed_call') {
            unawaited(_saveCompletedCall(event));
          }
        }
      },
      onError: (error) {
        // Handle error silently - phone events may not be available in all contexts
      },
    );
  }

  Future<void> _saveCompletedCall(Map<dynamic, dynamic> event) async {
    final institutionId = _session?.institutionId;
    final userId = _session?.userId;
    final timestampMillis = event['timestampMillis'];
    final durationSeconds = event['durationSeconds'];
    final phoneNumber = event['number'] as String? ?? '';

    // Never create ambiguous, unscoped analytics data. A completed call can be
    // captured only after the authenticated institution context is available.
    if (institutionId == null ||
        institutionId.isEmpty ||
        userId == null ||
        timestampMillis is! num ||
        durationSeconds is! num) {
      return;
    }

    final isMissed = event['isMissed'] == true;
    final direction =
        event['direction'] as String? ?? (isMissed ? 'missed' : 'incoming');
    final safeDuration = durationSeconds.toInt();
    final callLog = CallLog()
      ..phoneNumber = phoneNumber
      ..timestamp = DateTime.fromMillisecondsSinceEpoch(
        timestampMillis.toInt(),
      )
      ..direction = direction
      ..durationSeconds = safeDuration < 0 ? 0 : safeDuration
      ..isMissed = isMissed
      ..followedUp = false
      ..institutionId = institutionId
      ..handledByUserId = userId;

    await _hiveService.insertCallLog(callLog);
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
