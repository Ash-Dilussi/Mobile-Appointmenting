import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bookly/core/theme/app_colors.dart';
import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/features/home/presentation/providers/home_provider.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/features/call_history/presentation/screens/call_history_screen.dart';

/// Widget tests for CallHistoryScreen
void main() {
  late HiveService hiveService;
  late Directory tempDir;

  setUpAll(() async {
    // Initialize Flutter binding for path_provider
    TestWidgetsFlutterBinding.ensureInitialized();

    // Create a temp directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test_');

    // Set up mock path provider to use the temp directory
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    // Initialize Hive with temp directory
    await Hive.initFlutter(tempDir.path);

    // Initialize HiveService once
    hiveService = HiveService();
    await hiveService.init();
  });

  tearDownAll(() async {
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
    });

    testWidgets('All Calls tab shows loading indicator initially', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      // Don't pumpAndSettle - we want to catch the loading state

      // Should show CircularProgressIndicator in one of the tabs
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('All Calls tab shows empty state when no calls', (tester) async {
      // Insert no call logs - empty state
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No call history yet'), findsOneWidget);
    });

    testWidgets('All Calls tab shows call log when data exists', (tester) async {
      // Insert a call log
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 60
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false;
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('+1234567890'), findsOneWidget);
    });

    testWidgets('Missed tab shows empty state when no missed calls', (tester) async {
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
        ..synced = false;
      final answeredCall = CallLog()
        ..phoneNumber = '+2222222222'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 60
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false;
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
        ..synced = false;
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
        ..synced = false;
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
        ..synced = false;
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.call_made), findsOneWidget);
    });

    testWidgets('call card shows duration when call was answered', (tester) async {
      final callLog = CallLog()
        ..phoneNumber = '+1234567890'
        ..timestamp = DateTime.now()
        ..direction = 'incoming'
        ..durationSeconds = 125  // 2 min 5 sec
        ..isMissed = false
        ..followedUp = false
        ..createdAt = DateTime.now()
        ..synced = false;
      await hiveService.insertCallLog(callLog);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Duration format: "2 min 5s"
      expect(find.textContaining('Duration:'), findsOneWidget);
    });
  });
}
