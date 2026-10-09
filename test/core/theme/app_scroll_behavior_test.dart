import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/core/theme/app_scroll_behavior.dart';

void main() {
  testWidgets('uses bouncing physics for app scrollables', (tester) async {
    late ScrollPhysics physics;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            physics = const AppScrollBehavior().getScrollPhysics(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(physics, isA<BouncingScrollPhysics>());
    expect(physics.parent, isA<AlwaysScrollableScrollPhysics>());
  });
}
