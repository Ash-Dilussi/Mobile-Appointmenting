import 'dart:async';
import 'dart:io';

import 'package:bookly/core/hive/hive_initializer.dart';
import 'package:bookly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:bookly/features/auth/data/sources/account_deletion_data_source.dart';
import 'package:bookly/features/auth/data/sources/firebase_auth_data_source.dart';
import 'package:bookly/features/auth/data/sources/firestore_profile_data_source.dart';
import 'package:bookly/features/auth/domain/entities/auth_user.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuthDataSource extends Mock
    implements FirebaseAuthDataSource {}

class _MockFirestoreProfileDataSource extends Mock
    implements FirestoreProfileDataSource {}

class _MockAccountDeletionDataSource extends Mock
    implements AccountDeletionDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'bookly_account_deletion_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => tempDirectory.path);
    await Hive.initFlutter(tempDirectory.path);
    await HiveInitializer.init();
  });

  tearDown(() => HiveInitializer.clearCachedUser());

  tearDownAll(() async {
    await Hive.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('remote identity deletion purges local data on the next auth check',
      () async {
    final firebaseSource = _MockFirebaseAuthDataSource();
    final firestoreSource = _MockFirestoreProfileDataSource();
    final deletionSource = _MockAccountDeletionDataSource();
    var purgeCount = 0;
    final user = AuthUser(
      uid: 'officer-1',
      email: 'officer@bookly.test',
      displayName: 'Officer',
      role: UserRole.officer,
      institutionId: 'institution-1',
      isEmailVerified: true,
      createdAt: DateTime(2026),
    );
    await HiveInitializer.writeCachedUser(user);
    when(() => firebaseSource.rawAuthStateChanges)
        .thenAnswer((_) => Stream.value(null));
    when(firebaseSource.signOut).thenAnswer((_) async {});

    final repository = AuthRepositoryImpl(
      firebaseSource: firebaseSource,
      firestoreSource: firestoreSource,
      accountDeletionSource: deletionSource,
      purgeLocalData: () async => purgeCount++,
    );

    final emitted = await repository.authStateChanges.toList();

    expect(emitted, [user, null]);
    expect(purgeCount, 1);
    expect(HiveInitializer.readCachedUser(), isNull);
    verify(firebaseSource.signOut).called(1);
  });

  test('successful in-app deletion purges only after backend success',
      () async {
    final firebaseSource = _MockFirebaseAuthDataSource();
    final firestoreSource = _MockFirestoreProfileDataSource();
    final deletionSource = _MockAccountDeletionDataSource();
    var purgeCount = 0;
    when(firebaseSource.disconnectGoogleIfLinked).thenAnswer((_) async {});
    when(() => deletionSource.deleteAccount(deleteInstitution: false))
        .thenAnswer((_) async {});
    when(firebaseSource.signOut).thenAnswer((_) async {});

    final repository = AuthRepositoryImpl(
      firebaseSource: firebaseSource,
      firestoreSource: firestoreSource,
      accountDeletionSource: deletionSource,
      purgeLocalData: () async => purgeCount++,
    );

    await repository.deleteAccount(deleteInstitution: false);

    expect(purgeCount, 1);
    verify(() => deletionSource.deleteAccount(deleteInstitution: false))
        .called(1);
  });
}
