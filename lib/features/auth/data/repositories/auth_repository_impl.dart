import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/hive/hive_initializer.dart';
import '../sources/firebase_auth_data_source.dart';
import '../sources/firestore_profile_data_source.dart';
import '../models/firestore_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _firebaseSource;
  final FirestoreProfileDataSource _firestoreSource;

  AuthRepositoryImpl({
    required FirebaseAuthDataSource firebaseSource,
    required FirestoreProfileDataSource firestoreSource,
  })  : _firebaseSource = firebaseSource,
        _firestoreSource = firestoreSource;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    // Emit cache immediately — UI can start before network responds
    final cached = HiveInitializer.readCachedUser();
    if (cached != null) {
      yield cached.toAuthUser();
    }

    await for (final firebaseUser in _firebaseSource.rawAuthStateChanges) {
      if (firebaseUser == null) {
        // Token expired or revoked from another device
        await HiveInitializer.clearCachedUser();
        yield null;
        continue;
      }

      // Check if valid cache exists for this UID — skip Firestore if match
      final currentCache = HiveInitializer.readCachedUser();
      if (currentCache != null && currentCache.uid == firebaseUser.uid) {
        yield currentCache.toAuthUser();
        continue;
      }

      // First login or stale cache — fetch from Firestore, write to Hive
      final authUser = await _resolveAndCacheProfile(firebaseUser);
      yield authUser;
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final cached = HiveInitializer.readCachedUser();
    if (cached != null) return cached.toAuthUser();

    final firebaseUser = _firebaseSource.currentFirebaseUser;
    if (firebaseUser == null) return null;
    return _resolveAndCacheProfile(firebaseUser);
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential =
        await _firebaseSource.signInWithEmail(email, password);
    if (credential.user == null) throw AuthException.noFirebaseUser();
    return _resolveAndCacheProfile(credential.user!);
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final credential = await _firebaseSource.signInWithGoogle();
    if (credential.user == null) throw AuthException.noFirebaseUser();
    return _resolveAndCacheProfile(credential.user!);
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential =
        await _firebaseSource.registerWithEmail(email, password);
    if (credential.user == null) throw AuthException.noFirebaseUser();
    await _firebaseSource.updateDisplayName(displayName);

    final skeleton = FirestoreUserModel.newUserSkeleton(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      isEmailVerified: credential.user!.emailVerified,
    );
    await _firestoreSource.upsertProfile(skeleton);

    final authUser = skeleton.toAuthUser();
    await HiveInitializer.writeCachedUser(authUser);
    return authUser;
  }

  @override
  Future<void> signOut() async {
    // Clear cache before Firebase call — prevents race with authStateChanges null emission
    await HiveInitializer.clearCachedUser();
    await _firebaseSource.signOut();
  }

  @override
  Future<void> linkUserToInstitution({
    required String institutionId,
    required UserRole role,
  }) async {
    final currentUser = _firebaseSource.currentFirebaseUser;
    if (currentUser == null) throw AuthException.noFirebaseUser();

    await _firestoreSource.linkToInstitution(
      uid: currentUser.uid,
      institutionId: institutionId,
      role: role.name,
    );

    await _resolveAndCacheProfile(currentUser);
  }

  Future<AuthUser> _resolveAndCacheProfile(User firebaseUser) async {
    FirestoreUserModel? model =
        await _firestoreSource.fetchProfile(firebaseUser.uid);

    if (model == null) {
      model = FirestoreUserModel.newUserSkeleton(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? '',
        photoUrl: firebaseUser.photoURL,
        isEmailVerified: firebaseUser.emailVerified,
      );
      await _firestoreSource.upsertProfile(model);
    }

    final authUser = model.toAuthUser();
    await HiveInitializer.writeCachedUser(authUser);
    return authUser;
  }
}