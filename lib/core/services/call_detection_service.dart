import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/logger_service.dart';

/// Active call state model
class ActiveCallState {
  final bool isActive;
  final String? phoneNumber;
  final DateTime? startTime;

  const ActiveCallState({
    this.isActive = false,
    this.phoneNumber,
    this.startTime,
  });
}

/// Call detection service for Android native call detection
class CallDetectionService {
  static const _methodChannel = MethodChannel('com.example.in_call_appointment_handler/call_detection');
  static const _eventChannel = EventChannel('com.example.in_call_appointment_handler/call_events');

  Stream<Map<String, dynamic>>? _callEventStream;

  /// Check if call detection permission is granted
  Future<bool> checkPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (e, st) {
      logger.error('CallDetectionService', 'Permission check failed: $e',
          error: e, stackTrace: st);
      return false;
    }
  }

  /// Request call detection permission
  Future<bool> requestPermission() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e, st) {
      logger.error('CallDetectionService', 'Permission request failed: $e',
          error: e, stackTrace: st);
      return false;
    }
  }

  /// Listen to call events from native Android
  Stream<Map<String, dynamic>> watchCallEvents() {
    _callEventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _callEventStream!;
  }
}

/// Call detection provider
final callDetectionServiceProvider = Provider<CallDetectionService>((ref) {
  return CallDetectionService();
});

/// Active call state notifier
class ActiveCallNotifier extends StateNotifier<ActiveCallState> {
  final CallDetectionService _service;

  ActiveCallNotifier(this._service) : super(const ActiveCallState());

  Future<void> initialize() async {
    final hasPermission = await _service.checkPermission();
    if (hasPermission) {
      _service.watchCallEvents().listen(_handleCallEvent);
    }
  }

  void _handleCallEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final number = event['number'] as String? ?? '';

    switch (type) {
      case 'ringing':
        state = ActiveCallState(
          isActive: true,
          phoneNumber: number,
          startTime: DateTime.now(),
        );
        break;
      case 'offhook':
        if (!state.isActive) {
          state = ActiveCallState(
            isActive: true,
            phoneNumber: number,
            startTime: DateTime.now(),
          );
        }
        break;
      case 'idle':
        state = const ActiveCallState();
        break;
    }
  }
}

/// Active call state provider
final activeCallProvider = StateNotifierProvider<ActiveCallNotifier, ActiveCallState>((ref) {
  final service = ref.watch(callDetectionServiceProvider);
  return ActiveCallNotifier(service);
});
