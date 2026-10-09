import 'package:bookly/core/database/collections/institution.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/auth/rbac.dart';
import 'package:bookly/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockHiveService extends Mock implements HiveService {}

class _FixedAuthSessionNotifier extends AuthSessionNotifier {
  _FixedAuthSessionNotifier(AuthSession session) : super(_MockHiveService()) {
    state = session;
  }
}

Widget _screen({required AuthSession session, Institution? business}) {
  final repository = _MockAuthRepository();
  when(() => repository.authStateChanges)
      .thenAnswer((_) => const Stream.empty());

  return ProviderScope(
    overrides: [
      authSessionProvider.overrideWith(
        (ref) => _FixedAuthSessionNotifier(session),
      ),
      currentInstitutionProvider.overrideWithValue(business),
      authNotifierProvider.overrideWith(
        (ref) => AuthNotifier(repository, ref),
      ),
    ],
    child: const MaterialApp(home: DeleteAccountScreen()),
  );
}

void main() {
  testWidgets('legacy sole owner sees cautious business deletion paths',
      (tester) async {
    await tester.pumpWidget(
      _screen(
        session: const AuthSession(
          userId: 'owner-1',
          email: 'owner@bookly.test',
          institutionId: 'institution-1',
          role: Role.owner,
          hasCompletedOnboarding: true,
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Delete business'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('bookly.support@gmail.com'), findsOneWidget);
    expect(
        find.textContaining('Self-service ownership transfer'), findsOneWidget);
    expect(find.text('Transfer ownership'), findsNothing);
  });

  testWidgets('officer sees personal account deletion disclosure',
      (tester) async {
    await tester.pumpWidget(
      _screen(
        session: const AuthSession(
          userId: 'officer-1',
          email: 'officer@bookly.test',
          institutionId: 'institution-1',
          role: Role.officer,
          hasCompletedOnboarding: true,
        ),
      ),
    );

    expect(find.text('Delete my account'), findsOneWidget);
    expect(
      find.textContaining('Business-owned records remain available'),
      findsOneWidget,
    );
    expect(find.text('Delete business'), findsNothing);
  });

  testWidgets('known always-solo owner sees direct combined deletion',
      (tester) async {
    final business = Institution()
      ..id = 'institution-1'
      ..name = 'Solo Business'
      ..themePreset = 'solarOrange'
      ..ownerId = 'owner-1'
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026)
      ..hasEverHadAdditionalStaff = false;
    await tester.pumpWidget(
      _screen(
        session: const AuthSession(
          userId: 'owner-1',
          email: 'owner@bookly.test',
          institutionId: 'institution-1',
          role: Role.owner,
          hasCompletedOnboarding: true,
        ),
        business: business,
      ),
    );

    expect(find.text('Delete account and business'), findsOneWidget);
    expect(find.text('bookly.support@gmail.com'), findsNothing);
    expect(find.textContaining('always been yours alone'), findsOneWidget);
  });
}
