import 'package:flutter/foundation.dart';

typedef TapGuardClock = DateTime Function();

/// Suppresses accidental duplicate gestures without changing the callback's
/// single-tap behavior.
class TapGuard {
  TapGuard({
    this.cooldown = const Duration(milliseconds: 500),
    TapGuardClock? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration cooldown;
  final TapGuardClock _clock;
  DateTime? _lastInvocation;

  bool run(VoidCallback callback) {
    if (!tryAcquire()) return false;
    callback();
    return true;
  }

  bool tryAcquire() {
    final now = _clock();
    final lastInvocation = _lastInvocation;
    if (lastInvocation != null && now.difference(lastInvocation) < cooldown) {
      return false;
    }
    _lastInvocation = now;
    return true;
  }

  void reset() => _lastInvocation = null;
}
