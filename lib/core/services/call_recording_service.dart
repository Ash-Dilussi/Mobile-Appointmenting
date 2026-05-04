import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Recording state
enum RecordingState {
  idle,
  incoming,
  recording,
  stopped,
  error,
}

/// Recording event from native
class RecordingEvent {
  final String event;
  final String? path;
  final int? duration;
  final String? number;
  final String? message;

  RecordingEvent({
    required this.event,
    this.path,
    this.duration,
    this.number,
    this.message,
  });

  factory RecordingEvent.fromMap(Map<dynamic, dynamic> map) {
    return RecordingEvent(
      event: map['event'] as String? ?? 'unknown',
      path: map['path'] as String?,
      duration: map['duration'] as int?,
      number: map['number'] as String?,
      message: map['message'] as String?,
    );
  }
}

/// Call Recording Service
/// Handles starting/stopping call recordings via native platform code.
/// Uses device microphone with privacy notice: "Recorded for customer safety"
class CallRecordingService {
  static const _channel = MethodChannel('com.example.in_call_appointment_handler/recording');
  static const _eventChannel = EventChannel('com.example.in_call_appointment_handler/recording_events');

  StreamSubscription<RecordingEvent>? _eventSubscription;

  // State
  final _stateController = StreamController<RecordingState>.broadcast();
  final _pathController = StreamController<String?>.broadcast();
  final _durationController = StreamController<int>.broadcast();

  RecordingState _currentState = RecordingState.idle;
  String? _currentPath;
  int _currentDuration = 0;

  /// Stream of recording state changes
  Stream<RecordingState> get stateStream => _stateController.stream;
  RecordingState get currentState => _currentState;

  /// Stream of recording file paths
  Stream<String?> get pathStream => _pathController.stream;
  String? get currentPath => _currentPath;

  /// Stream of recording duration in seconds
  Stream<int> get durationStream => _durationController.stream;
  int get currentDuration => _currentDuration;

  /// Initialize the service and listen for native events
  void init() {
    _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final recordingEvent = RecordingEvent.fromMap(event);
          _handleRecordingEvent(recordingEvent);
        }
      },
      onError: (error) {
        debugPrint('Recording event error: $error');
        _updateState(RecordingState.error);
      },
    );
  }

  void _handleRecordingEvent(RecordingEvent event) {
    switch (event.event) {
      case 'incoming':
        _updateState(RecordingState.incoming);
        if (event.number != null) {
          _pathController.add(null);
        }
        break;
      case 'started':
        _updateState(RecordingState.recording);
        if (event.path != null) {
          _currentPath = event.path;
          _pathController.add(event.path);
        }
        _currentDuration = 0;
        _durationController.add(0);
        break;
      case 'stopped':
        _updateState(RecordingState.stopped);
        if (event.duration != null) {
          _currentDuration = event.duration!;
          _durationController.add(event.duration!);
        }
        break;
      case 'error':
        _updateState(RecordingState.error);
        debugPrint('Recording error: ${event.message}');
        break;
    }
  }

  void _updateState(RecordingState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Check if recording permission is granted
  Future<bool> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking recording permission: $e');
      return false;
    }
  }

  /// Request recording permission via permission_handler
  Future<PermissionStatus> requestMicPermission() async {
    return await Permission.microphone.request();
  }

  /// Check microphone permission status
  Future<PermissionStatus> checkMicPermission() async {
    return await Permission.microphone.status;
  }

  /// Check if currently recording
  Future<bool> isRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('isRecording');
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking recording status: $e');
      return false;
    }
  }

  /// Start recording manually
  Future<String?> startRecording() async {
    try {
      final result = await _channel.invokeMethod<String?>('startRecording');
      _currentPath = result;
      return result;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return null;
    }
  }

  /// Stop recording manually
  Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod<String?>('stopRecording');
      return result;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  /// Get current recording path
  Future<String?> getRecordingPath() async {
    try {
      final result = await _channel.invokeMethod<String?>('getRecordingPath');
      return result;
    } catch (e) {
      debugPrint('Error getting recording path: $e');
      return null;
    }
  }

  /// Delete a recording file
  Future<bool> deleteRecording(String path) async {
    try {
      final file = File(path);
      final deleted = await file.delete();
      return deleted.existsSync() == false;
    } catch (e) {
      debugPrint('Error deleting recording: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _stateController.close();
    _pathController.close();
    _durationController.close();
  }
}