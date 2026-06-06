import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookly/features/auth/domain/entities/auth_user.dart';
import 'package:bookly/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookly/features/auth/presentation/providers/auth_notifier.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockRef extends Mock implements Ref {}

void main() {
  group('Persistent Session Tests', () {
    late MockAuthRepository mockRepository;
    late MockRef mockRef;

    setUp(() {
      mockRepository = MockAuthRepository();
      mockRef = MockRef();
    });

    // C1: User remains logged in after app restart (Hive cache hit)
    test('C1: user remains logged in after app restart (Hive cache hit)', () async {
      final cachedUser = AuthUser(
        uid: 'uid_owner_001',
        email: 'owner@test.com',
        displayName: 'Test Owner',
        role: UserRole.owner,
        institutionId: 'inst_abc123',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );

      when(() => mockRepository.authStateChanges).thenAnswer(
        (_) => Stream.value(cachedUser),
      );

      final notifier = AuthNotifier(mockRepository, mockRef);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.status, AuthStatus.authenticated);
      verifyNever(() => mockRepository.signInWithEmail(email: any(named: 'email'), password: any(named: 'password')));
    });

    // C2: Cleared app cache forces re-login
    test('C2: cleared app cache forces re-login', () async {
      when(() => mockRepository.authStateChanges).thenAnswer(
        (_) => Stream<AuthUser?>.value(null),
      );

      final notifier = AuthNotifier(mockRepository, mockRef);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.status, AuthStatus.unauthenticated);
    });

    // C3a: New user routed to newUser status (no institutionId)
    test('C3a: new user routed to newUser status (no institutionId)', () async {
      final newUser = AuthUser(
        uid: 'uid_new_001',
        email: 'new@test.com',
        displayName: 'New User',
        role: UserRole.unknown,
        institutionId: '',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );

      when(() => mockRepository.authStateChanges).thenAnswer(
        (_) => Stream.value(newUser),
      );

      final notifier = AuthNotifier(mockRepository, mockRef);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.status, AuthStatus.newUser);
      expect(notifier.state.user?.institutionId, '');
    });

    // C3b: Existing staff user routed to authenticated status
    test('C3b: existing staff user routed to authenticated status', () async {
      final officerUser = AuthUser(
        uid: 'uid_officer_001',
        email: 'officer@test.com',
        displayName: 'Test Officer',
        role: UserRole.officer,
        institutionId: 'inst_abc123',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );

      when(() => mockRepository.authStateChanges).thenAnswer(
        (_) => Stream.value(officerUser),
      );

      final notifier = AuthNotifier(mockRepository, mockRef);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user?.institutionId, 'inst_abc123');
    });

    // Sign-out clears both stores
    test('signOut clears Hive cache and Firebase session', () async {
      when(() => mockRepository.authStateChanges).thenAnswer(
        (_) => Stream<AuthUser?>.value(null),
      );
      when(() => mockRepository.signOut()).thenAnswer((_) async {});

      final notifier = AuthNotifier(mockRepository, mockRef);
      await Future.delayed(const Duration(milliseconds: 50));

      await notifier.signOut();

      verify(() => mockRepository.signOut()).called(1);
      expect(notifier.state.status, AuthStatus.unauthenticated);
    });
  });

  group('AuthState Tests', () {
    test('AuthState.initial() creates correct state', () {
      final state = AuthState.initial();
      expect(state.status, AuthStatus.initial);
      expect(state.user, isNull);
    });

    test('AuthState.authenticated() creates correct state', () {
      final user = AuthUser(
        uid: 'uid_001',
        email: 'test@test.com',
        displayName: 'Test User',
        role: UserRole.owner,
        institutionId: 'inst_001',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final state = AuthState.authenticated(user);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user, equals(user));
    });

    test('AuthState.newUser() creates correct state', () {
      final user = AuthUser(
        uid: 'uid_001',
        email: 'test@test.com',
        displayName: 'Test User',
        role: UserRole.unknown,
        institutionId: '',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final state = AuthState.newUser(user);
      expect(state.status, AuthStatus.newUser);
      expect(state.user, equals(user));
    });

    test('AuthState.error() creates correct state', () {
      final state = AuthState.error('user-not-found', 'No account found');
      expect(state.status, AuthStatus.error);
      expect(state.errorCode, 'user-not-found');
      expect(state.errorMessage, 'No account found');
    });

    test('isLoading returns true for initial and loading states', () {
      expect(AuthState.initial().isLoading, isTrue);
      expect(AuthState.loading().isLoading, isTrue);
      expect(AuthState.authenticated(AuthUser(
        uid: '1',
        email: 'a@a.com',
        displayName: 'A',
        role: UserRole.owner,
        institutionId: 'i1',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      )).isLoading, isFalse);
    });
  });

  group('AuthUser Tests', () {
    test('AuthUser equality by uid', () {
      final user1 = AuthUser(
        uid: 'uid_001',
        email: 'test@test.com',
        displayName: 'Test',
        role: UserRole.owner,
        institutionId: 'inst_001',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final user2 = AuthUser(
        uid: 'uid_001',
        email: 'different@email.com',
        displayName: 'Different Name',
        role: UserRole.officer,
        institutionId: 'different_inst',
        isEmailVerified: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(user1, equals(user2));
    });

    test('isLinkedToInstitution returns correct value', () {
      final ownerWithInst = AuthUser(
        uid: '1',
        email: 'a@a.com',
        displayName: 'A',
        role: UserRole.owner,
        institutionId: 'inst_001',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final newUser = AuthUser(
        uid: '2',
        email: 'b@b.com',
        displayName: 'B',
        role: UserRole.unknown,
        institutionId: '',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      expect(ownerWithInst.isLinkedToInstitution, isTrue);
      expect(newUser.isLinkedToInstitution, isFalse);
    });

    test('isOwner and isOfficer return correct values', () {
      final owner = AuthUser(
        uid: '1',
        email: 'a@a.com',
        displayName: 'A',
        role: UserRole.owner,
        institutionId: 'inst_001',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final officer = AuthUser(
        uid: '2',
        email: 'b@b.com',
        displayName: 'B',
        role: UserRole.officer,
        institutionId: 'inst_001',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final unknown = AuthUser(
        uid: '3',
        email: 'c@c.com',
        displayName: 'C',
        role: UserRole.unknown,
        institutionId: '',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      expect(owner.isOwner, isTrue);
      expect(owner.isOfficer, isFalse);
      expect(officer.isOwner, isFalse);
      expect(officer.isOfficer, isTrue);
      expect(unknown.isOwner, isFalse);
      expect(unknown.isOfficer, isFalse);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = AuthUser(
        uid: '1',
        email: 'a@a.com',
        displayName: 'A',
        role: UserRole.owner,
        institutionId: 'inst_001',
        isEmailVerified: true,
        createdAt: DateTime.now(),
      );
      final updated = original.copyWith(displayName: 'Updated Name', institutionId: 'inst_002');
      expect(updated.uid, '1');
      expect(updated.email, 'a@a.com');
      expect(updated.displayName, 'Updated Name');
      expect(updated.institutionId, 'inst_002');
    });
  });

  group('UserRole Tests', () {
    test('UserRoleX.fromString returns correct role', () {
      expect(UserRoleX.fromString('owner'), UserRole.owner);
      expect(UserRoleX.fromString('officer'), UserRole.officer);
      expect(UserRoleX.fromString('unknown'), UserRole.unknown);
      expect(UserRoleX.fromString('invalid'), UserRole.unknown);
    });

    test('UserRoleX.name returns correct string', () {
      expect(UserRole.owner.name, 'owner');
      expect(UserRole.officer.name, 'officer');
      expect(UserRole.unknown.name, 'unknown');
    });
  });
}