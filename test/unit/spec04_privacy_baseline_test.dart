import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('contact import uses the native picker without broad permission', () {
    final customerForm = File(
      'lib/features/customers/presentation/screens/add_customer_screen.dart',
    ).readAsStringSync();

    expect(customerForm, contains('FlutterContacts.openExternalPick()'));

    final dartSources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final source in dartSources) {
      final contents = source.readAsStringSync();
      expect(
        contents,
        isNot(contains('Permission.contacts')),
        reason: '${source.path} must not request broad contacts permission',
      );
      expect(
        contents,
        isNot(contains('FlutterContacts.requestPermission')),
        reason: '${source.path} must use the OS-owned picker only',
      );
    }

    final androidManifests = Directory('android/app/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('AndroidManifest.xml'));
    for (final manifest in androidManifests) {
      final contents = manifest.readAsStringSync();
      expect(
        contents,
        isNot(contains('android.permission.READ_CONTACTS')),
        reason: '${manifest.path} must not declare broad read access',
      );
      expect(
        contents,
        isNot(contains('android.permission.WRITE_CONTACTS')),
        reason: '${manifest.path} must not declare broad write access',
      );
    }

    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(infoPlist, isNot(contains('NSContactsUsageDescription')));
  });

  test('public dependency list has no ads, analytics, or crash SDK', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    const prohibitedDependencies = <String>[
      'firebase_analytics:',
      'firebase_crashlytics:',
      'firebase_performance:',
      'google_mobile_ads:',
      'sentry_flutter:',
      'appcenter_analytics:',
      'appcenter_crashes:',
      'mixpanel_flutter:',
      'amplitude_flutter:',
      'facebook_app_events:',
      'appsflyer_sdk:',
      'adjust_sdk:',
    ];

    for (final dependency in prohibitedDependencies) {
      expect(
        pubspec,
        isNot(contains(dependency)),
        reason: '$dependency changes the Spec 04 data inventory',
      );
    }
  });
}
