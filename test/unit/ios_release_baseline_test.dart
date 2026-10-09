import 'dart:io';

import 'package:bookly/core/config/release_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS public-v1 declares no contacts or dormant call permissions', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, isNot(contains('NSContactsUsageDescription')));
    expect(infoPlist, isNot(contains('NSMicrophoneUsageDescription')));
    expect(infoPlist, isNot(contains('NSPhoneUsageDescription')));
    expect(infoPlist, isNot(contains('CFBundleURLSchemes')));
    expect(infoPlist, isNot(contains('109555447879692783095')));
  });

  test('CocoaPods baseline targets the plugin minimum iOS version', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final frameworkInfo = File(
      'ios/Flutter/AppFrameworkInfo.plist',
    ).readAsStringSync();

    expect(podfile, contains("platform :ios, '13.0'"));
    expect(podfile, contains('flutter_install_all_ios_pods'));
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 12.0')));
    expect(project, contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0'));
    expect(frameworkInfo, contains('<string>13.0</string>'));
  });

  test('iOS Firebase configuration has no committed placeholders', () {
    final options = File(
      'lib/core/firebase/firebase_options.dart',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(options, isNot(contains('YOUR_IOS_API_KEY')));
    expect(options, isNot(contains('YOUR_IOS_APP_ID')));
    expect(options, contains('BOOKLY_IOS_FIREBASE_API_KEY'));
    expect(options, contains('BOOKLY_IOS_FIREBASE_APP_ID'));
    expect(project, contains('GoogleService-Info.plist in Resources'));
  });

  test('hosted workflow declares pod, signing, IPA, and TestFlight stages', () {
    final pipeline = File('codemagic.yaml').readAsStringSync();

    expect(pipeline, contains('instance_type: mac_mini_m2'));
    expect(pipeline, contains('IOS_FIREBASE_CONFIG_BASE64'));
    expect(pipeline, contains('cd ios && pod install'));
    expect(pipeline, contains(r'fetch-signing-files "$BUNDLE_ID"'));
    expect(pipeline, contains('--type IOS_APP_STORE'));
    expect(pipeline, contains('flutter build ipa --release'));
    expect(pipeline, contains('submit_to_testflight: true'));
  });

  test('Google OAuth features are outside the iOS release scope', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(ReleaseScope.googleSignInEnabled, isFalse);
    expect(ReleaseScope.googleCalendarSyncEnabled, isFalse);

    final settings = File(
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ).readAsStringSync();
    final booking = File(
      'lib/features/booking/presentation/screens/booking_screen.dart',
    ).readAsStringSync();

    expect(
      settings,
      contains('if (ReleaseScope.googleCalendarSyncEnabled)'),
    );
    expect(
      booking,
      contains('if (ReleaseScope.googleCalendarSyncEnabled)'),
    );
  });

  test('Google OAuth features remain in Android release scope', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(ReleaseScope.googleSignInEnabled, isTrue);
    expect(ReleaseScope.googleCalendarSyncEnabled, isTrue);
  });
}
