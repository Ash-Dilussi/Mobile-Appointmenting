import 'package:bookly/core/database/collections/collections.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/core/providers/hive_service_provider.dart';
import 'package:bookly/features/auth/domain/entities/auth_user.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/services/presentation/screens/station_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHiveService extends Mock implements HiveService {}

AuthUser _user(UserRole role) => AuthUser(
      uid: 'user-1',
      email: 'owner@example.com',
      displayName: 'Test Owner',
      role: role,
      institutionId: 'institution-1',
      isEmailVerified: true,
      createdAt: DateTime(2026),
    );

Future<ProviderContainer> _containerFor(
  UserRole role, {
  List<ServiceStation> stations = const <ServiceStation>[],
}) async {
  final db = _MockHiveService();
  when(() => db.watchStationsForInstitution('institution-1'))
      .thenAnswer((_) => Stream.value(stations));

  final container = ProviderContainer(
    overrides: [hiveServiceProvider.overrideWithValue(db)],
  );
  await container
      .read(authSessionProvider.notifier)
      .loadSessionFromAuthUser(_user(role));
  return container;
}

void main() {
  testWidgets('owner can add a service location from the empty list',
      (tester) async {
    final container = await _containerFor(UserRole.owner);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StationManagementScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Add Location'), findsWidgets);
  });

  testWidgets('owner can add a service location from a populated list',
      (tester) async {
    final station = ServiceStation()
      ..id = 1
      ..institutionId = 'institution-1'
      ..name = 'Consultation Room';
    final container = await _containerFor(
      UserRole.owner,
      stations: [station],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StationManagementScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('add-service-location-fab')),
      findsOneWidget,
    );
    expect(find.text('Add Location'), findsOneWidget);
  });

  testWidgets('officer does not receive station write controls',
      (tester) async {
    final container = await _containerFor(UserRole.officer);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StationManagementScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Add Location'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
