import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/core/theme/service_color_palette.dart';
import 'package:bookly/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookly/features/services/presentation/screens/service_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveService extends Mock implements HiveService {}

void main() {
  testWidgets('Book Appointment hands the viewed service to Booking',
      (tester) async {
    final db = _MockHiveService();
    final service = Service()
      ..id = 9
      ..title = 'Consultation'
      ..defaultDurationMinutes = 45
      ..cost = 75
      ..isActive = true
      ..createdAt = DateTime(2026, 9, 15)
      ..updatedAt = DateTime(2026, 9, 15)
      ..synced = false;
    when(() => db.getServiceById(9)).thenReturn(service);

    final router = GoRouter(
      initialLocation: '/services/detail/9',
      routes: [
        GoRoute(
          path: '/services/detail/:id',
          builder: (_, __) => const ServiceDetailScreen(serviceId: 9),
        ),
        GoRoute(
          path: '/booking',
          name: 'booking',
          builder: (_, state) => Scaffold(
            body: Text(
              'Booking service ${state.uri.queryParameters['serviceId']}',
            ),
          ),
        ),
        GoRoute(
          path: '/services',
          name: 'service-management',
          builder: (_, __) => const Scaffold(),
        ),
        GoRoute(
          path: '/services/edit/:id',
          name: 'edit-service',
          builder: (_, __) => const Scaffold(),
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

    final bookAction = find.text('Book Appointment');
    await tester.ensureVisible(bookAction);
    await tester.pumpAndSettle();
    await tester.tap(bookAction);
    await tester.pumpAndSettle();

    expect(find.text('Booking service 9'), findsOneWidget);
    expect(router.canPop(), isTrue);
  });

  testWidgets('Booking preselects a service supplied by Service Details',
      (tester) async {
    final db = _MockHiveService();
    final service = Service()
      ..id = 9
      ..title = 'Consultation'
      ..defaultDurationMinutes = 45
      ..cost = 75
      ..isActive = true
      ..createdAt = DateTime(2026, 9, 15)
      ..updatedAt = DateTime(2026, 9, 15)
      ..synced = false;
    when(() => db.getServiceById(9)).thenReturn(service);
    when(db.watchAllServices).thenAnswer((_) => Stream.value([service]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: BookingScreen(prefilledServiceId: 9),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final servicePill = find.byKey(const ValueKey('booking-service-9'));
    expect(servicePill, findsOneWidget);
    expect(
      find.descendant(
        of: servicePill,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('service pills behave as one radio group and use saved accent',
      (tester) async {
    final db = _MockHiveService();
    final first = Service()
      ..id = 9
      ..title = 'Consultation'
      ..defaultDurationMinutes = 45
      ..cost = 75
      ..colorValue = ServiceColorPalette.options[1].argbValue
      ..isActive = true
      ..createdAt = DateTime(2026, 9, 15)
      ..updatedAt = DateTime(2026, 9, 15)
      ..synced = false;
    final second = Service()
      ..id = 10
      ..title = 'Follow-up'
      ..defaultDurationMinutes = 30
      ..cost = 50
      ..colorValue = ServiceColorPalette.options[5].argbValue
      ..isActive = true
      ..createdAt = DateTime(2026, 9, 15)
      ..updatedAt = DateTime(2026, 9, 15)
      ..synced = false;
    when(db.watchAllServices).thenAnswer((_) => Stream.value([first, second]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(() => db.getServiceById(9)).thenReturn(first);
    when(() => db.getServiceById(10)).thenReturn(second);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BookingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstPill = find.byKey(const ValueKey('booking-service-9'));
    final secondPill = find.byKey(const ValueKey('booking-service-10'));
    expect(firstPill, findsOneWidget);
    expect(secondPill, findsOneWidget);

    await tester.tap(firstPill);
    await tester.pump();
    await tester.tap(secondPill);
    await tester.pump();

    expect(
      find.descendant(
        of: firstPill,
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: secondPill,
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
    final selectedMaterial = tester.widget<Material>(
      find.descendant(of: secondPill, matching: find.byType(Material)).first,
    );
    expect(selectedMaterial.color, ServiceColorPalette.options[5].color);
  });
}
