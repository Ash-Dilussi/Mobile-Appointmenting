// Pure Dart entity — zero imports from Flutter, Firebase, or Hive.
// This is the canonical user object passed through the entire app.
class AuthUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final UserRole role;
  final String institutionId;
  final bool isEmailVerified;
  final bool shouldPromptPasswordChange;
  final DateTime createdAt;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.institutionId,
    required this.isEmailVerified,
    this.shouldPromptPasswordChange = false,
    required this.createdAt,
  });

  bool get isLinkedToInstitution => institutionId.isNotEmpty;
  bool get isOwner => role == UserRole.owner;
  bool get isOfficer => role == UserRole.officer;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    UserRole? role,
    String? institutionId,
    bool? isEmailVerified,
    bool? shouldPromptPasswordChange,
    DateTime? createdAt,
  }) {
    return AuthUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      institutionId: institutionId ?? this.institutionId,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      shouldPromptPasswordChange:
          shouldPromptPasswordChange ?? this.shouldPromptPasswordChange,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && runtimeType == other.runtimeType && uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() =>
      'AuthUser(uid: $uid, role: $role, institutionId: $institutionId)';
}

enum UserRole { owner, officer, unknown }

extension UserRoleX on UserRole {
  String get name => toString().split('.').last;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.unknown,
    );
  }
}
