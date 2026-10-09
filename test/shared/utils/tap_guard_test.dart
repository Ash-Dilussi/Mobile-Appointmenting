import 'package:bookly/shared/utils/tap_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suppresses rapid invocations and allows calls after cooldown', () {
    var now = DateTime(2026, 9, 16, 12);
    var executions = 0;
    final guard = TapGuard(
      cooldown: const Duration(milliseconds: 500),
      clock: () => now,
    );

    expect(guard.run(() => executions++), isTrue);
    expect(guard.run(() => executions++), isFalse);
    expect(executions, 1);

    now = now.add(const Duration(milliseconds: 500));

    expect(guard.run(() => executions++), isTrue);
    expect(executions, 2);
  });
}
