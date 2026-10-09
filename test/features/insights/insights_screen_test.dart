import 'dart:io';

import 'package:bookly/features/insights/presentation/screens/insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('officer boundary never builds owner-only content',
      (tester) async {
    var builderInvoked = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: InsightsOwnerSectionBoundary(
            canViewOwnerSections: false,
            builder: (context, ref) {
              builderInvoked = true;
              return const Text('Owner-only KPI');
            },
          ),
        ),
      ),
    );

    expect(builderInvoked, isFalse);
    expect(find.text('Owner-only KPI'), findsNothing);
  });

  testWidgets('owner boundary builds owner-only content', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: InsightsOwnerSectionBoundary(
            canViewOwnerSections: true,
            builder: (context, ref) => const Text('Owner-only KPI'),
          ),
        ),
      ),
    );

    expect(find.text('Owner-only KPI'), findsOneWidget);
  });

  test('Insights route derives owner access from the authenticated session',
      () {
    final routerSource =
        File('lib/core/router/app_router.dart').readAsStringSync();

    expect(routerSource, contains('canViewOwnerSections:'));
    expect(routerSource, contains('ref.read(authSessionProvider)?.isOwner'));
  });
}
