// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/features/customers/presentation/screens/add_customer_screen.dart';
import 'package:bookly/features/customers/presentation/screens/customer_profile_screen.dart';
import 'package:bookly/features/customers/presentation/screens/customers_screen.dart';
import 'package:bookly/features/customers/presentation/widgets/customer_note_card.dart';
import 'package:bookly/shared/widgets/appointment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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
    registerFallbackValue(Customer());
    tempDir = await Directory.systemTemp.createTemp('customer_notes_test_');
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

  testWidgets('keeps contact fields and supports customer-note CRUD with undo',
      (tester) async {
    final now = DateTime(2026, 9, 6);
    final customer = Customer()
      ..id = 7
      ..name = 'Asha Perera'
      ..phoneNumber = '0712345678'
      ..email = 'asha@example.com'
      ..address = '42 Temple Road'
      ..city = 'Kandy'
      ..dob = DateTime(1990, 5, 4)
      ..notes = [
        CustomerNote(
          id: 'existing-note',
          title: 'Preference',
          description: 'Prefers text messages',
          createdAt: now,
          updatedAt: now,
        ),
      ]
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(() => db.getCustomerById(7)).thenReturn(customer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AddCustomerScreen(customerId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Email (optional)'), findsOneWidget);
    expect(find.text('Address (optional)'), findsOneWidget);
    expect(find.byKey(const Key('customer-city-field')), findsOneWidget);
    expect(find.byKey(const Key('customer-dob-field')), findsOneWidget);
    expect(find.byType(CustomerNoteCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('add-customer-note')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add-customer-note')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-customer-note')));
    await tester.pump();
    expect(find.text('Enter a note title'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('customer-note-title-field')),
      'Accessibility',
    );
    await tester.enterText(
      find.byKey(const Key('customer-note-description-field')),
      'Use the step-free entrance',
    );
    await tester.tap(find.byKey(const Key('save-customer-note')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerNoteCard), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('edit-customer-note-existing-note')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('customer-note-title-field')),
          )
          .controller!
          .text,
      'Preference',
    );
    await tester.enterText(
      find.byKey(const Key('customer-note-title-field')),
      'Contact preference',
    );
    await tester.tap(find.byKey(const Key('save-customer-note')));
    await tester.pumpAndSettle();
    expect(find.text('Contact preference'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('delete-customer-note-existing-note')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contact preference'), findsNothing);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Contact preference'), findsOneWidget);
  });

  testWidgets('add mode keeps the contact import entry point', (tester) async {
    final db = _MockHiveService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AddCustomerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import from Contacts'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Email (optional)'), findsOneWidget);
    expect(find.text('Address (optional)'), findsOneWidget);
    expect(find.text('City (optional)'), findsOneWidget);
  });

  testWidgets('dirty Add Customer asks before closing', (tester) async {
    final db = _MockHiveService();
    final router = GoRouter(
      initialLocation: '/customers/add',
      routes: [
        GoRoute(
          path: '/customers/add',
          builder: (_, __) => const AddCustomerScreen(),
        ),
        GoRoute(
          path: '/customers',
          name: 'customers',
          builder: (_, __) => const Scaffold(body: Text('Customers index')),
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
      find.widgetWithText(TextFormField, 'Name'),
      'Unsaved name',
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(
      find.text(
        'You have unsaved changes. If you leave now, they will be lost.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Discard'), findsOneWidget);
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.actions, hasLength(2));
    expect(dialog.actions, everyElement(isA<TextButton>()));
    expect(find.text('Unsaved name'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Unsaved name'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Unsaved name'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Customers index'), findsOneWidget);
    verifyNever(() => db.insertCustomer(any()));
    verifyNever(() => db.updateCustomer(any(), any()));
  });

  testWidgets('clean Add Customer closes without a confirmation dialog',
      (tester) async {
    final db = _MockHiveService();
    final router = GoRouter(
      initialLocation: '/customers/add',
      routes: [
        GoRoute(
          path: '/customers/add',
          builder: (_, __) => const AddCustomerScreen(),
        ),
        GoRoute(
          path: '/customers',
          name: 'customers',
          builder: (_, __) => const Scaffold(body: Text('Customers index')),
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

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Customers index'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('reverting an Edit Customer field restores the clean baseline',
      (tester) async {
    final customer = Customer()
      ..id = 7
      ..name = 'Original name'
      ..phoneNumber = '0712345678'
      ..createdAt = DateTime(2026, 9, 1)
      ..updatedAt = DateTime(2026, 9, 1);
    final db = _MockHiveService();
    when(() => db.getCustomerById(7)).thenReturn(customer);
    final router = GoRouter(
      initialLocation: '/customers/7/edit',
      routes: [
        GoRoute(
          path: '/customers/:id/edit',
          builder: (_, state) => AddCustomerScreen(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/customers',
          name: 'customers',
          builder: (_, __) => const Scaffold(body: Text('Customers index')),
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

    final nameField = find.widgetWithText(TextFormField, 'Name');
    await tester.enterText(nameField, 'Changed name');
    await tester.enterText(nameField, 'Original name');
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('Customers index'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
    verifyNever(() => db.updateCustomer(any(), any()));
  });

  testWidgets('Android back asks before leaving dirty Add Customer',
      (tester) async {
    final db = _MockHiveService();
    final router = GoRouter(
      initialLocation: '/customers',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (_, __) => const Scaffold(body: Text('Customers index')),
        ),
        GoRoute(
          path: '/customers/add',
          builder: (_, __) => const AddCustomerScreen(),
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
    unawaited(router.push('/customers/add'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Unsaved name',
    );
    await tester.pump();

    final popRequest = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Unsaved name'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await popRequest;
  });

  testWidgets('add mode persists address and city independently',
      (tester) async {
    final db = _MockHiveService();
    Customer? savedCustomer;
    when(() => db.insertCustomer(any())).thenAnswer((invocation) async {
      savedCustomer = invocation.positionalArguments.single as Customer;
      return 1;
    });
    final router = GoRouter(
      initialLocation: '/customers/add',
      routes: [
        GoRoute(
          path: '/customers/add',
          builder: (_, __) => const AddCustomerScreen(),
        ),
        GoRoute(
          path: '/customers',
          name: 'customers',
          builder: (_, __) => const Scaffold(body: Text('Customers')),
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

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Asha');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone'),
      '0712345678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address (optional)'),
      '42 Temple Road',
    );
    await tester.enterText(
      find.byKey(const Key('customer-city-field')),
      'Kandy',
    );
    await tester.scrollUntilVisible(
      find.text('Save Customer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Customer'));
    await tester.pumpAndSettle();

    expect(savedCustomer, isNotNull);
    expect(savedCustomer!.address, '42 Temple Road');
    expect(savedCustomer!.city, 'Kandy');
  });

  testWidgets('profile independently renders address, city, age, and notes',
      (tester) async {
    final now = DateTime(2026, 9, 6);
    Customer buildCustomer({
      String? address = '42 Temple Road',
      String? city = 'Kandy',
      DateTime? dob,
      List<CustomerNote>? notes,
    }) =>
        Customer()
          ..id = 7
          ..name = 'Asha Perera'
          ..phoneNumber = '0712345678'
          ..address = address
          ..city = city
          ..dob = dob ?? DateTime(1990, 5, 4)
          ..notes = notes ??
              [
                CustomerNote(
                  id: 'profile-note',
                  title: 'Preference',
                  createdAt: now,
                  updatedAt: now,
                ),
              ]
          ..createdAt = now
          ..updatedAt = now
          ..synced = false;

    final db = _MockHiveService();
    var current = buildCustomer();
    when(() => db.getCustomerById(7)).thenAnswer((_) => current);
    when(() => db.getAppointmentsForCustomer(7))
        .thenReturn(const <Appointment>[]);

    Future<void> pumpProfile() => tester.pumpWidget(
          ProviderScope(
            overrides: [hiveServiceProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CustomerProfileScreen(customerId: 7),
            ),
          ),
        );

    await pumpProfile();
    await tester.pumpAndSettle();
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.byType(CustomerNoteCard), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-customer-note-profile-note')),
        findsNothing);
    expect(find.byKey(const ValueKey('delete-customer-note-profile-note')),
        findsNothing);
    expect(find.text('Appointment History'), findsOneWidget);
    expect(find.text('Book Appointment'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);

    current = buildCustomer(address: null);
    await pumpProfile();
    await tester.pumpAndSettle();
    expect(find.text('Address'), findsNothing);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.byType(CustomerNoteCard), findsOneWidget);

    current = buildCustomer(city: null);
    await pumpProfile();
    await tester.pumpAndSettle();
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('City'), findsNothing);

    current = buildCustomer(dob: null);
    current.dob = null;
    await pumpProfile();
    await tester.pumpAndSettle();
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Age'), findsNothing);
    expect(find.byType(CustomerNoteCard), findsOneWidget);

    current = buildCustomer(notes: const <CustomerNote>[]);
    await pumpProfile();
    await tester.pumpAndSettle();
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.byType(CustomerNoteCard), findsNothing);
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('profile books with customer id as the primary route payload',
      (tester) async {
    final now = DateTime(2026, 9, 7);
    final customer = Customer()
      ..id = 7
      ..name = 'Asha Perera'
      ..phoneNumber = '0712345678'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(() => db.getCustomerById(7)).thenReturn(customer);
    when(() => db.getAppointmentsForCustomer(7))
        .thenReturn(const <Appointment>[]);
    final router = GoRouter(
      initialLocation: '/customer/7',
      routes: [
        GoRoute(
          path: '/customer/:id',
          builder: (_, __) => const CustomerProfileScreen(customerId: 7),
        ),
        GoRoute(
          path: '/booking',
          name: 'booking',
          builder: (_, state) => Scaffold(
            body: Text(
              'customerId=${state.uri.queryParameters['customerId']};'
              'phone=${state.uri.queryParameters['phone']}',
            ),
          ),
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
    await tester.scrollUntilVisible(
      find.text('Book Appointment'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Book Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('customerId=7;phone=0712345678'), findsOneWidget);
  });

  testWidgets('profile history reuses the customer-first appointment card',
      (tester) async {
    final customer = Customer()
      ..id = 7
      ..name = 'Asha Perera'
      ..phoneNumber = '0712345678'
      ..createdAt = DateTime(2026, 9, 1)
      ..updatedAt = DateTime(2026, 9, 1)
      ..synced = false;
    final appointment = Appointment()
      ..id = 41
      ..customerId = 7
      ..serviceId = 9
      ..stationId = 3
      ..startTime = DateTime(2026, 9, 18, 15, 45)
      ..endTime = DateTime(2026, 9, 18, 17)
      ..status = 'confirmed'
      ..createdAt = DateTime(2026, 9, 1)
      ..updatedAt = DateTime(2026, 9, 1)
      ..synced = false;
    final haircut = Service()
      ..id = 9
      ..title = 'Haircut'
      ..defaultDurationMinutes = 30
      ..cost = 25
      ..createdAt = DateTime(2026, 9, 1)
      ..updatedAt = DateTime(2026, 9, 1)
      ..synced = false;
    final colour = Service()
      ..id = 10
      ..title = 'Colour treatment'
      ..defaultDurationMinutes = 45
      ..cost = 50
      ..createdAt = DateTime(2026, 9, 1)
      ..updatedAt = DateTime(2026, 9, 1)
      ..synced = false;
    final station = ServiceStation()
      ..id = 3
      ..name = 'Mall Branch';
    final db = _MockHiveService();
    when(() => db.getCustomerById(7)).thenReturn(customer);
    when(() => db.getAppointmentsForCustomer(7)).thenReturn([appointment]);
    when(() => db.getAppointmentServicesForAppointment(41)).thenReturn([
      AppointmentService()
        ..appointmentId = 41
        ..serviceId = 9
        ..durationOverride = 35,
      AppointmentService()
        ..appointmentId = 41
        ..serviceId = 10,
    ]);
    when(() => db.getServiceById(9)).thenReturn(haircut);
    when(() => db.getServiceById(10)).thenReturn(colour);
    when(() => db.getServiceStationById(3)).thenReturn(station);

    final router = GoRouter(
      initialLocation: '/customer/7',
      routes: [
        GoRoute(
          path: '/customer/:id',
          builder: (_, __) => const CustomerProfileScreen(customerId: 7),
        ),
        GoRoute(
          path: '/appointment/:id',
          name: 'appointment-detail',
          builder: (_, state) => Scaffold(
            body: Text('Appointment ${state.pathParameters['id']}'),
          ),
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
    await tester.scrollUntilVisible(
      find.byType(AppointmentTile),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byType(AppointmentTile), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('80 min'), findsOneWidget);
    expect(find.text('Mall Branch'), findsOneWidget);
    expect(find.text('Haircut'), findsNothing);
    expect(find.text('Colour treatment'), findsNothing);

    await tester.tap(find.byType(AppointmentTile));
    await tester.pumpAndSettle();
    expect(find.text('Appointment 41'), findsOneWidget);
  });

  testWidgets('profile handles a sparse local customer without crashing',
      (tester) async {
    final customer = Customer()..id = 7;
    final db = _MockHiveService();
    when(() => db.getCustomerById(7)).thenReturn(customer);
    when(() => db.getAppointmentsForCustomer(7))
        .thenReturn(const <Appointment>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomerProfileScreen(customerId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unnamed customer'), findsOneWidget);
    expect(find.text('No contact information available'), findsOneWidget);
    expect(find.textContaining('Customer since'), findsNothing);
    expect(find.text('Phone'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is FilledButton && widget.onPressed == null,
      ),
      findsOneWidget,
    );
  });

  testWidgets('customer list renders sparse local rows safely', (tester) async {
    final customer = Customer();
    final db = _MockHiveService();
    when(db.watchAllCustomers).thenAnswer((_) => Stream.value([customer]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CustomersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Unnamed customer'), findsOneWidget);
    expect(find.text('null'), findsNothing);
  });
}
