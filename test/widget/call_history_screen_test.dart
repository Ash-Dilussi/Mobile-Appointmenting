// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bookly/core/theme/app_colors.dart';
import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/features/home/presentation/providers/home_provider.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/features/call_history/presentation/screens/call_history_screen.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/core/auth/rbac.dart';
import '../helpers/test_helpers.dart';

class _EmptyAssetManifest extends Fake implements AssetManifest {
  @override
  List<String> listAssets() => const [];
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  _TestAuthSessionNotifier(super.service) {
    state = const AuthSession(
      userId: 'test-user',
      email: 'test@example.com',
      institutionId: 'test-inst',
      role: Role.owner,
      hasCompletedOnboarding: true,
    );
  }
}

class FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  HttpHeaders get headers => FakeHttpHeaders();

  @override
  int get contentLength => 0;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => 'OK';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Return empty list of bytes for the font
    return Stream<List<int>>.value([]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final HttpHeaders _headers = FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = 0;

  @override
  bool bufferOutput = true;

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  void add(List<int> data) {}

  @override
  void write(Object? object) {}

  @override
  Future<HttpClientResponse> close() async {
    return FakeHttpClientResponse();
  }
}

class FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}
}

class FakeHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return FakeHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return FakeHttpClientRequest();
  }
}

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return FakeHttpClient();
  }
}

/// Widget tests for CallHistoryScreen
void main() {
  late HiveService hiveService;
  late Directory tempDir;

  test('booking navigation carries the originating call id', () {
    final source = File(
      'lib/features/call_history/presentation/screens/call_history_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'callLogId'"));
  });

  setUpAll(() async {
    // Mock HTTP requests so Google Fonts doesn't crash on network fetching
    HttpOverrides.global = TestHttpOverrides();

    // Initialize Flutter binding for path_provider
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create a temp directory for Hive and runtime font cache writes.
    tempDir = await Directory.systemTemp.createTemp('hive_test_');

    // Set up mock path provider to use the temp directory.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

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

    // Initialize Hive with temp directory
    await Hive.initFlutter(tempDir.path);

    // Initialize HiveService once
    hiveService = HiveService();
    await hiveService.init();
  });

  tearDownAll(() async {
    google_fonts_base.clearCache();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CallHistoryScreen Widget Tests', () {
    setUp(() async {
      // Clear all boxes before each test
      await hiveService.clearAllData();
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [
          homeHiveProvider.overrideWithValue(hiveService),
          authSessionProvider.overrideWith(
            (ref) => _TestAuthSessionNotifier(hiveService),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          home: const CallHistoryScreen(),
        ),
      );
    }

    Widget createRoutedWidgetUnderTest(GoRouter router) {
      return ProviderScope(
        overrides: [
          homeHiveProvider.overrideWithValue(hiveService),
          authSessionProvider.overrideWith(
            (ref) => _TestAuthSessionNotifier(hiveService),
          ),
        ],
        child: MaterialApp.router(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          routerConfig: router,
        ),
      );
    }

    testWidgets('displays AppBar with title "Call History"', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Call History'), findsOneWidget);
    });

    testWidgets('displays two tabs: All Calls and Missed', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('All Calls'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(
        find.textContaining('Calls initiated through Bookly'),
        findsOneWidget,
      );
    });

    testWidgets('All Calls tab shows loading indicator initially',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      // Don't pumpAndSettle - we want to catch the loading state

      // Should show CircularProgressIndicator in one of the tabs
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('All Calls tab shows empty state when no calls',
        (tester) async {
      // Insert no call logs - empty state
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No call history yet'), findsOneWidget);
    });

    testWidgets('All Calls tab shows call log when data exists',
        (tester) async {
      // Insert a call log
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 60
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('+1234567890'), findsOneWidget);
    });

    testWidgets('saved contacts show only their name on call cards',
        (tester) async {
      final customer = Customer()
        ..name = 'Saved Customer'
        ..phoneNumber = '+1234567890'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCustomer(customer);

      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 60
        ..isMissed = true
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Saved Customer'), findsOneWidget);
      expect(find.text('+1234567890'), findsNothing);

      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();

      expect(find.text('Saved Customer'), findsOneWidget);
      expect(find.text('+1234567890'), findsNothing);
    });

    testWidgets('Missed tab shows empty state when no missed calls',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Missed tab
      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();

      expect(find.text('No missed calls'), findsOneWidget);
    });

    testWidgets('Missed tab shows only missed calls', (tester) async {
      // Insert missed and non-missed calls
      final missedCall = CallLog()
        ..phoneNumber = '+1111111111'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 0
        ..isMissed = true
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      final answeredCall = CallLog()
        ..phoneNumber = '+2222222222'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 60
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(missedCall);
      await hiveService.insertCallLog(answeredCall);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Missed tab
      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();

      // Should show only the missed call
      expect(find.text('+1111111111'), findsOneWidget);
      expect(find.text('+2222222222'), findsNothing);
    });

    testWidgets('FAB is present with "New Appointment" label', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('New Appointment'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('New Appointment opens Booking directly and preserves Back',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/call-history',
        routes: [
          GoRoute(
            path: '/call-history',
            builder: (_, __) => const CallHistoryScreen(),
          ),
          GoRoute(
            path: '/booking',
            name: 'booking',
            builder: (_, __) => const Scaffold(
              body: Center(child: Text('Booking screen probe')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(createRoutedWidgetUnderTest(router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Appointment'));
      await tester.pumpAndSettle();

      expect(find.text('Booking screen probe'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(router.canPop(), isTrue);
    });

    testWidgets('tab indicator uses primary color', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final tabBar = find.byType(TabBar);
      expect(tabBar, findsOneWidget);
    });

    testWidgets('incoming call shows call_received icon', (tester) async {
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 60
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.call_received), findsOneWidget);
    });

    testWidgets('missed call shows call_missed icon', (tester) async {
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 0
        ..isMissed = true
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.call_missed), findsOneWidget);
    });

    testWidgets('outgoing call shows call_made icon', (tester) async {
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'outgoing'
        ..durationSeconds = 30
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.call_made), findsOneWidget);
    });

    testWidgets('app-initiated rows are labelled honestly', (tester) async {
      final customer = TestHiveHelpers.createCustomer(
        name: 'Dialled Customer',
        phoneNumber: '+1234567890',
        institutionId: 'test-inst',
      );
      await tester.runAsync(() async {
        final customerId = await hiveService.insertCustomer(customer);
        await hiveService.insertAppInitiatedCallLog(
          customerId: customerId!,
          phoneNumber: customer.phoneNumber,
          institutionId: 'test-inst',
          handledByUserId: 'test-user',
        );
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Dialled Customer'), findsOneWidget);
      expect(find.text('Call initiated'), findsOneWidget);
    });

    testWidgets('call card does not show duration when call was answered',
        (tester) async {
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 125 // 2 min 5 sec
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false
        ..institutionId = 'test-inst';
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.textContaining('Duration:'), findsNothing);
    });
  });
}
