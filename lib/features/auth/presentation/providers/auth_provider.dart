import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

// Local user model for demo auth
class LocalUser {
  final String uid;
  final String email;

  LocalUser({required this.uid, required this.email});
}

// Auth state
enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final LocalUser? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    LocalUser? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

// Auth state notifier - local demo implementation
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _storage;

  AuthNotifier(this._storage) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(status: AuthStatus.loading);

    // Check for stored session
    final token = await _storage.read(key: 'auth_token');
    final storedEmail = await _storage.read(key: 'user_email');

    if (token != null && storedEmail != null) {
      // User was previously logged in
      state = AuthState(
        status: AuthStatus.authenticated,
        user: LocalUser(uid: 'local-user', email: storedEmail),
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      // Local demo auth - accept any valid email format with 6+ char password
      if (email.isEmpty || !email.contains('@')) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Invalid email address',
        );
        return;
      }
      if (password.length < 6) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Password should be at least 6 characters',
        );
        return;
      }

      // Store token
      await _storage.write(key: 'auth_token', value: 'valid');
      await _storage.write(key: 'user_email', value: email);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: LocalUser(uid: 'local-user', email: email),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: 'An unexpected error occurred',
      );
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      // Local demo auth - accept any valid email format with 6+ char password
      if (email.isEmpty || !email.contains('@')) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Invalid email address',
        );
        return;
      }
      if (password.length < 6) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Password should be at least 6 characters',
        );
        return;
      }

      await _storage.write(key: 'auth_token', value: 'valid');
      await _storage.write(key: 'user_email', value: email);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: LocalUser(uid: 'local-user', email: email),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: 'An unexpected error occurred',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      error: 'Google Sign-In not configured in demo mode',
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'user_email');
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }
}

// Auth state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(storage);
});
