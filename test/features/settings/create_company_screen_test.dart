import 'package:bookly/core/auth/rbac.dart';
import 'package:bookly/core/database/collections/institution.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/settings/application/business_provisioning_service.dart';
import 'package:bookly/features/settings/presentation/screens/create_company_screen.dart';
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
  Widget buildApp(GoRouter router) {
    return ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    );
  }

  GoRouter buildRouter({String initialLocation = '/home'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pushNamed('create-company'),
                child: const Text('Open Create Business'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/business/setup',
          name: 'business-setup',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Business setup')),
          ),
        ),
        GoRoute(
          path: '/company/create',
          name: 'create-company',
          builder: (context, state) => const CreateCompanyScreen(),
        ),
      ],
    );
  }

  testWidgets('top-left Back button returns to the previous screen',
      (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(buildApp(router));
    await tester.tap(find.text('Open Create Business'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Create Business'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open Create Business'), findsOneWidget);
    expect(find.byType(CreateCompanyScreen), findsNothing);
  });

  testWidgets('Back button falls back to Business Setup without history',
      (tester) async {
    final router = buildRouter(initialLocation: '/company/create');
    addTearDown(router.dispose);

    await tester.pumpWidget(buildApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Business setup'), findsOneWidget);
    expect(find.byType(CreateCompanyScreen), findsNothing);
  });

  testWidgets('detailed team form submits every legacy business field',
      (tester) async {
    const session = AuthSession(
      userId: 'owner-1',
      email: 'owner@example.com',
      name: 'Owner',
      role: Role.owner,
    );
    final service = _MockProvisioningService();
    final business = Institution()
      ..id = 'inst-team-1'
      ..ownerId = 'owner-1'
      ..name = 'North Studio'
      ..themePreset = 'clinicTeal'
      ..address = '10 Main Street'
      ..phone = '+94 77 123 4567'
      ..email = 'hello@north.example'
      ..createdAt = DateTime.utc(2026, 9, 26)
      ..updatedAt = DateTime.utc(2026, 9, 26)
      ..hasEverHadAdditionalStaff = false;
    when(
      () => service.provision(
        session: session,
        name: any(named: 'name'),
        themePreset: any(named: 'themePreset'),
        address: any(named: 'address'),
        phone: any(named: 'phone'),
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async => business);
    final router = GoRouter(
      initialLocation: '/company/create',
      routes: [
        GoRoute(
          path: '/company/create',
          name: 'create-company',
          builder: (_, __) => const CreateCompanyScreen(),
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

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Business Name'),
      'North Studio',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '10 Main Street',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '+94 77 123 4567',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'hello@north.example',
    );
    await tester.scrollUntilVisible(
      find.text('Clinic Teal'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Clinic Teal'));
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Create Business'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Business'));
    await tester.pumpAndSettle();

    verify(
      () => service.provision(
        session: session,
        name: 'North Studio',
        themePreset: 'clinicTeal',
        address: '10 Main Street',
        phone: '+94 77 123 4567',
        email: 'hello@north.example',
      ),
    ).called(1);
    expect(find.text('Home'), findsOneWidget);
  });
}
