import '../../domain/repositories/institution_repository.dart';
import '../sources/institution_functions_data_source.dart';

class InstitutionRepositoryImpl implements InstitutionRepository {
  InstitutionRepositoryImpl({
    required InstitutionFunctionsDataSource functionsSource,
  }) : _functionsSource = functionsSource;

  final InstitutionFunctionsDataSource _functionsSource;

  @override
  Future<ProvisionedInstitution> provisionBusiness(
    InstitutionProvisioningRequest request,
  ) async {
    final data = await _functionsSource.provisionBusiness(request);
    final institution = data['institution'];
    if (institution is! Map) {
      throw const InstitutionRepositoryException(
        code: 'invalid-response',
        message: 'The server returned an invalid business response.',
      );
    }
    final map = Map<String, dynamic>.from(institution);
    final id = (map['id'] as String? ?? '').trim();
    final ownerId = (map['ownerId'] as String? ?? '').trim();
    final name = (map['name'] as String? ?? '').trim();
    final themePreset = (map['themePreset'] as String? ?? '').trim();
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(map['updatedAt'] as String? ?? '');
    if (id.isEmpty ||
        ownerId.isEmpty ||
        name.isEmpty ||
        themePreset.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      throw const InstitutionRepositoryException(
        code: 'invalid-response',
        message: 'The server returned incomplete business data.',
      );
    }

    return ProvisionedInstitution(
      id: id,
      ownerId: ownerId,
      name: name,
      themePreset: themePreset,
      address: _optionalString(map['address']),
      phone: _optionalString(map['phone']),
      email: _optionalString(map['email']),
      hasEverHadAdditionalStaff:
          map['hasEverHadAdditionalStaff'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String? _optionalString(Object? value) {
    final normalized = value is String ? value.trim() : '';
    return normalized.isEmpty ? null : normalized;
  }
}
