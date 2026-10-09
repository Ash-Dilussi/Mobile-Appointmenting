import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/release_scope.dart';
import '../../../../core/error/auth_exception.dart';

class FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthDataSource({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  })  : _auth = firebaseAuth,
        _googleSignIn = googleSignIn;

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get rawAuthStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // Firebase SDK ≥10 consolidates user-not-found + wrong-password into invalid-credential
      // We disambiguate by treating invalid-credential as user-not-found for the login flow
      if (e.code == 'invalid-credential') {
        throw const AuthException('user-not-found',
            message: 'No account found with this email address.');
      }
      throw AuthException.fromFirebase(e);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!ReleaseScope.googleSignInEnabled) {
      throw const AuthException(
        'operation-not-allowed',
        message: 'Google Sign-In is not available on this platform.',
      );
    }
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw AuthException.googleCancelled();
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      throw AuthException.noFirebaseUser();
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Revokes the Google grant when Google is linked to the current identity.
  /// Firebase account deletion alone removes the provider association but
  /// cannot revoke a third-party OAuth grant held by Google.
  Future<void> disconnectGoogleIfLinked() async {
    final hasGoogleProvider = _auth.currentUser?.providerData.any(
          (provider) => provider.providerId == GoogleAuthProvider.PROVIDER_ID,
        ) ??
        false;
    if (!hasGoogleProvider) return;
    await _googleSignIn.disconnect();
  }

  Future<bool> validateCurrentToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.getIdToken(true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
