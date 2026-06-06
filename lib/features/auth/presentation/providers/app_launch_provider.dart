import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/hive/hive_initializer.dart';
import '../../domain/entities/auth_user.dart';
import 'auth_session_provider.dart';

/// Sealed class representing every possible startup outcome.
/// Replaces ad-hoc boolean checks scattered across the notifier.
sealed class AppLaunchState {
  const AppLaunchState();
}

/// Initial state while the splash screen is running its minimum display timer
class AppLaunchChecking extends AppLaunchState {
  const AppLaunchChecking();
}

/// Cache found and valid. Take user to app home via entrance animation.
class AppLaunchAuthenticated extends AppLaunchState {
  final AuthUser user;
  const AppLaunchAuthenticated(this.user);
}

/// No cache or Firebase returned null. Take user to login via entrance animation.
class AppLaunchUnauthenticated extends AppLaunchState {
  const AppLaunchUnauthenticated();
}

/// Something went wrong (corrupt cache, Hive read error).
class AppLaunchError extends AppLaunchState {
  final String message;
  const AppLaunchError(this.message);
}

/// Notifier that owns the startup decision.
/// Runs once per process lifecycle, resolves to a terminal state, and never changes after that.
class AppLaunchNotifier extends StateNotifier<AppLaunchState> {
  final AuthSessionNotifier _sessionNotifier;
  static const _minSplashDuration = Duration(milliseconds: 1200);

  AppLaunchNotifier(this._sessionNotifier)
      : super(const AppLaunchChecking()) {
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      // Run the minimum splash display and cache check in parallel
      final results = await Future.wait([
        Future.delayed(_minSplashDuration),
        _checkCache(),
      ]);

      final authUser = results[1] as AuthUser?;

      if (authUser != null) {
        await _sessionNotifier.loadSessionFromAuthUser(authUser);
        state = AppLaunchAuthenticated(authUser);
      } else {
        state = const AppLaunchUnauthenticated();
      }
    } catch (e) {
      state = AppLaunchError(e.toString());
    }
  }

  Future<AuthUser?> _checkCache() async {
    // Primary: try Hive cache (synchronous, instant)
    final cached = HiveInitializer.readCachedUser();
    if (cached != null) return cached.toAuthUser();

    // No cache → go straight to login, don't wait for Firebase
    return null;
  }
}

final appLaunchProvider =
    StateNotifierProvider<AppLaunchNotifier, AppLaunchState>((ref) {
  return AppLaunchNotifier(
    ref.read(authSessionProvider.notifier),
  );
});