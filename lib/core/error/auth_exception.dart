import 'package:firebase_auth/firebase_auth.dart';

class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException(this.code, {this.message = ''});

  factory AuthException.fromFirebase(FirebaseAuthException e) {
    return AuthException(e.code, message: e.message ?? '');
  }

  factory AuthException.googleCancelled() =>
      const AuthException('google_sign_in_cancelled');

  factory AuthException.noFirebaseUser() =>
      const AuthException('no_firebase_user');

  factory AuthException.tokenRevoked() =>
      const AuthException('token_revoked');

  @override
  String toString() => 'AuthException(code: $code, message: $message)';
}