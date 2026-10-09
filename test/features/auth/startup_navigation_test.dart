import 'dart:io';

import 'package:bookly/core/hive/hive_initializer.dart';
import 'package:bookly/core/providers/app_init_provider.dart';
import 'package:bookly/core/router/app_router.dart';
import 'package:bookly/features/auth/presentation/providers/app_launch_provider.dart';
import 'package:bookly/features/auth/presentation/screens/entrance_screen.dart';
import 'package:bookly/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDirectory = await Directory.systemTemp.createTemp(
      'startup_navigation_test_',
    );

    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDirectory.path);

    await Hive.initFlutter(tempDirectory.path);
    await HiveInitializer.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  testWidgets(
    'checking entrance follows the resolved launch state instead of looping',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/entrance',
        routes: [
          GoRoute(
            path: '/entrance',
            builder: (context, state) => EntranceScreen(
              launchState:
                  state.extra as AppLaunchState? ?? const AppLaunchChecking(),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(
              body: Text('Login destination'),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(
              body: Text('Home destination'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(find.text('Login destination'), findsOneWidget);
    },
  );

  test('auth resolution does not recreate the app router', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialRouter = container.read(routerProvider);
    container.read(appLaunchProvider);

    return Future<void>.delayed(const Duration(milliseconds: 1300)).then((_) {
      expect(
          container.read(appLaunchProvider), isNot(isA<AppLaunchChecking>()));
      expect(container.read(routerProvider), same(initialRouter));
    });
  });

  testWidgets('splash navigates when app init is already complete',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/entrance',
          builder: (_, __) => const Scaffold(
            body: Text('Entrance destination'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appInitProvider.overrideWith(_CompletedAppInitNotifier.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('Entrance destination'), findsOneWidget);
  });
}

class _CompletedAppInitNotifier extends AppInitNotifier {
  @override
  Future<bool> build() async => true;
}
