import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/error/auth_exception.dart';
import '../../../../core/hive/hive_initializer.dart';
import '../sources/firebase_auth_data_source.dart';
import '../sources/firestore_profile_data_source.dart';
import '../sources/account_deletion_data_source.dart';
import '../models/firestore_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _firebaseSource;
  final FirestoreProfileDataSource _firestoreSource;
  final AccountDeletionDataSource _accountDeletionSource;
  final Future<void> Function() _purgeLocalData;

  AuthRepositoryImpl({
    required FirebaseAuthDataSource firebaseSource,
    required FirestoreProfileDataSource firestoreSource,
    required AccountDeletionDataSource accountDeletionSource,
    required Future<void> Function() purgeLocalData,
  })  : _firebaseSource = firebaseSource,
        _firestoreSource = firestoreSource,
        _accountDeletionSource = accountDeletionSource,
        _purgeLocalData = purgeLocalData;

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
        if (HiveInitializer.readCachedUser() != null) {
          await _purgeDeletedSession();
        } else {
          await HiveInitializer.clearCachedUser();
        }
        yield null;
        continue;
      }

      // Check if valid cache exists for this UID — skip Firestore if match
      // First login or stale cache — fetch from Firestore, write to Hive
      // A matching cache must not suppress the remote membership refresh.
      try {
        final authUser = await _resolveAndCacheProfile(firebaseUser);
        yield authUser;
      } on AuthException catch (error) {
        if (error.code != 'token_revoked') rethrow;
        yield null;
      }
    }
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final cached = HiveInitializer.readCachedUser();
    if (cached != null) return cached.toAuthUser();

    final firebaseUser = _firebaseSource.currentFirebaseUser;
    if (firebaseUser == null) return null;
    try {
      return await _resolveAndCacheProfile(firebaseUser);
    } on AuthException catch (error) {
      if (error.code == 'token_revoked') return null;
      rethrow;
    }
  }

  @override
  Future<AuthUser?> refreshCurrentUser() async {
    final firebaseUser = _firebaseSource.currentFirebaseUser;
    if (firebaseUser == null) return null;
    try {
      return await _resolveAndCacheProfile(firebaseUser);
    } on AuthException catch (error) {
      if (error.code == 'token_revoked') return null;
      rethrow;
    }
  }

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseSource.signInWithEmail(email, password);
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
    late UserCredential credential;

    try {
      credential = await _firebaseSource.registerWithEmail(email, password);
    } on AuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Partial registration: Auth account exists but Firestore write
        // failed on a previous attempt. Sign in silently and recover.
        credential = await _firebaseSource.signInWithEmail(email, password);
      } else {
        rethrow;
      }
    }

    if (credential.user == null) throw AuthException.noFirebaseUser();

    // Best-effort display name update — non-fatal if it fails
    try {
      await _firebaseSource.updateDisplayName(displayName);
    } catch (_) {}

    // A retry may be signing back into an account whose Firestore profile was
    // already completed. Never merge an unlinked skeleton over that profile:
    // role and institution membership are server-owned security fields.
    final existing = await _firestoreSource.fetchProfile(credential.user!.uid);
    if (existing != null) {
      final authUser = existing.toAuthUser();
      await HiveInitializer.writeCachedUser(authUser);
      return authUser;
    }

    final skeleton = FirestoreUserModel.newUserSkeleton(
      uid: credential.user!.uid,
      email: email,
      displayName: displayName,
      isEmailVerified: credential.user!.emailVerified,
    );

    // Firestore is the source of truth for role and institution membership.
    // Do not complete registration without a server profile; a retry can
    // recover the already-created Auth account through the branch above.
    await _firestoreSource.upsertProfile(skeleton);

    // Cache the server-backed skeleton only after its Firestore write succeeds.
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
  Future<void> acknowledgePasswordChangePrompt() async {
    final currentUser = _firebaseSource.currentFirebaseUser;
    if (currentUser == null) throw AuthException.noFirebaseUser();
    await _firestoreSource.acknowledgePasswordChangePrompt(currentUser.uid);
    await _resolveAndCacheProfile(currentUser);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _firebaseSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> deleteAccount({required bool deleteInstitution}) async {
    try {
      await _firebaseSource.disconnectGoogleIfLinked();
    } catch (_) {
      // Best effort: not every email/password account has a Google session,
      // and a stale Google token must not block the trusted server deletion.
    }

    await _accountDeletionSource.deleteAccount(
      deleteInstitution: deleteInstitution,
    );

    // The caller is no longer authorized to retain this institution's local
    // records. The server keeps institution-owned records intact for an
    // officer-only deletion; other authorized officers are unaffected.
    await _purgeLocalData();
    await HiveInitializer.clearCachedUser();
    try {
      await _firebaseSource.signOut();
    } catch (_) {
      // The backend has already deleted the identity. Local Firebase cleanup
      // is best effort because the SDK can report user-not-found afterward.
    }
  }

  Future<AuthUser> _resolveAndCacheProfile(User firebaseUser) async {
    final cached = HiveInitializer.readCachedUser();
    FirestoreUserModel? model = await _firestoreSource.fetchProfile(
      firebaseUser.uid,
    );

    if (model == null) {
      // A linked cached account whose remote membership disappears has been
      // deleted or removed. Never recreate it as an unlinked skeleton: wipe
      // the now-unauthorized device cache and force sign-out instead.
      if (cached != null &&
          cached.uid == firebaseUser.uid &&
          cached.institutionId.isNotEmpty) {
        await _purgeDeletedSession();
        throw AuthException.tokenRevoked();
      }
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

  Future<void> _purgeDeletedSession() async {
    try {
      await _purgeLocalData();
    } finally {
      await HiveInitializer.clearCachedUser();
      try {
        await _firebaseSource.signOut();
      } catch (_) {
        // A remotely deleted identity commonly makes sign-out fail locally.
      }
    }
  }
}
