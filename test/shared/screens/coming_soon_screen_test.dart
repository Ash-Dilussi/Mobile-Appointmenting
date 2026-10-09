import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:bookly/shared/screens/coming_soon_screen.dart';

void main() {
  testWidgets('shows the requested feature and returns to the previous screen',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.push('/coming-soon'),
                child: const Text('Open placeholder'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/coming-soon',
          builder: (context, state) =>
              const ComingSoonScreen(featureName: 'Notifications'),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open placeholder'));
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Notifications is coming soon'), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);

    await tester.tap(find.text('Go Back'));
    await tester.pumpAndSettle();

    expect(find.text('Open placeholder'), findsOneWidget);
  });

  testWidgets('remains usable with large text on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/coming-soon',
      routes: [
        GoRoute(
          path: '/coming-soon',
          builder: (context, state) =>
              const ComingSoonScreen(featureName: 'Privacy Policy'),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Privacy Policy is coming soon'), findsOneWidget);
    expect(find.text('Go Back'), findsOneWidget);
  });
}
