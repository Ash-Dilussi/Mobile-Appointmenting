import 'package:bookly/core/auth/rbac.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/database/collections/institution.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/settings/application/business_provisioning_service.dart';
import 'package:bookly/features/settings/presentation/screens/business_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockProvisioningService extends Mock
    implements BusinessProvisioningService {}

class _MockHiveService extends Mock implements HiveService {}

class _FixedSessionNotifier extends AuthSessionNotifier {
  _FixedSessionNotifier(AuthSession session) : super(_MockHiveService()) {
    state = session;
  }
}

void main() {
  const session = AuthSession(
    userId: 'owner-1',
    email: 'alex@example.com',
    name: 'Alex',
    role: Role.owner,
  );

  test('builds readable default solo business names', () {
    expect(
      defaultSoloBusinessName(displayName: 'Alex', email: 'a@example.com'),
      "Alex's Business",
    );
    expect(
      defaultSoloBusinessName(displayName: 'Chris', email: 'c@example.com'),
      "Chris' Business",
    );
    expect(
      defaultSoloBusinessName(displayName: null, email: 'solo@example.com'),
      "solo's Business",
    );
  });

  testWidgets('offers solo and team paths without company-labelled UI',
      (tester) async {
    final service = _MockProvisioningService();
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(
          path: '/setup',
          name: 'business-setup',
          builder: (_, __) => const BusinessSetupScreen(),
        ),
        GoRoute(
          path: '/business/create',
          name: 'create-company',
          builder: (_, __) => const Scaffold(body: Text('Team setup')),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => _FixedSessionNotifier(session),
          ),
          businessProvisioningServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('My team'), findsOneWidget);
    expect(find.textContaining('company', findRichText: true), findsNothing);

    await tester.tap(find.text('My team'));
    await tester.pumpAndSettle();
    expect(find.text('Team setup'), findsOneWidget);
  });

  testWidgets('solo path auto-provisions, confirms the name, and is skippable',
      (tester) async {
    final service = _MockProvisioningService();
    final business = Institution()
      ..id = 'business-1'
      ..name = "Alex's Business"
      ..themePreset = 'solarOrange'
      ..ownerId = 'owner-1'
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026)
      ..hasEverHadAdditionalStaff = false;
    when(
      () => service.provision(
        session: session,
        name: any(named: 'name'),
        themePreset: any(named: 'themePreset'),
      ),
    ).thenAnswer((_) async => business);
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(
          path: '/setup',
          name: 'business-setup',
          builder: (_, __) => const BusinessSetupScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => _FixedSessionNotifier(session),
          ),
          businessProvisioningServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just me'));
    await tester.pumpAndSettle();

    expect(find.text('Your business is ready'), findsOneWidget);
    expect(find.textContaining("Alex's Business"), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    verify(
      () => service.provision(
        session: session,
        name: "Alex's Business",
        themePreset: 'solarOrange',
      ),
    ).called(1);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('provisioning failure enters retry-safe recovery state',
      (tester) async {
    final service = _MockProvisioningService();
    var attempts = 0;
    when(
      () => service.provision(
        session: session,
        name: any(named: 'name'),
        themePreset: any(named: 'themePreset'),
      ),
    ).thenAnswer((_) async {
      attempts += 1;
      throw const BusinessProvisioningRecoveryRequired(
        message:
            'We could not finish setting up your business. Your account is safe, and you can retry.',
      );
    });
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(
          path: '/setup',
          name: 'business-setup',
          builder: (_, __) => const BusinessSetupScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => _FixedSessionNotifier(session),
          ),
          businessProvisioningServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just me'));
    await tester.pumpAndSettle();

    expect(find.text('Your account is safe'), findsOneWidget);
    expect(find.text('Retry setup'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Just me'), findsNothing);

    await tester.tap(find.text('Retry setup'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
