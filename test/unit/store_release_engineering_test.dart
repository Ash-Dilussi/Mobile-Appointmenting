import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release targets API 36 and never falls back to debug signing',
      () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final properties = File('android/gradle.properties').readAsStringSync();

    expect(gradle, contains('targetSdk = 36'));
    expect(settings, contains('version "8.10.1"'));
    expect(properties, contains('kotlin.incremental=false'));
    expect(
        properties, contains('kotlin.compiler.execution.strategy=in-process'));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
    expect(gradle, contains('Bookly release signing is not configured'));
    expect(gradle, contains('BOOKLY_ANDROID_STORE_FILE'));
  });

  test('unfinished destinations are excluded from release builds', () {
    final scope = File('lib/core/config/release_scope.dart').readAsStringSync();
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    final settings = File(
      'lib/features/settings/presentation/screens/settings_screen.dart',
    ).readAsStringSync();
    final home = File(
      'lib/features/home/presentation/screens/home_screen.dart',
    ).readAsStringSync();
    final stations = File(
      'lib/features/services/presentation/screens/station_management_screen.dart',
    ).readAsStringSync();

    expect(
      scope,
      contains('developmentOnlyDestinationsEnabled = !kReleaseMode'),
    );
    expect(
      RegExp(
        r'if \(ReleaseScope\.developmentOnlyDestinationsEnabled\)\s*GoRoute\(\s*path: ./(?:upgrade|coming-soon)',
        multiLine: true,
      ).allMatches(router).length,
      2,
    );
    expect(settings, contains('Email bookly.support@gmail.com'));
    expect(settings,
        isNot(contains("_openComingSoon(context, 'Contact Support')")));
    expect(
      settings,
      contains('if (ReleaseScope.developmentOnlyDestinationsEnabled)'),
    );
    expect(home, contains('ReleaseScope.developmentOnlyDestinationsEnabled'));
    expect(
      stations,
      contains('ReleaseScope.developmentOnlyDestinationsEnabled &&'),
    );
  });

  test('release secrets remain excluded from version control', () {
    final rootIgnore = File('.gitignore').readAsStringSync();
    final androidIgnore = File('android/.gitignore').readAsStringSync();

    expect(rootIgnore, contains('*.jks'));
    expect(rootIgnore, contains('**/android/key.properties'));
    expect(androidIgnore, contains('key.properties'));
    expect(androidIgnore, contains('**/*.jks'));
  });
}
