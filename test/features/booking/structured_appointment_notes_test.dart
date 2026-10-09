// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';

import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/core/theme/app_spacing.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/core/utils/age_utils.dart';
import 'package:bookly/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:bookly/features/booking/presentation/screens/booking_confirmation_screen.dart';
import 'package:bookly/features/booking/presentation/screens/booking_screen.dart';
import 'package:bookly/shared/widgets/app_surface_card.dart';
import 'package:bookly/features/booking/presentation/widgets/appointment_note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class _EmptyAssetManifest extends Fake implements AssetManifest {
  @override
  List<String> listAssets() => const [];
}

class _MockHiveService extends Mock implements HiveService {}

ServiceStation _testStation() => ServiceStation()
  ..id = 4
  ..name = 'Main Room'
  ..createdAt = DateTime(2026, 9, 11)
  ..updatedAt = DateTime(2026, 9, 11)
  ..synced = false;

Future<void> _selectTestStation(WidgetTester tester) async {
  final station = find.byKey(const ValueKey('booking-station-4'));
  await tester.scrollUntilVisible(
    station,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(station);
  await tester.pump();
}

Future<void> _tapBookingAction(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  final pageScroll = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  pageScroll.position.jumpTo(pageScroll.position.maxScrollExtent);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  late Directory tempDir;
  late HiveService hiveService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Customer());
    registerFallbackValue(Appointment());
    tempDir = await Directory.systemTemp.createTemp('structured_notes_test_');

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

    await Hive.initFlutter(tempDir.path);
    hiveService = HiveService();
    await hiveService.init();
  });

  setUp(() => hiveService.clearAllData());

  tearDownAll(() async {
    google_fonts_base.clearCache();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('dirty New Appointment asks before closing', (tester) async {
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(db.getAllCustomers).thenReturn(const <Customer>[]);

    final router = GoRouter(
      initialLocation: '/booking',
      routes: [
        GoRoute(
          path: '/booking',
          builder: (_, __) => const BookingScreen(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('Home probe')),
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
      find.byKey(const Key('booking-phone-field')),
      '0712345678',
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
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('booking-phone-field')))
          .controller!
          .text,
      '0712345678',
    );

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Home probe'), findsOneWidget);
    verifyNever(() => db.insertCustomer(any()));
    verifyNever(() => db.insertAppointment(any()));
  });

  testWidgets('Android back guards a non-text booking selection',
      (tester) async {
    final service = Service()
      ..id = 3
      ..title = 'Haircut'
      ..defaultDurationMinutes = 30
      ..cost = 2500
      ..createdAt = DateTime(2026, 9, 1)
      ..updatedAt = DateTime(2026, 9, 1);
    final db = _MockHiveService();
    when(db.watchAllServices).thenAnswer((_) => Stream.value([service]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(db.getAllCustomers).thenReturn(const <Customer>[]);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('Home probe')),
        ),
        GoRoute(
          path: '/booking',
          builder: (_, __) => const BookingScreen(),
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
    unawaited(router.push('/booking'));
    await tester.pumpAndSettle();

    final serviceChip = find.byKey(const ValueKey('booking-service-3'));
    await tester.scrollUntilVisible(
      serviceChip,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(serviceChip);
    await tester.pump();

    final popRequest = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await popRequest;

    expect(find.text('Home probe'), findsOneWidget);
    verifyNever(() => db.insertAppointment(any()));
  });

  testWidgets('requires a radio-selected service station before booking',
      (tester) async {
    final now = DateTime(2026, 9, 11);
    final customer = Customer()
      ..id = 21
      ..name = 'Station Customer'
      ..phoneNumber = '0771234567'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final station = ServiceStation()
      ..id = 4
      ..name = 'Main Room'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations).thenAnswer((_) => Stream.value([station]));
    when(() => db.getCustomerById(customer.id!)).thenReturn(customer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: BookingScreen(prefilledCustomerId: customer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Book Appointment'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Book Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Select a service station to continue.'), findsOneWidget);
    verifyNever(() => db.insertAppointment(any()));
    expect(find.byType(RadioListTile<int>), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-station-4')));
    await tester.pump();

    expect(find.text('Select a service station to continue.'), findsNothing);
    expect(
      tester
          .widget<RadioListTile<int>>(
            find.byKey(const ValueKey('booking-station-4')),
          )
          .groupValue,
      4,
    );
  });

  testWidgets('adds, edits, deletes, restores, and persists a note',
      (tester) async {
    final mockHiveService = _MockHiveService();
    Appointment? savedAppointment;
    when(mockHiveService.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(mockHiveService.watchAllServiceStations)
        .thenAnswer((_) => Stream.value([_testStation()]));
    when(mockHiveService.getAllCustomers).thenReturn(const <Customer>[]);
    when(() => mockHiveService.insertCustomer(any()))
        .thenAnswer((_) async => 1);
    when(() => mockHiveService.insertAppointment(any())).thenAnswer(
      (invocation) async {
        savedAppointment = invocation.positionalArguments.single as Appointment;
        return 1;
      },
    );

    final router = GoRouter(
      initialLocation: '/booking',
      routes: [
        GoRoute(
          path: '/booking',
          name: 'booking',
          builder: (_, __) => const BookingScreen(),
        ),
        GoRoute(
          path: '/booking/confirmation/:appointmentId',
          name: 'booking-confirmation',
          builder: (_, __) => const Scaffold(
            body: Text('Booking saved'),
          ),
        ),
        GoRoute(
          path: '/appointment/:id',
          name: 'appointment-detail',
          builder: (_, __) => const Scaffold(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const Scaffold(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiveServiceProvider.overrideWithValue(mockHiveService),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.byKey(const Key('add-appointment-note')), findsOneWidget);
    expect(find.byType(AppointmentNoteCard), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('add-appointment-note')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add-appointment-note')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('appointment-note-title-field')),
      'Preparation',
    );
    await tester.enterText(
      find.byKey(const Key('appointment-note-description-field')),
      'Arrive ten minutes early',
    );
    await tester.tap(find.byKey(const Key('save-appointment-note')));
    await tester.pumpAndSettle();

    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('Arrive ten minutes early'), findsOneWidget);
    expect(find.byType(AppointmentNoteCard), findsOneWidget);

    await tester.tap(find.byTooltip('Edit note'));
    await tester.pumpAndSettle();
    final titleField = tester.widget<TextFormField>(
      find.byKey(const Key('appointment-note-title-field')),
    );
    final descriptionField = tester.widget<TextFormField>(
      find.byKey(const Key('appointment-note-description-field')),
    );
    expect(titleField.controller!.text, 'Preparation');
    expect(descriptionField.controller!.text, 'Arrive ten minutes early');

    await tester.enterText(
      find.byKey(const Key('appointment-note-title-field')),
      'Updated preparation',
    );
    await tester.tap(find.byKey(const Key('save-appointment-note')));
    await tester.pumpAndSettle();
    expect(find.text('Updated preparation'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentNoteCard), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Undo'));
    await tester.pumpAndSettle();
    expect(find.byType(AppointmentNoteCard), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('booking-phone-field')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('booking-phone-field')),
      '+94770000000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-add-customer-pill')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('booking-quick-add-name-field')),
      'Test Customer',
    );
    await _selectTestStation(tester);
    await _tapBookingAction(tester, 'Book Appointment');

    expect(find.text('Booking saved'), findsOneWidget);
    final saved = savedAppointment!;
    expect(saved.notes, hasLength(1));
    expect(saved.notes.single.title, 'Updated preparation');
    expect(saved.notes.single.description, 'Arrive ten minutes early');
  });

  testWidgets('unmatched phone shows pill-only quick add and saves on submit',
      (tester) async {
    final mockHiveService = _MockHiveService();
    Customer? savedCustomer;
    when(mockHiveService.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(mockHiveService.watchAllServiceStations)
        .thenAnswer((_) => Stream.value([_testStation()]));
    when(mockHiveService.getAllCustomers).thenReturn(const <Customer>[]);
    when(() => mockHiveService.getCustomerByPhone(any())).thenReturn(null);
    when(() => mockHiveService.insertCustomer(any()))
        .thenAnswer((invocation) async {
      savedCustomer = invocation.positionalArguments.single as Customer;
      savedCustomer!.id = 1;
      return 1;
    });
    when(() => mockHiveService.insertAppointment(any()))
        .thenAnswer((_) async => 1);

    final router = GoRouter(
      initialLocation: '/booking',
      routes: [
        GoRoute(
          path: '/booking',
          name: 'booking',
          builder: (_, __) => const BookingScreen(),
        ),
        GoRoute(
          path: '/booking/confirmation/:appointmentId',
          name: 'booking-confirmation',
          builder: (_, __) => const Scaffold(body: Text('Booking saved')),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, __) => const Scaffold(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(mockHiveService)],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('booking-phone-field')),
      '071 234 5678',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('booking-add-customer-row')), findsOneWidget);
    expect(find.byKey(const Key('booking-add-customer-pill')), findsOneWidget);
    expect(find.byKey(const Key('booking-quick-add-card')), findsNothing);

    await tester.tap(find.byKey(const Key('booking-add-customer-row')),
        warnIfMissed: false);
    await tester.pump();
    expect(find.byKey(const Key('booking-quick-add-card')), findsNothing);

    await tester.tap(find.byKey(const Key('booking-add-customer-pill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-quick-add-card')), findsOneWidget);
    expect(find.byKey(const Key('booking-name-field')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('booking-quick-add-name-field')),
      'Nimali Silva',
    );
    expect(tester.state<FormState>(find.byType(Form).first).validate(), isTrue);
    await tester.enterText(
      find.byKey(const Key('booking-quick-add-town-field')),
      'Kandy',
    );
    await tester.tap(find.byKey(const Key('booking-quick-add-dob-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await _selectTestStation(tester);
    await _tapBookingAction(tester, 'Book Appointment');

    expect(find.text('Booking saved'), findsOneWidget);
    expect(savedCustomer, isNotNull);
    expect(savedCustomer!.name, 'Nimali Silva');
    expect(savedCustomer!.phoneNumber, '071 234 5678');
    expect(savedCustomer!.city, 'Kandy');
    expect(savedCustomer!.address, isNull);
    expect(savedCustomer!.dob, isNotNull);
  });

  testWidgets('prefilled unmatched phone opens the quick-add card',
      (tester) async {
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value([_testStation()]));
    when(db.getAllCustomers).thenReturn(const <Customer>[]);
    when(() => db.getCustomerByPhone('0771234567')).thenReturn(null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BookingScreen(prefilledPhone: '0771234567'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('booking-quick-add-card')), findsOneWidget);
    expect(find.byKey(const Key('booking-name-field')), findsNothing);
    expect(
        find.byKey(const Key('booking-existing-customer-card')), findsNothing);
  });

  testWidgets('prefilled matching phone shows the existing-customer card',
      (tester) async {
    final now = DateTime(2026, 9, 7);
    final customer = Customer()
      ..id = 10
      ..name = 'Matched Customer'
      ..phoneNumber = '0771234567'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value([_testStation()]));
    when(db.getAllCustomers).thenReturn([customer]);
    when(() => db.getCustomerByPhone('0771234567')).thenReturn(customer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BookingScreen(prefilledPhone: '0771234567'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('booking-existing-customer-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('booking-quick-add-card')), findsNothing);
    expect(find.byKey(const Key('booking-name-field')), findsNothing);
  });

  testWidgets('prefilled customer id resolves directly and clears search text',
      (tester) async {
    final now = DateTime(2026, 9, 7);
    final customer = Customer()
      ..id = 24
      ..name = 'Exact Customer'
      ..phoneNumber = '0771234567'
      ..city = 'Kandy'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(() => db.getCustomerById(24)).thenReturn(customer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BookingScreen(
            prefilledCustomerId: 24,
            prefilledPhone: 'should-not-be-used',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('booking-existing-customer-card')),
      findsOneWidget,
    );
    expect(find.text('Exact Customer'), findsOneWidget);
    expect(find.text('Kandy'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('booking-phone-field')))
          .controller!
          .text,
      isEmpty,
    );
    verify(() => db.getCustomerById(24)).called(1);
    verifyNever(() => db.getCustomerByPhone(any()));
  });

  testWidgets(
      'name search selects a customer, clears the field, and still saves',
      (tester) async {
    final now = DateTime(2026, 9, 7);
    final customer = Customer()
      ..id = 11
      ..name = 'Asha Perera'
      ..phoneNumber = '0712345678'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value([_testStation()]));
    when(db.getAllCustomers).thenReturn([customer]);
    when(() => db.getCustomerByPhone(any())).thenReturn(null);
    when(() => db.insertAppointment(any())).thenAnswer((_) async => 24);

    final router = GoRouter(
      initialLocation: '/booking',
      routes: [
        GoRoute(
          path: '/booking',
          name: 'booking',
          builder: (_, __) => const BookingScreen(),
        ),
        GoRoute(
          path: '/booking/confirmation/:appointmentId',
          name: 'booking-confirmation',
          builder: (_, __) => const Scaffold(body: Text('Booking saved')),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
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

    final searchField = tester.widget<TextFormField>(
      find.byKey(const Key('booking-phone-field')),
    );
    final editableText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('booking-phone-field')),
        matching: find.byType(EditableText),
      ),
    );
    final inputDecorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('booking-phone-field')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(editableText.keyboardType, TextInputType.text);
    expect(inputDecorator.decoration.labelText, 'Customer name or phone');
    expect(find.byKey(const Key('booking-name-field')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('booking-phone-field')),
      'Asha',
    );
    await tester.pumpAndSettle();

    expect(find.text('Asha Perera'), findsOneWidget);
    expect(find.byKey(const Key('booking-add-customer-pill')), findsNothing);

    await tester.tap(find.text('Asha Perera'));
    await tester.pumpAndSettle();

    expect(searchField.controller?.text, isEmpty);
    expect(
      find.byKey(const Key('booking-existing-customer-card')),
      findsOneWidget,
    );
    expect(tester.state<FormState>(find.byType(Form).first).validate(), isTrue);

    await _selectTestStation(tester);
    await _tapBookingAction(tester, 'Book Appointment');

    expect(find.text('Booking saved'), findsOneWidget);
    verifyNever(() => db.insertCustomer(any()));
    verify(() => db.insertAppointment(any())).called(1);
  });

  testWidgets('unresolved name is blocked and never inserted as a phone',
      (tester) async {
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(db.getAllCustomers).thenReturn(const <Customer>[]);
    when(() => db.getCustomerByPhone(any())).thenReturn(null);

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

    await tester.enterText(
      find.byKey(const Key('booking-phone-field')),
      'Unknown Customer',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('booking-add-customer-pill')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Book Appointment'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Book Appointment'));
    await tester.pump();

    expect(
      find.text(
        'Select a customer from the list, or tap "Add" to create a new one.',
      ),
      findsOneWidget,
    );
    verifyNever(() => db.insertCustomer(any()));
    verifyNever(() => db.insertAppointment(any()));
  });

  testWidgets('exact phone suppresses Add and existing selection still works',
      (tester) async {
    final now = DateTime(2026, 9, 6);
    final customer = Customer()
      ..id = 9
      ..name = 'Asha Perera'
      ..phoneNumber = '0712345678'
      ..address = '42 Temple Road'
      ..city = 'Kandy'
      ..dob = DateTime(1990, 5, 4)
      ..notes = [
        CustomerNote(
          id: 'booking-customer-note',
          title: 'Prefers text messages',
          createdAt: now,
          updatedAt: now,
        ),
        CustomerNote(
          id: 'booking-customer-note-two',
          title: 'Sensitive skin',
          description: 'Avoid strongly scented products during treatment.',
          createdAt: now,
          updatedAt: now,
        ),
      ]
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(db.getAllCustomers).thenReturn([customer]);

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
    await tester.enterText(
      find.byKey(const Key('booking-phone-field')),
      '0712345678',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-add-customer-pill')), findsNothing);

    await tester.tap(find.text('Asha Perera'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-existing-customer-card')),
        findsOneWidget);
    expect(find.byKey(const Key('booking-quick-add-card')), findsNothing);
    expect(find.text('0712345678'), findsWidgets);
    expect(find.text('Age ${currentAge(customer.dob!)}'), findsOneWidget);
    expect(find.text('Kandy'), findsOneWidget);
    expect(find.text('Customer notes'), findsOneWidget);
    expect(find.text('2 notes • Swipe'), findsOneWidget);
    expect(find.text('Prefers text messages'), findsOneWidget);
    expect(find.text('Sensitive skin'), findsOneWidget);

    final customerCardFinder =
        find.byKey(const Key('booking-existing-customer-card'));
    expect(tester.widget(customerCardFinder), isA<AppSurfaceCard>());
    final surface = tester.widget<Container>(
      find
          .descendant(
            of: customerCardFinder,
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(AppSpacing.radiusLg));
    expect(decoration.boxShadow, anyOf(isNull, isEmpty));

    final notesCarousel = tester.widget<ListView>(
      find.byKey(const Key('booking-customer-notes-carousel')),
    );
    expect(notesCarousel.scrollDirection, Axis.horizontal);
  });

  testWidgets('requires a non-empty note title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const BookingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('add-appointment-note')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add-appointment-note')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('appointment-note-title-field')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('save-appointment-note')));
    await tester.pump();

    expect(find.text('Enter a note title'), findsOneWidget);
  });

  testWidgets('edit mode reloads persisted structured notes', (tester) async {
    final now = DateTime.now();
    final appointment = Appointment()
      ..startTime = now.add(const Duration(days: 1))
      ..endTime = now.add(const Duration(days: 1, hours: 1))
      ..status = 'upcoming'
      ..notes = [
        AppointmentNote(
          id: 'persisted-note',
          title: 'Preparation',
          description: 'Bring the previous prescription',
          createdAt: now,
          updatedAt: now,
        ),
      ]
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final appointmentId = await tester.runAsync(
      () => hiveService.insertAppointment(appointment),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiveServiceProvider.overrideWithValue(hiveService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: BookingScreen(appointmentId: appointmentId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Preparation'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Preparation'), findsOneWidget);
    expect(find.text('Bring the previous prescription'), findsOneWidget);
    expect(find.byType(AppointmentNoteCard), findsOneWidget);
  });

  testWidgets('edit mode still saves its loaded customer', (tester) async {
    final now = DateTime.now();
    final customer = Customer()
      ..id = 12
      ..name = 'Loaded Customer'
      ..phoneNumber = '0777654321'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final appointment = Appointment()
      ..id = 31
      ..customerId = customer.id
      ..stationId = 4
      ..startTime = now.add(const Duration(days: 1))
      ..endTime = now.add(const Duration(days: 1, hours: 1))
      ..status = 'upcoming'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value([_testStation()]));
    when(() => db.getAppointmentById(appointment.id!)).thenReturn(appointment);
    when(() => db.getCustomerById(customer.id!)).thenReturn(customer);
    when(() => db.getCustomerByPhone(any())).thenReturn(customer);
    when(() => db.getAppointmentServicesForAppointment(appointment.id!))
        .thenReturn(const <AppointmentService>[]);
    when(() => db.updateAppointment(appointment.id!, any()))
        .thenAnswer((_) async => true);
    when(() => db.deleteAppointmentServicesForAppointment(appointment.id!))
        .thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/booking/edit/${appointment.id}',
      routes: [
        GoRoute(
          path: '/booking/edit/:id',
          name: 'edit-booking',
          builder: (_, state) => BookingScreen(
            appointmentId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/appointment/:id',
          name: 'appointment-detail',
          builder: (_, __) => const Scaffold(
            body: Text('Appointment updated'),
          ),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
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

    expect(
      find.byKey(const Key('booking-existing-customer-card')),
      findsOneWidget,
    );
    await _tapBookingAction(tester, 'Update Appointment');

    expect(find.text('Appointment updated'), findsOneWidget);
    final captured = verify(
      () => db.updateAppointment(appointment.id!, captureAny()),
    ).captured.single as Appointment;
    expect(captured.customerId, customer.id);
  });

  testWidgets('merged search remains usable with large text in dark mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final customer = Customer()
      ..id = 13
      ..name = 'Large Text Customer'
      ..phoneNumber = '0777000111'
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final db = _MockHiveService();
    when(db.watchAllServices)
        .thenAnswer((_) => Stream.value(const <Service>[]));
    when(db.watchAllServiceStations)
        .thenAnswer((_) => Stream.value(const <ServiceStation>[]));
    when(() => db.getCustomerByPhone(customer.phoneNumber))
        .thenReturn(customer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [hiveServiceProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: BookingScreen(prefilledPhone: customer.phoneNumber),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byTooltip('Clear selected customer')).shortestSide,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('booking-phone-field'))).shortestSide,
      greaterThanOrEqualTo(48),
    );

    await tester.binding.setSurfaceSize(const Size(667, 375));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('note card remains usable on a small dark-mode layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    const editKey = Key('edit-appointment-note-accessible-note');
    const deleteKey = Key('delete-appointment-note-accessible-note');
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AppointmentNoteCard(
              note: AppointmentNote(
                id: 'accessible-note',
                title: 'Detailed preparation and accessibility information',
                description: 'A longer description that must remain readable.',
                createdAt: now,
                updatedAt: now,
              ),
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(editKey)), const Size(48, 48));
    expect(tester.getSize(find.byKey(deleteKey)), const Size(48, 48));

    await tester.binding.setSurfaceSize(const Size(667, 375));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail and confirmation screens render structured notes',
      (tester) async {
    final now = DateTime.now();
    final appointment = Appointment()
      ..startTime = now.add(const Duration(days: 1))
      ..endTime = now.add(const Duration(days: 1, hours: 1))
      ..status = 'confirmed'
      ..notes = [
        AppointmentNote(
          id: 'detail-note',
          title: 'Client request',
          description: 'Use the fragrance-free option',
          createdAt: now,
          updatedAt: now,
        ),
      ]
      ..createdAt = now
      ..updatedAt = now
      ..synced = false;
    final appointmentId = await tester.runAsync(
      () => hiveService.insertAppointment(appointment),
    );

    Future<void> pumpScreen(Widget screen) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(hiveService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpScreen(
      AppointmentDetailScreen(appointmentId: appointmentId!),
    );
    await tester.scrollUntilVisible(
      find.text('Client request'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Use the fragrance-free option'), findsOneWidget);
    expect(find.byTooltip('Edit note'), findsNothing);

    await pumpScreen(
      BookingConfirmationScreen(appointmentId: appointmentId),
    );
    await tester.scrollUntilVisible(
      find.text('Client request'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Use the fragrance-free option'), findsOneWidget);
    expect(find.byTooltip('Edit note'), findsNothing);
  });
}
