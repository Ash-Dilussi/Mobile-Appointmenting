class InstitutionProvisioningRequest {
  const InstitutionProvisioningRequest({
    required this.idempotencyKey,
    required this.name,
    required this.themePreset,
    this.address,
    this.phone,
    this.email,
  });

  final String idempotencyKey;
  final String name;
  final String themePreset;
  final String? address;
  final String? phone;
  final String? email;
}

class ProvisionedInstitution {
  const ProvisionedInstitution({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.themePreset,
    required this.hasEverHadAdditionalStaff,
    required this.createdAt,
    required this.updatedAt,
    this.address,
    this.phone,
    this.email,
  });

  final String id;
  final String ownerId;
  final String name;
  final String themePreset;
  final String? address;
  final String? phone;
  final String? email;
  final bool hasEverHadAdditionalStaff;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class InstitutionRepositoryException implements Exception {
  const InstitutionRepositoryException({
    required this.code,
    required this.message,
    this.reason,
  });

  final String code;
  final String message;
  final String? reason;

  @override
  String toString() => 'InstitutionRepositoryException($code, $reason)';
}

/// Trusted remote boundary for institution lifecycle operations.
///
/// Implementations must not create institutions through direct client
/// Firestore writes. Provisioning is an identity/authorization operation and
/// belongs behind the server transaction exposed by this seam.
abstract class InstitutionRepository {
  Future<ProvisionedInstitution> provisionBusiness(
    InstitutionProvisioningRequest request,
  );
}
