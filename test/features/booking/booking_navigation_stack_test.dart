import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/features/auth/presentation/providers/auth_provider.dart';
import 'package:bookly/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:bookly/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:bookly/features/home/presentation/providers/home_provider.dart';
import 'package:bookly/features/home/presentation/screens/home_screen.dart';
import 'package:bookly/features/home/presentation/screens/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveService extends Mock implements HiveService {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockHiveService db;
  late _MockSecureStorage secureStorage;
  late Appointment appointment;
  late Service service;
  late Customer customer;

  setUp(() {
    db = _MockHiveService();
    secureStorage = _MockSecureStorage();
    appointment = Appointment()
      ..id = 41
      ..startTime = DateTime.now().add(const Duration(hours: 2))
      ..endTime = DateTime.now().add(const Duration(hours: 3))
      ..status = 'upcoming'
      ..customerId = 7
      ..serviceId = 9
      ..notes = <AppointmentNote>[]
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;
    customer = Customer()
      ..id = 7
      ..name = 'Calendar Routing Client'
      ..phoneNumber = '0771234567'
      ..notes = <CustomerNote>[]
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;
    service = Service()
      ..id = 9
      ..title = 'Routing Test Service'
      ..defaultDurationMinutes = 60
      ..cost = 50
      ..isActive = true
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now()
      ..synced = false;

    when(() => secureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => db.getCustomerById(any())).thenReturn(customer);
    when(() => db.getServiceById(9)).thenReturn(service);
  });

  Widget appWithRouter(
    GoRouter router, {
    List<Override> overrides = const <Override>[],
  }) {
    return ProviderScope(
      overrides: [
        homeHiveProvider.overrideWithValue(db),
        secureStorageProvider.overrideWithValue(secureStorage),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }

  GoRoute appointmentDetailProbeRoute() => GoRoute(
        path: '/appointment/:id',
        name: 'appointment-detail',
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(
              'Appointment detail probe ${state.pathParameters['id']}',
            ),
          ),
        ),
      );

  testWidgets('Dashboard tile opens Appointment Details and preserves Back',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        appointmentDetailProbeRoute(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      appWithRouter(
        router,
        overrides: [
          upcomingAppointmentsProvider.overrideWith(
            (ref) => Stream.value([appointment]),
          ),
          servicesProvider.overrideWith((ref) => Stream.value([service])),
          recentCustomersProvider.overrideWith(
            (ref) => Stream.value(const <Customer>[]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Routing Test Service'));
    await tester.pumpAndSettle();

    expect(find.text('Appointment detail probe 41'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('Calendar tile opens Appointment Details and preserves Back',
      (tester) async {
    when(() => db.watchAppointmentsForDate(any()))
        .thenAnswer((_) => Stream.value([appointment]));
    when(() => db.watchAppointmentServicesForAppointment(41))
        .thenAnswer((_) => Stream.value(const <AppointmentService>[]));

    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
        appointmentDetailProbeRoute(),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      appWithRouter(
        router,
        overrides: [
          calendarBusyDaysProvider.overrideWith(
            (ref) => Stream.value(const <DateTime, double>{}),
          ),
          servicesProvider.overrideWith((ref) => Stream.value([service])),
          serviceStationsProvider.overrideWith(
            (ref) => Stream.value(const <ServiceStation>[]),
          ),
          recentCustomersProvider.overrideWith(
            (ref) => Stream.value([customer]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar Routing Client'));
    await tester.pumpAndSettle();

    expect(find.text('Appointment detail probe 41'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('Appointment Edit preserves Appointment Details for Back',
      (tester) async {
    when(() => db.getAppointmentById(41)).thenReturn(appointment);

    final router = GoRouter(
      initialLocation: '/appointment/41',
      routes: [
        GoRoute(
          path: '/appointment/:id',
          builder: (_, __) => const AppointmentDetailScreen(appointmentId: 41),
        ),
        GoRoute(
          path: '/booking/edit/:id',
          name: 'booking-edit',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('Edit booking probe')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit booking probe'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('Dashboard exposes a stack-preserving Quick Book action',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const MainShell(
            child: Center(child: Text('Dashboard probe')),
          ),
        ),
        GoRoute(
          path: '/booking',
          name: 'booking',
          builder: (_, __) => const Scaffold(
            body: Center(child: Text('New booking probe')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(appWithRouter(router));
    await tester.pumpAndSettle();

    final quickBook = find.byKey(const Key('dashboard-quick-book'));
    expect(quickBook, findsOneWidget);
    await tester.tap(quickBook);
    await tester.pumpAndSettle();

    expect(find.text('New booking probe'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });
}
