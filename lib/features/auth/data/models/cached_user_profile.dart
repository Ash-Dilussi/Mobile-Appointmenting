import 'package:hive/hive.dart';
import '../../domain/entities/auth_user.dart';

part 'cached_user_profile.g.dart';

@HiveType(typeId: 10)
class CachedUserProfile extends HiveObject {
  @HiveField(0) final String uid;
  @HiveField(1) final String email;
  @HiveField(2) final String displayName;
  @HiveField(3) final String? photoUrl;
  @HiveField(4) final String roleString;
  @HiveField(5) final String institutionId;
  @HiveField(6) final bool isEmailVerified;
  @HiveField(7) final int createdAtMs;

  CachedUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.roleString,
    required this.institutionId,
    required this.isEmailVerified,
    required this.createdAtMs,
  });

  factory CachedUserProfile.fromAuthUser(AuthUser user) => CachedUserProfile(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        roleString: user.role.name,
        institutionId: user.institutionId,
        isEmailVerified: user.isEmailVerified,
        createdAtMs: user.createdAt.millisecondsSinceEpoch,
      );

  AuthUser toAuthUser() => AuthUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        role: UserRoleX.fromString(roleString),
        institutionId: institutionId,
        isEmailVerified: isEmailVerified,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      );
}