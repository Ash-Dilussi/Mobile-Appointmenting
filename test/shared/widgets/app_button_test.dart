import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookly/shared/widgets/app_button.dart';
import 'package:bookly/shared/widgets/app_icon_button.dart';

void main() {
  testWidgets('AppButton suppresses rapid duplicate taps', (tester) async {
    var invocations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            onPressed: () => invocations++,
            child: const Text('Continue'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Continue'));

    expect(invocations, 1);
  });

  testWidgets('AppIconButton suppresses rapid duplicate taps', (tester) async {
    var invocations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => invocations++,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Go back'));
    await tester.tap(find.byTooltip('Go back'));

    expect(invocations, 1);
  });

  testWidgets('button press motion is disabled by accessibility setting',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AppButton(
              onPressed: _noop,
              child: Text('Continue'),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pump();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
    expect(scale.scale, 1);

    await gesture.up();
  });
}

void _noop() {}
