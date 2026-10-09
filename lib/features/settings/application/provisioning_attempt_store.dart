import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ProvisioningAttemptStore {
  Future<String?> readForUser(String uid);

  Future<void> writeForUser(String uid, String idempotencyKey);

  Future<void> clearForUser(String uid);
}

class SecureProvisioningAttemptStore implements ProvisioningAttemptStore {
  SecureProvisioningAttemptStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _keyPrefix = 'business_provisioning_attempt_';

  @override
  Future<String?> readForUser(String uid) =>
      _storage.read(key: '$_keyPrefix$uid');

  @override
  Future<void> writeForUser(String uid, String idempotencyKey) =>
      _storage.write(key: '$_keyPrefix$uid', value: idempotencyKey);

  @override
  Future<void> clearForUser(String uid) =>
      _storage.delete(key: '$_keyPrefix$uid');
}
