import '../../domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> getCurrentUser();

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

  Future<void> linkUserToInstitution({
    required String institutionId,
    required UserRole role,
  });
}