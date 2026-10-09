import '../../domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> getCurrentUser();

  /// Bypasses the local auth cache and resolves the current Firestore profile.
  /// Used after trusted backend operations change membership atomically.
  Future<AuthUser?> refreshCurrentUser();

  Stream<AuthUser?> get authStateChanges;

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<void> acknowledgePasswordChangePrompt();

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Deletes the signed-in identity through the trusted backend.
  ///
  /// [deleteInstitution] is only valid for the sole owner and permanently
  /// removes the institution and every membership associated with it.
  Future<void> deleteAccount({required bool deleteInstitution});
}
