import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/hive/hive_initializer.dart';
import 'auth_providers.dart';
import 'auth_session_provider.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  newUser,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final String? errorCode;
  final String? errorMessage;

  const AuthState._({
    required this.status,
    this.user,
    this.errorCode,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState._(status: AuthStatus.initial);
  factory AuthState.loading() => const AuthState._(status: AuthStatus.loading);
  factory AuthState.unauthenticated() =>
      const AuthState._(status: AuthStatus.unauthenticated);
  factory AuthState.authenticated(AuthUser user) =>
      AuthState._(status: AuthStatus.authenticated, user: user);
  factory AuthState.newUser(AuthUser user) =>
      AuthState._(status: AuthStatus.newUser, user: user);
  factory AuthState.error(String code, [String? message]) =>
      AuthState._(status: AuthStatus.error, errorCode: code, errorMessage: message);

  bool get isLoading =>
      status == AuthStatus.loading || status == AuthStatus.initial;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(AuthState.initial()) {
    _onStartup();
  }

  Future<void> _onStartup() async {
    // AppLaunchNotifier handles the cold-start decision.
    // AuthNotifier listens for mid-session state changes only.
    _repository.authStateChanges.listen(
      (authUser) {
        if (authUser == null) {
          // Session expired or remote sign-out — clear and redirect
          state = AuthState.unauthenticated();
          return;
        }
        // Session reconfirmed (cache hit or Firestore refresh)
        _ref.read(authSessionProvider.notifier).loadSessionFromAuthUser(authUser);
        state = AuthState.authenticated(authUser);
      },
      onError: (e) => state = AuthState.error(e.toString()),
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = AuthState.loading();
    try {
      final user = await _repository.signInWithEmail(
          email: email, password: password);
      _routeByInstitution(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.code, e.message);
    } catch (e) {
      state = AuthState.error('unknown', e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState.loading();
    try {
      final user = await _repository.signInWithGoogle();
      _routeByInstitution(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.code, e.message);
    } catch (e) {
      state = AuthState.error('unknown', e.toString());
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = AuthState.loading();
    try {
      final user = await _repository.registerWithEmail(
          email: email, password: password, displayName: displayName);
      _routeByInstitution(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.code, e.message);
    } catch (e) {
      state = AuthState.error('unknown', e.toString());
    }
  }

  Future<void> signOut() async {
    state = AuthState.loading();
    // Clear cache before Firebase call — prevents race with authStateChanges null emission
    await HiveInitializer.clearCachedUser();
    _ref.read(authSessionProvider.notifier).clearSession();
    await _repository.signOut();
    state = AuthState.unauthenticated();
  }

  Future<void> onInstitutionLinked({
    required String institutionId,
    required UserRole role,
  }) async {
    await _repository.linkUserToInstitution(
        institutionId: institutionId, role: role);
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      state = AuthState.unauthenticated();
    }
  }

  void _routeByInstitution(AuthUser? user) {
    if (user == null) {
      state = AuthState.unauthenticated();
    } else if (user.isLinkedToInstitution) {
      state = AuthState.authenticated(user);
    } else {
      state = AuthState.newUser(user);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});