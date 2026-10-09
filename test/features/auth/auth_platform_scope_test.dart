import 'package:bookly/core/error/auth_exception.dart';
import 'package:bookly/features/auth/data/sources/firebase_auth_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  test('Firebase Google sign-in cannot be invoked on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final googleSignIn = _MockGoogleSignIn();
    final source = FirebaseAuthDataSource(
      firebaseAuth: _MockFirebaseAuth(),
      googleSignIn: googleSignIn,
    );

    await expectLater(
      source.signInWithGoogle(),
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          'operation-not-allowed',
        ),
      ),
    );
    verifyNever(googleSignIn.signIn);
  });
}
