import 'package:cloud_functions/cloud_functions.dart';

import '../../../../core/error/auth_exception.dart';

class AccountDeletionDataSource {
  AccountDeletionDataSource({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<void> deleteAccount({required bool deleteInstitution}) async {
    try {
      await _functions.httpsCallable('deleteMyAccount').call<void>({
        'deleteInstitution': deleteInstitution,
        'source': 'app',
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthException(
        error.code,
        message:
            error.message ?? 'The deletion request could not be completed.',
      );
    }
  }
}
