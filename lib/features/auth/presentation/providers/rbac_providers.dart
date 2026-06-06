import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/rbac/rbac_service.dart';
import '../../domain/rbac/permission.dart';
import 'auth_providers.dart';

final permissionProvider =
    Provider.family<bool, Permission>((ref, permission) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return RBACService.can(user, permission);
});