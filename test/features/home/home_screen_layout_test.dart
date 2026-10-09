import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/features/auth/domain/entities/auth_user.dart';
import 'package:bookly/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookly/features/auth/presentation/providers/auth_providers.dart';
import 'package:bookly/features/auth/presentation/providers/auth_provider.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/home/presentation/providers/home_provider.dart';
import 'package:bookly/features/home/presentation/screens/home_screen.dart';
import 'package:bookly/shared/widgets/app_surface_card.dart';
import 'package:bookly/shared/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveService extends Mock implements HiveService {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockHiveService db;
  late _MockSecureStorage secureStorage;
  late _MockAuthRepository authRepository;
  late AuthUser authUser;
  late List<Customer> customers;
  late Appointment appointment;
  late Service service;

  setUp(() {
    db = _MockHiveService();
    secureStorage = _MockSecureStorage();
    authRepository = _MockAuthRepository();
    authUser = AuthUser(
      uid: 'owner-1',
      email: 'owner@bookly.test',
      displayName: 'Owner',
      role: UserRole.owner,
      institutionId: 'company-1',
      isEmailVerified: true,
      createdAt: DateTime(2026),
    );
    customers = [
      Customer()
        ..id = 7
        ..name = 'Alice Perera'
        ..phoneNumber = '0771234567'
        ..notes = <CustomerNote>[]
        ..synced = false,
      Customer()
        ..id = 8
        ..name = 'Ben Silva'
        ..phoneNumber = '0717654321'
        ..notes = <CustomerNote>[]
        ..synced = false,
    ];
    appointment = Appointment()
      ..id = 41
      ..customerId = 7
      ..serviceId = 9
      ..startTime = DateTime.now().add(const Duration(hours: 2))
      ..endTime = DateTime.now().add(const Duration(hours: 3))
      ..status = 'upcoming'
      ..notes = <AppointmentNote>[]
      ..synced = false;
    service = Service()
      ..id = 9
      ..title = 'Consultation'
      ..defaultDurationMinutes = 60
      ..cost = 50
      ..isActive = true
      ..synced = false;

    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => db.getCustomerById(7)).thenReturn(customers.first);
    when(() => db.getServiceById(9)).thenReturn(service);
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => Stream.value(authUser));
    when(() => authRepository.getCurrentUser())
        .thenAnswer((_) async => authUser);
    when(() => authRepository.acknowledgePasswordChangePrompt())
        .thenAnswer((_) async {});
  });

  Widget appWithRouter(GoRouter router) {
    return ProviderScope(
      overrides: [
        homeHiveProvider.overrideWithValue(db),
        hiveServiceProvider.overrideWithValue(db),
        authSessionProvider.overrideWith(
          (ref) => AuthSessionNotifier(db)..loadSessionFromAuthUser(authUser),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        secureStorageProvider.overrideWithValue(secureStorage),
        upcomingAppointmentsProvider.overrideWith(
          (ref) => Stream.value([appointment]),
        ),
        servicesProvider.overrideWith(
          (ref) => Stream.value([service]),
        ),
        recentCustomersProvider.overrideWith(
          (ref) => Stream.value(customers),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Calendar probe')),
            ),
          ),
          GoRoute(
            path: '/customers',
            name: 'customers',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Customers probe')),
            ),
          ),
          GoRoute(
            path: '/customer/:id',
            name: 'customer-profile',
            builder: (_, state) => Scaffold(
              body: Center(
                child: Text('Customer probe ${state.pathParameters['id']}'),
              ),
            ),
          ),
          GoRoute(
            path: '/coming-soon',
            name: 'coming-soon',
            builder: (_, __) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/business/setup',
            name: 'business-setup',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Business setup probe')),
            ),
          ),
          GoRoute(
            path: '/change-password',
            name: 'change-password',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Change password probe')),
            ),
          ),
        ],
      );

  testWidgets('renders standalone headers and one surface per recent client',
      (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.pumpAndSettle();

    expect(find.byType(SectionHeader), findsNWidgets(2));
    expect(
      find.ancestor(
        of: find.text('Availability'),
        matching: find.byType(AppSurfaceCard),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Recent Clients'),
        matching: find.byType(AppSurfaceCard),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.text('Alice Perera'),
        matching: find.byType(AppSurfaceCard),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Ben Silva'),
        matching: find.byType(AppSurfaceCard),
      ),
      findsOneWidget,
    );
  });

  testWidgets('preserves section actions and customer profile navigation',
      (tester) async {
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View Calendar'));
    await tester.tap(find.text('View Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar probe'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('See All'));
    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(find.text('Customers probe'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    final aliceCard = find.ancestor(
      of: find.text('Alice Perera'),
      matching: find.byType(AppSurfaceCard),
    );
    await tester.ensureVisible(aliceCard);
    await tester.tap(aliceCard);
    await tester.pumpAndSettle();
    expect(find.text('Customer probe 7'), findsOneWidget);
  });

  testWidgets('shows persistent business setup CTA for an unlinked user',
      (tester) async {
    authUser = AuthUser(
      uid: 'new-1',
      email: 'new@bookly.test',
      displayName: 'New Owner',
      role: UserRole.unknown,
      institutionId: '',
      isEmailVerified: true,
      createdAt: DateTime(2026),
    );
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => Stream.value(authUser));
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Set up your business to get started'), findsOneWidget);
    await tester.tap(find.text('Set up your business'));
    await tester.pumpAndSettle();
    expect(find.text('Business setup probe'), findsOneWidget);
  });

  testWidgets('offers an optional password change prompt to a new officer',
      (tester) async {
    authUser = AuthUser(
      uid: 'officer-1',
      email: 'officer@bookly.test',
      displayName: 'Officer',
      role: UserRole.officer,
      institutionId: 'company-1',
      isEmailVerified: false,
      shouldPromptPasswordChange: true,
      createdAt: DateTime(2026),
    );
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => Stream.value(authUser));
    final router = buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Change your temporary password'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.text('Change password probe'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Change your temporary password'), findsNothing);
  });
}
