import 'package:bookly/shared/widgets/app_date_picker_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPickerHost(
    WidgetTester tester, {
    required ValueChanged<DateTime?> onCompleted,
    DateTime? initialDate,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showAppDatePicker(
                    context: context,
                    initialDate: initialDate ?? DateTime(2024, 5, 10, 18),
                    minimumDate: DateTime(2024, 1, 1, 9),
                    maximumDate: DateTime(2024, 12, 31, 21),
                    title: 'Select test date',
                  );
                  onCompleted(result);
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpTimePickerHost(
    WidgetTester tester, {
    required ValueChanged<TimeOfDay?> onCompleted,
    required bool use24HourFormat,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: use24HourFormat,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showAppTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 23, minute: 7),
                  );
                  onCompleted(result);
                },
                child: const Text('Open time picker'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Cancel discards the pending wheel value', (tester) async {
    DateTime? completedValue = DateTime(2000);
    var didComplete = false;
    await pumpPickerHost(
      tester,
      onCompleted: (value) {
        completedValue = value;
        didComplete = true;
      },
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    picker.onDateTimeChanged(DateTime(2024, 8, 20));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(didComplete, isTrue);
    expect(completedValue, isNull);
  });

  testWidgets('Done commits the pending date and keeps native wheel theming',
      (tester) async {
    DateTime? completedValue;
    await pumpPickerHost(tester,
        onCompleted: (value) => completedValue = value);

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.initialDateTime, DateTime(2024, 5, 10));
    expect(picker.minimumDate, DateTime(2024, 1, 1));
    expect(picker.maximumDate, DateTime(2024, 12, 31));

    final cupertinoTheme = tester.widget<CupertinoTheme>(
      find.byKey(const Key('app-date-picker-cupertino-theme')),
    );
    final materialContext = tester.element(find.text('Select test date'));
    expect(
      cupertinoTheme.data.primaryColor,
      Theme.of(materialContext).colorScheme.primary,
    );

    picker.onDateTimeChanged(DateTime(2024, 8, 20, 12));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(completedValue, DateTime(2024, 8, 20));
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('out-of-range initial dates are clamped safely', (tester) async {
    await pumpPickerHost(
      tester,
      initialDate: DateTime(2030),
      onCompleted: (_) {},
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.initialDateTime, DateTime(2024, 12, 31));
  });

  testWidgets('tapping the barrier returns null', (tester) async {
    DateTime? completedValue = DateTime(2000);
    var didComplete = false;
    await pumpPickerHost(
      tester,
      onCompleted: (value) {
        completedValue = value;
        didComplete = true;
      },
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(didComplete, isTrue);
    expect(completedValue, isNull);
  });

  testWidgets('remains usable in dark landscape with large text',
      (tester) async {
    tester.view.physicalSize = const Size(667, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DateTime? completedValue;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                completedValue = await showAppDatePicker(
                  context: context,
                  initialDate: DateTime(2024, 5, 10),
                  minimumDate: DateTime(2024),
                  maximumDate: DateTime(2025),
                  title: 'Select an accessible date',
                );
              },
              child: const Text('Open accessible picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open accessible picker'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(completedValue, DateTime(2024, 5, 10));
  });

  testWidgets('time wheel follows 24-hour format and Cancel discards changes',
      (tester) async {
    TimeOfDay? completedValue = const TimeOfDay(hour: 1, minute: 1);
    var didComplete = false;
    await pumpTimePickerHost(
      tester,
      use24HourFormat: true,
      onCompleted: (value) {
        completedValue = value;
        didComplete = true;
      },
    );

    await tester.tap(find.text('Open time picker'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.mode, CupertinoDatePickerMode.time);
    expect(picker.use24hFormat, isTrue);
    expect(picker.minuteInterval, 1);
    expect(picker.initialDateTime.hour, 23);
    expect(picker.initialDateTime.minute, 7);

    picker.onDateTimeChanged(DateTime(2026, 1, 1, 9, 42));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(didComplete, isTrue);
    expect(completedValue, isNull);
  });

  testWidgets('time wheel follows 12-hour format and Done returns TimeOfDay',
      (tester) async {
    TimeOfDay? completedValue;
    await pumpTimePickerHost(
      tester,
      use24HourFormat: false,
      onCompleted: (value) => completedValue = value,
    );

    await tester.tap(find.text('Open time picker'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.use24hFormat, isFalse);
    picker.onDateTimeChanged(DateTime(2026, 1, 1, 9, 42));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(completedValue, const TimeOfDay(hour: 9, minute: 42));
  });
}
