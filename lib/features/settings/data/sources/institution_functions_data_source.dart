import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/repositories/institution_repository.dart';

class InstitutionFunctionsDataSource {
  InstitutionFunctionsDataSource({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> provisionBusiness(
    InstitutionProvisioningRequest request,
  ) async {
    try {
      final result = await _functions.httpsCallable('provisionBusiness').call({
        'idempotencyKey': request.idempotencyKey,
        'name': request.name,
        'themePreset': request.themePreset,
        'address': request.address,
        'phone': request.phone,
        'email': request.email,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details is Map
          ? Map<String, dynamic>.from(error.details as Map)
          : const <String, dynamic>{};
      throw InstitutionRepositoryException(
        code: error.code,
        reason: details['reason'] as String?,
        message: _messageFor(error.code, details['reason'] as String?),
      );
    }
  }

  String _messageFor(String code, String? reason) {
    if (reason == 'ALREADY_LINKED') {
      return 'This account already belongs to a Bookly business.';
    }
    if (code == 'unauthenticated') {
      return 'Your session expired. Sign in again before retrying setup.';
    }
    if (code == 'invalid-argument') {
      return 'Check the business details and try again.';
    }
    return 'We could not finish setting up your business. Your account is safe, and you can retry.';
  }
}
