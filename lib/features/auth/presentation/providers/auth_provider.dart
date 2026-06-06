import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

// Secure storage keys for profile data
const String _keyUserName = 'user_name';
const String _keyUserPhone = 'user_phone';

// Local user model for demo auth
class LocalUser {
  final String uid;
  final String email;
  final String name;
  final String? phone;

  LocalUser({
    required this.uid,
    required this.email,
    this.name = '',
    this.phone,
  });

  LocalUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? phone,
  }) {
    return LocalUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }
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
    final storedName = await _storage.read(key: _keyUserName) ?? '';
    final storedPhone = await _storage.read(key: _keyUserPhone);

    if (token != null && storedEmail != null) {
      // User was previously logged in
      state = AuthState(
        status: AuthStatus.authenticated,
        user: LocalUser(uid: 'local-user', email: storedEmail, name: storedName, phone: storedPhone),
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

      // Verify password against stored hash
      final storedPasswordHash = await _storage.read(key: 'user_password_hash');
      if (storedPasswordHash != null) {
        // User has set a password before, verify it
        final inputHash = _hashPassword(password);
        if (inputHash != storedPasswordHash) {
          state = const AuthState(
            status: AuthStatus.unauthenticated,
            error: 'Incorrect password',
          );
          return;
        }
      }

      // Store token
      await _storage.write(key: 'auth_token', value: 'valid');
      await _storage.write(key: 'user_email', value: email);

      // Load profile data
      final storedName = await _storage.read(key: _keyUserName) ?? '';
      final storedPhone = await _storage.read(key: _keyUserPhone);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: LocalUser(uid: 'local-user', email: email, name: storedName, phone: storedPhone),
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

      // Store password hash for password reset capability
      await _storage.write(key: 'user_password_hash', value: _hashPassword(password));
      await _storage.write(key: 'auth_token', value: 'valid');
      await _storage.write(key: 'user_email', value: email);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: LocalUser(uid: 'local-user', email: email, name: '', phone: null),
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
      await _storage.delete(key: _keyUserName);
      await _storage.delete(key: _keyUserPhone);
      // Keep password hash for password reset capability
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Update user profile (name and/or phone)
  Future<void> updateProfile({String? name, String? phone}) async {
    state = state.copyWith(error: null);

    try {
      if (name != null && name.isNotEmpty) {
        await _storage.write(key: _keyUserName, value: name);
      }
      if (phone != null) {
        if (phone.isEmpty) {
          await _storage.delete(key: _keyUserPhone);
        } else {
          await _storage.write(key: _keyUserPhone, value: phone);
        }
      }

      final currentUser = state.user;
      if (currentUser != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: currentUser.copyWith(
            name: name ?? currentUser.name,
            phone: phone != null && phone.isNotEmpty ? phone : null,
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to update profile');
    }
  }

  /// Change password - verifies current password first
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    state = state.copyWith(error: null);

    try {
      // Verify current password
      final storedPasswordHash = await _storage.read(key: 'user_password_hash');
      if (storedPasswordHash == null) {
        state = state.copyWith(error: 'No password set. Please sign in again.');
        return false;
      }

      final inputHash = _hashPassword(currentPassword);
      if (inputHash != storedPasswordHash) {
        state = state.copyWith(error: 'Current password is incorrect');
        return false;
      }

      // Validate new password
      if (newPassword.length < 6) {
        state = state.copyWith(error: 'New password must be at least 6 characters');
        return false;
      }

      // Update password hash
      await _storage.write(key: 'user_password_hash', value: _hashPassword(newPassword));
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to change password');
      return false;
    }
  }

  /// Send password reset email (simulated)
  /// Returns true if email exists in storage
  Future<bool> sendPasswordResetEmail(String email) async {
    final storedEmail = await _storage.read(key: 'user_email');
    if (storedEmail != null && storedEmail.toLowerCase() == email.toLowerCase()) {
      // Store pending reset state
      await _storage.write(key: 'pending_reset_email', value: email);
      await _storage.write(key: 'reset_token', value: 'demo-reset-token');
      return true;
    }
    return false;
  }

  /// Reset password with email and new password
  Future<bool> resetPassword(String email, String newPassword) async {
    if (newPassword.length < 6) {
      return false;
    }

    final pendingEmail = await _storage.read(key: 'pending_reset_email');
    if (pendingEmail == null || pendingEmail.toLowerCase() != email.toLowerCase()) {
      return false;
    }

    // Update password hash
    await _storage.write(key: 'user_password_hash', value: _hashPassword(newPassword));
    // Clear reset state
    await _storage.delete(key: 'pending_reset_email');
    await _storage.delete(key: 'reset_token');

    return true;
  }

  /// Simple hash function for demo purposes
  String _hashPassword(String password) {
    // Using base64 encoding as a simple "hash" for demo
    // In production, use proper hashing like bcrypt or argon2
    return password.split('').reversed.join() + password.length.toString();
  }
}

// Auth state provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(storage);
});
