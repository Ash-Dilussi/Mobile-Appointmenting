import 'package:bookly/shared/widgets/app_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('incoming missed calls render Missed instead of Incoming',
      (tester) async {
    final colors = ColorScheme.fromSeed(seedColor: Colors.orange);
    final presentation = callLogStatusPresentation(
      isMissed: true,
      direction: 'incoming',
      colors: colors,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colors),
        home: Scaffold(
          body: AppBadge(presentation: presentation),
        ),
      ),
    );

    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Incoming'), findsNothing);
  });
}
