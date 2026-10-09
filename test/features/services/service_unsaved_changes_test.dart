// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/features/services/presentation/screens/add_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _EmptyAssetManifest extends Fake implements AssetManifest {
  @override
  List<String> listAssets() => const [];
}

class _MockHiveService extends Mock implements HiveService {}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Service());
    tempDir = await Directory.systemTemp.createTemp('service_guard_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tempDir.path,
    );

    const fakeFontBody = 'fake response body - success';
    final fakeFontFile = GoogleFontsFile(
      '1194f6ffe4d2f05258573616a77932c38041f3102763096c19437c3db1818a04',
      fakeFontBody.length,
    );
    google_fonts_base.assetManifest = _EmptyAssetManifest();
    google_fonts_base.httpClient = MockClient(
      (_) async => http.Response(fakeFontBody, 200),
    );
    GoogleFonts.config.allowRuntimeFetching = true;
    for (final weight in <FontWeight>[
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      google_fonts_base.googleFontsTextStyle(
        fontFamily: 'Inter',
        fontWeight: weight,
        fonts: {
          GoogleFontsVariant(
            fontWeight: weight,
            fontStyle: FontStyle.normal,
          ): fakeFontFile,
        },
      );
    }
    await GoogleFonts.pendingFonts();
  });

  tearDownAll(() async {
    google_fonts_base.clearCache();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  testWidgets('dirty Add Service asks before closing', (tester) async {
    final db = _MockHiveService();
    final router = GoRouter(
      initialLocation: '/services/add',
      routes: [
        GoRoute(
          path: '/services/add',
          builder: (_, __) => const AddServiceScreen(),
        ),
        GoRoute(
          path: '/services',
          name: 'service-management',
          builder: (_, __) => const Scaffold(body: Text('Services probe')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Service Title'),
      'Unsaved service',
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).actions,
      hasLength(2),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved service'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Services probe'), findsOneWidget);
    verifyNever(() => db.insertService(any()));
    verifyNever(() => db.updateService(any(), any()));
  });

  testWidgets('Android back asks before leaving dirty Add Service',
      (tester) async {
    final db = _MockHiveService();
    final router = GoRouter(
      initialLocation: '/services',
      routes: [
        GoRoute(
          path: '/services',
          name: 'service-management',
          builder: (_, __) => const Scaffold(body: Text('Services probe')),
        ),
        GoRoute(
          path: '/services/add',
          builder: (_, __) => const AddServiceScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push('/services/add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Service Title'),
      'Unsaved service',
    );
    await tester.pump();

    final popRequest = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await popRequest;

    expect(find.text('Unsaved service'), findsOneWidget);
    expect(find.text('Services probe'), findsNothing);
  });
}
