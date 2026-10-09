import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public Android manifest excludes dormant call permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, isNot(contains('android.permission.READ_CALL_LOG')));
    expect(manifest, isNot(contains('android.permission.RECORD_AUDIO')));
    expect(manifest, isNot(contains('android.permission.CALL_PHONE')));
  });

  test('native recording and provider ingestion use the dormant build flag',
      () {
    final source = File(
      'android/app/src/main/kotlin/com/example/in_call_appointment_handler/MainActivity.kt',
    ).readAsStringSync();

    expect(
      RegExp(
        r'DORMANT_CALL_INTEGRATION_ENABLED[\s\S]*startRecording\(\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'DORMANT_CALL_INTEGRATION_ENABLED[\s\S]*emitLatestCompletedCall\(\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Dart microphone requests consult the native release gate first', () {
    final source = File(
      'lib/core/services/call_recording_service.dart',
    ).readAsStringSync();

    expect(source, contains("invokeMethod<bool>('isFeatureEnabled')"));
    expect(
      RegExp(
        r'if \(!await _isDormantIntegrationEnabled\(\)\)[\s\S]*Permission\.microphone\.request',
      ).hasMatch(source),
      isTrue,
    );
  });
}
