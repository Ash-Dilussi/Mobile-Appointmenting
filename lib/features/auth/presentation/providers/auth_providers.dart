import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/sources/firebase_auth_data_source.dart';
import '../../data/sources/firestore_profile_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/sources/account_deletion_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_user.dart';
import '../../../../core/auth/officer_provisioning_service.dart';
import '../../../../core/database/hive_service.dart';

// Firebase SDK singletons
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseFunctionsProvider =
    Provider<FirebaseFunctions>((ref) => FirebaseFunctions.instance);

final officerProvisioningServiceProvider = Provider<OfficerProvisioningService>(
  (ref) => OfficerProvisioningService(
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

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

final accountDeletionDataSourceProvider = Provider<AccountDeletionDataSource>(
  (ref) => AccountDeletionDataSource(
    functions: ref.watch(firebaseFunctionsProvider),
  ),
);

// Repository
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepositoryImpl(
          firebaseSource: ref.watch(firebaseAuthDataSourceProvider),
          firestoreSource: ref.watch(firestoreProfileDataSourceProvider),
          accountDeletionSource: ref.watch(accountDeletionDataSourceProvider),
          purgeLocalData: HiveService.instance.clearAllData,
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
