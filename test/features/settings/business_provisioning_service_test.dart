import 'package:bookly/core/database/collections/institution.dart';
import 'package:bookly/core/database/collections/user.dart';
import 'package:bookly/core/database/hive_service.dart';
import 'package:bookly/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:bookly/features/settings/application/business_provisioning_service.dart';
import 'package:bookly/features/settings/application/provisioning_attempt_store.dart';
import 'package:bookly/features/settings/domain/repositories/institution_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockInstitutionRepository extends Mock
    implements InstitutionRepository {}

class _MockHiveService extends Mock implements HiveService {}

class _FakeInstitution extends Fake implements Institution {}

class _FakeUser extends Fake implements User {}

class _FakeRequest extends Fake implements InstitutionProvisioningRequest {}

class _MemoryAttemptStore implements ProvisioningAttemptStore {
  String? value;

  @override
  Future<void> clearForUser(String uid) async => value = null;

  @override
  Future<String?> readForUser(String uid) async => value;

  @override
  Future<void> writeForUser(String uid, String idempotencyKey) async {
    value = idempotencyKey;
  }
}

void main() {
  const session = AuthSession(
    userId: 'owner-1',
    email: 'alex@example.com',
    name: 'Alex',
  );
  final remoteBusiness = ProvisionedInstitution(
    id: 'inst-atomic-1',
    ownerId: 'owner-1',
    name: "Alex's Business",
    themePreset: 'solarOrange',
    hasEverHadAdditionalStaff: false,
    createdAt: DateTime.utc(2026, 9, 26),
    updatedAt: DateTime.utc(2026, 9, 26),
  );

  setUpAll(() {
    registerFallbackValue(_FakeInstitution());
    registerFallbackValue(_FakeUser());
    registerFallbackValue(_FakeRequest());
  });

  test('uses the trusted repository and publishes local state after caching',
      () async {
    final repository = _MockInstitutionRepository();
    final hive = _MockHiveService();
    final attempts = _MemoryAttemptStore();
    var refreshed = false;
    var bootstrapped = false;

    when(() => repository.provisionBusiness(any()))
        .thenAnswer((_) async => remoteBusiness);
    when(() => hive.getUserById('owner-1')).thenReturn(null);
    when(() => hive.insertInstitution(any()))
        .thenAnswer((_) async => 'inst-atomic-1');
    when(() => hive.insertUser(any())).thenAnswer((_) async {});

    final service = BusinessProvisioningService(
      institutionRepository: repository,
      attemptStore: attempts,
      hiveService: hive,
      refreshLinkedUser: () async => refreshed = true,
      bootstrapEntitlements: (institutionId) async {
        expect(institutionId, 'inst-atomic-1');
        bootstrapped = true;
      },
      createIdempotencyKey: () => 'attempt_12345678901234567890',
    );

    final result = await service.provision(
      session: session,
      name: " Alex's Business ",
      themePreset: 'solarOrange',
    );

    expect(result.id, 'inst-atomic-1');
    expect(result.hasEverHadAdditionalStaff, isFalse);
    expect(refreshed, isTrue);
    expect(bootstrapped, isTrue);
    expect(attempts.value, isNull);
    final request = verify(() => repository.provisionBusiness(captureAny()))
        .captured
        .single as InstitutionProvisioningRequest;
    expect(request.idempotencyKey, 'attempt_12345678901234567890');
    expect(request.name, "Alex's Business");
    final cacheOrder = verifyInOrder([
      () => hive.insertInstitution(captureAny()),
      () => hive.getUserById('owner-1'),
      () => hive.insertUser(any()),
    ]);
    final cached = cacheOrder.first.captured.single as Institution;
    expect(cached.ownerId, 'owner-1');
  });

  test('retry reuses one persisted key after a local cache failure', () async {
    final repository = _MockInstitutionRepository();
    final hive = _MockHiveService();
    final attempts = _MemoryAttemptStore();
    var insertAttempts = 0;
    var refreshCount = 0;

    when(() => repository.provisionBusiness(any()))
        .thenAnswer((_) async => remoteBusiness);
    when(() => hive.insertInstitution(any())).thenAnswer((_) async {
      insertAttempts += 1;
      if (insertAttempts == 1) throw StateError('disk unavailable');
      return 'inst-atomic-1';
    });
    when(() => hive.getUserById('owner-1')).thenReturn(null);
    when(() => hive.insertUser(any())).thenAnswer((_) async {});

    final service = BusinessProvisioningService(
      institutionRepository: repository,
      attemptStore: attempts,
      hiveService: hive,
      refreshLinkedUser: () async => refreshCount += 1,
      bootstrapEntitlements: (_) async {},
      createIdempotencyKey: () => 'attempt_12345678901234567890',
    );

    await expectLater(
      service.provision(
        session: session,
        name: "Alex's Business",
        themePreset: 'solarOrange',
      ),
      throwsA(isA<BusinessProvisioningRecoveryRequired>()),
    );
    expect(attempts.value, 'attempt_12345678901234567890');

    await service.provision(
      session: session,
      name: "Alex's Business",
      themePreset: 'solarOrange',
    );

    final requests = verify(() => repository.provisionBusiness(captureAny()))
        .captured
        .cast<InstitutionProvisioningRequest>();
    expect(requests, hasLength(2));
    expect(requests.map((request) => request.idempotencyKey).toSet(),
        {'attempt_12345678901234567890'});
    expect(refreshCount, 1);
    expect(attempts.value, isNull);
  });
}
