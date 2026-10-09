import 'package:bookly/core/auth/rbac.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/features/auth/domain/repositories/auth_repository.dart';
import 'package:bookly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveService extends Mock implements HiveService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FixedSessionNotifier extends AuthSessionNotifier {
  _FixedSessionNotifier(AuthSession session, HiveService hive) : super(hive) {
    state = session;
  }
}

void main() {
  testWidgets('linked solo owner keeps services, locations, and staff access',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final hive = _MockHiveService();
    final repository = _MockAuthRepository();
    when(hive.getThemeMode).thenReturn('system');
    when(() => repository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    const session = AuthSession(
      userId: 'owner-1',
      email: 'solo@example.com',
      name: 'Solo Owner',
      institutionId: 'business-1',
      role: Role.owner,
      hasCompletedOnboarding: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hiveServiceProvider.overrideWithValue(hive),
          authSessionProvider.overrideWith(
            (ref) => _FixedSessionNotifier(session, hive),
          ),
          authNotifierProvider.overrideWith(
            (ref) => AuthNotifier(repository, ref),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Manage Services'), findsOneWidget);
    expect(find.text('Service Locations'), findsOneWidget);
    expect(find.text('Staff Management'), findsOneWidget);
    expect(find.text('Set Up Business'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
