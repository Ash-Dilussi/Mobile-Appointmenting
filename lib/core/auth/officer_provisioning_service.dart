import 'package:cloud_functions/cloud_functions.dart';

class OfficerProvisioningResult {
  const OfficerProvisioningResult({
    required this.uid,
    required this.email,
    required this.temporaryPassword,
  });

  final String uid;
  final String email;
  final String temporaryPassword;
}

class OfficerProvisioningException implements Exception {
  const OfficerProvisioningException({
    required this.code,
    required this.message,
    this.reason,
  });

  final String code;
  final String message;
  final String? reason;

  @override
  String toString() => 'OfficerProvisioningException($code, $reason)';
}

/// Trusted callable boundary for officer identity and membership lifecycle.
///
/// Firestore Rules read membership directly from `users/{uid}`; Bookly does
/// not use custom claims for institution or role access. Removal therefore
/// takes effect for Firestore authorization as soon as the server transaction
/// commits and does not depend on an ID-token claim refresh.
class OfficerProvisioningService {
  OfficerProvisioningService({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  Future<OfficerProvisioningResult> provisionOfficer({
    required String ownerUid,
    required String institutionId,
    required String displayName,
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedName = displayName.trim();
    if (normalizedEmail.isEmpty || normalizedName.isEmpty) {
      throw ArgumentError('Name and email are required.');
    }
    if (ownerUid.isEmpty || institutionId.isEmpty) {
      throw StateError('Your owner session is no longer valid.');
    }

    try {
      final result = await _functions.httpsCallable('createOfficer').call({
        'displayName': normalizedName,
        'email': normalizedEmail,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final uid = (data['uid'] as String? ?? '').trim();
      final returnedEmail = (data['email'] as String? ?? '').trim();
      final temporaryPassword =
          (data['temporaryPassword'] as String? ?? '').trim();
      if (uid.isEmpty || returnedEmail.isEmpty || temporaryPassword.isEmpty) {
        throw const OfficerProvisioningException(
          code: 'invalid-response',
          message: 'The server returned an incomplete staff account.',
        );
      }
      return OfficerProvisioningResult(
        uid: uid,
        email: returnedEmail,
        temporaryPassword: temporaryPassword,
      );
    } on FirebaseFunctionsException catch (error) {
      throw _translate(error);
    }
  }

  Future<void> removeOfficer({required String officerUid}) async {
    if (officerUid.trim().isEmpty) {
      throw ArgumentError.value(officerUid, 'officerUid');
    }
    try {
      await _functions.httpsCallable('removeOfficer').call<void>({
        'officerUid': officerUid.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw _translate(error);
    }
  }

  OfficerProvisioningException _translate(FirebaseFunctionsException error) {
    final details = error.details is Map
        ? Map<String, dynamic>.from(error.details as Map)
        : const <String, dynamic>{};
    final reason = details['reason'] as String?;
    if (reason == 'ALREADY_HAS_BOOKLY_ACCOUNT') {
      return const OfficerProvisioningException(
        code: 'already-exists',
        reason: 'ALREADY_HAS_BOOKLY_ACCOUNT',
        message:
            'This person already has a Bookly business set up. Multi-business membership is not supported yet. Contact support if you need help.',
      );
    }
    if (error.code == 'unauthenticated') {
      return const OfficerProvisioningException(
        code: 'unauthenticated',
        message: 'Your owner session expired. Sign in and try again.',
      );
    }
    if (error.code == 'permission-denied') {
      return const OfficerProvisioningException(
        code: 'permission-denied',
        message: 'Only the current business owner can manage staff.',
      );
    }
    return OfficerProvisioningException(
      code: error.code,
      reason: reason,
      message: error.message ??
          'We could not update this staff account. Please try again.',
    );
  }
}
