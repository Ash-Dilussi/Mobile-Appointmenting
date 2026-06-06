import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/sources/firebase_auth_data_source.dart';
import '../../data/sources/firestore_profile_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user.dart';

// Firebase SDK singletons
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Data sources
final firebaseAuthDataSourceProvider =
    Provider<FirebaseAuthDataSource>((ref) => FirebaseAuthDataSource(
          firebaseAuth: ref.watch(firebaseAuthProvider),
          googleSignIn: ref.watch(googleSignInProvider),
        ));

final firestoreProfileDataSourceProvider =
    Provider<FirestoreProfileDataSource>((ref) => FirestoreProfileDataSource(
          firestore: ref.watch(firestoreProvider),
        ));

// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepositoryImpl(
      firebaseSource: ref.watch(firebaseAuthDataSourceProvider),
      firestoreSource: ref.watch(firestoreProfileDataSourceProvider),
    ));

// Derived streams
final authStateStreamProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authStateStreamProvider).valueOrNull;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null && user.isLinkedToInstitution;
});