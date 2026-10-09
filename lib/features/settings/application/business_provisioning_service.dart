import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/collections/institution.dart';
import '../../../core/database/collections/user.dart';
import '../../../core/database/hive_service.dart';
import '../../../core/entitlements/entitlement_provider.dart';
import '../../../core/providers/hive_service_provider.dart';
import '../../auth/presentation/providers/auth_notifier.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/providers/auth_session_provider.dart';
import '../data/repositories/institution_repository_impl.dart';
import '../data/sources/institution_functions_data_source.dart';
import '../domain/repositories/institution_repository.dart';
import 'provisioning_attempt_store.dart';

typedef EntitlementBootstrapper = Future<void> Function(String institutionId);
typedef IdempotencyKeyFactory = String Function();
typedef LinkedUserRefresher = Future<void> Function();

class BusinessProvisioningRecoveryRequired implements Exception {
  const BusinessProvisioningRecoveryRequired({
    required this.message,
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() => 'BusinessProvisioningRecoveryRequired($message)';
}

/// Coordinates trusted remote provisioning and local cache recovery for both
/// onboarding paths.
///
/// The server transaction owns institution creation and membership linking.
/// This service persists one idempotency key before the first call and keeps it
/// until every required local cache write succeeds. Retrying therefore repairs
/// the same business instead of creating another one.
class BusinessProvisioningService {
  BusinessProvisioningService({
    required InstitutionRepository institutionRepository,
    required ProvisioningAttemptStore attemptStore,
    required HiveService hiveService,
    required LinkedUserRefresher refreshLinkedUser,
    required EntitlementBootstrapper bootstrapEntitlements,
    IdempotencyKeyFactory? createIdempotencyKey,
  })  : _institutionRepository = institutionRepository,
        _attemptStore = attemptStore,
        _hiveService = hiveService,
        _refreshLinkedUser = refreshLinkedUser,
        _bootstrapEntitlements = bootstrapEntitlements,
        _createIdempotencyKey =
            createIdempotencyKey ?? (() => const Uuid().v4());

  final InstitutionRepository _institutionRepository;
  final ProvisioningAttemptStore _attemptStore;
  final HiveService _hiveService;
  final LinkedUserRefresher _refreshLinkedUser;
  final EntitlementBootstrapper _bootstrapEntitlements;
  final IdempotencyKeyFactory _createIdempotencyKey;

  Future<Institution> provision({
    required AuthSession session,
    required String name,
    required String themePreset,
    String? address,
    String? phone,
    String? email,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A business name is required.');
    }

    var idempotencyKey = await _attemptStore.readForUser(session.userId);
    if (idempotencyKey == null || idempotencyKey.trim().isEmpty) {
      idempotencyKey = _createIdempotencyKey();
      // Persist before the first network call. If this write fails, no remote
      // mutation has happened and the recovery UI can retry safely.
      await _attemptStore.writeForUser(session.userId, idempotencyKey);
    }

    try {
      final remote = await _institutionRepository.provisionBusiness(
        InstitutionProvisioningRequest(
          idempotencyKey: idempotencyKey,
          name: normalizedName,
          themePreset: themePreset,
          address: _emptyToNull(address),
          phone: _emptyToNull(phone),
          email: _emptyToNull(email),
        ),
      );
      if (remote.ownerId != session.userId) {
        throw const InstitutionRepositoryException(
          code: 'owner-mismatch',
          message: 'The provisioned business owner did not match this account.',
        );
      }

      final business = Institution()
        ..id = remote.id
        ..name = remote.name
        ..address = remote.address
        ..phone = remote.phone
        ..email = remote.email
        ..themePreset = remote.themePreset
        ..ownerId = remote.ownerId
        ..createdAt = remote.createdAt
        ..updatedAt = remote.updatedAt
        ..hasEverHadAdditionalStaff = remote.hasEverHadAdditionalStaff;

      // Cache the institution and operational user before publishing the
      // linked auth session. A crash cannot leave a linked cache pointing at a
      // missing local institution.
      await _hiveService.insertInstitution(business);
      final existingUser = _hiveService.getUserById(session.userId);
      final cachedUser = existingUser ??
          (User()
            ..id = session.userId
            ..email = session.email
            ..name = session.name ?? '');
      cachedUser.institutionId = business.id;
      cachedUser.role = 'owner';
      if (existingUser == null) {
        await _hiveService.insertUser(cachedUser);
      } else {
        await _hiveService.updateUser(cachedUser.id, cachedUser);
      }

      // The callable already linked the profile. Refresh only; never perform a
      // second client write that could diverge from the server transaction.
      await _refreshLinkedUser();
      await _attemptStore.clearForUser(session.userId);

      // Entitlements have a local/free fallback and must not turn a completed
      // identity transaction into another setup failure.
      try {
        await _bootstrapEntitlements(business.id);
      } catch (_) {}
      return business;
    } on BusinessProvisioningRecoveryRequired {
      rethrow;
    } on InstitutionRepositoryException catch (error) {
      throw BusinessProvisioningRecoveryRequired(
        message: error.message,
        cause: error,
      );
    } catch (error) {
      throw BusinessProvisioningRecoveryRequired(
        message:
            'We could not finish setting up your business. Your account is safe, and you can retry.',
        cause: error,
      );
    }
  }

  String? _emptyToNull(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

String defaultSoloBusinessName({
  required String? displayName,
  required String email,
}) {
  final normalizedName = displayName?.trim() ?? '';
  if (normalizedName.isNotEmpty) {
    final suffix = normalizedName.toLowerCase().endsWith('s') ? "'" : "'s";
    return '$normalizedName$suffix Business';
  }

  final emailName = email.split('@').first.trim();
  if (emailName.isNotEmpty) {
    return '$emailName\'s Business';
  }
  return 'My Business';
}

final institutionFunctionsDataSourceProvider =
    Provider<InstitutionFunctionsDataSource>((ref) {
  return InstitutionFunctionsDataSource(
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

final institutionRepositoryProvider = Provider<InstitutionRepository>((ref) {
  return InstitutionRepositoryImpl(
    functionsSource: ref.watch(institutionFunctionsDataSourceProvider),
  );
});

final provisioningAttemptStoreProvider = Provider<ProvisioningAttemptStore>(
  (ref) => SecureProvisioningAttemptStore(ref.watch(secureStorageProvider)),
);

final businessProvisioningServiceProvider =
    Provider<BusinessProvisioningService>((ref) {
  return BusinessProvisioningService(
    institutionRepository: ref.watch(institutionRepositoryProvider),
    attemptStore: ref.watch(provisioningAttemptStoreProvider),
    hiveService: ref.watch(hiveServiceProvider),
    refreshLinkedUser:
        ref.read(authNotifierProvider.notifier).onInstitutionProvisioned,
    bootstrapEntitlements: (institutionId) => ref
        .read(entitlementProvider.notifier)
        .bootstrap(institutionId: institutionId),
  );
});
