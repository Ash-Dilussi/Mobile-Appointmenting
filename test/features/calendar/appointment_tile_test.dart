import 'package:bookly/core/database/collections/appointment.dart';
import 'package:bookly/core/theme/app_theme.dart';
import 'package:bookly/core/theme/service_color_palette.dart';
import 'package:bookly/shared/widgets/appointment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Appointment appointment({String status = 'confirmed'}) => Appointment()
    ..id = 12
    ..startTime = DateTime(2026, 4, 18, 15, 45)
    ..endTime = DateTime(2026, 4, 18, 17, 15)
    ..status = status
    ..createdAt = DateTime(2026, 4, 1)
    ..updatedAt = DateTime(2026, 4, 1)
    ..synced = false;

  Widget subject({
    String status = 'confirmed',
    String customerName = 'A very long customer name that must truncate',
    String locationName = 'A very long location name that must truncate',
    List<AppointmentTileService> services = const <AppointmentTileService>[],
    VoidCallback? onTap,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 375,
            child: AppointmentTile(
              appointment: appointment(status: status),
              customerName: customerName,
              services: services,
              totalDurationMinutes: 90,
              locationName: locationName,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the specified hierarchy without service-name text',
      (tester) async {
    await tester.pumpWidget(
      subject(
        services: <AppointmentTileService>[
          AppointmentTileService(
            name: 'Haircut',
            durationMinutes: 30,
            colorValue: ServiceColorPalette.options.first.argbValue,
          ),
          AppointmentTileService(
            name: 'Colour treatment',
            durationMinutes: 60,
            colorValue: ServiceColorPalette.options.last.argbValue,
          ),
        ],
      ),
    );

    expect(find.text('Confirmed'), findsOneWidget);
    expect(
      find.text('A very long customer name that must truncate'),
      findsOneWidget,
    );
    expect(find.text('90 min'), findsOneWidget);
    expect(find.text('April'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('3:45 PM'), findsOneWidget);
    expect(find.text('Haircut'), findsNothing);
    expect(find.text('Colour treatment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'uses a neutral fallback for an unknown status and handles no services',
      (tester) async {
    await tester.pumpWidget(subject(status: 'unexpected'));

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('90 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole surface invokes its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(subject(onTap: () => tapped = true));

    await tester.tap(find.byType(AppointmentTile));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('remains stable on a small phone with large text',
      (tester) async {
    await tester.pumpWidget(
      subject(
        textScaler: const TextScaler.linear(2),
        services: <AppointmentTileService>[
          AppointmentTileService(
            name: 'Haircut',
            durationMinutes: 90,
            colorValue: ServiceColorPalette.options.first.argbValue,
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
