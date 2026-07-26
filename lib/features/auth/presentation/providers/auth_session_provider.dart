import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/hive_service.dart';
import '../../../../core/database/collections/institution.dart';
import '../../../../core/database/collections/user.dart';
import '../../../../core/auth/rbac.dart';
import '../../../../core/providers/hive_service_provider.dart';
import '../../domain/entities/auth_user.dart';

/// Extended auth state with multi-tenant context
class AuthSession {
  final String userId;
  final String email;
  final String? name;
  final String? institutionId;
  final Role? role;
  final bool hasCompletedOnboarding;

  const AuthSession({
    required this.userId,
    required this.email,
    this.name,
    this.institutionId,
    this.role,
    this.hasCompletedOnboarding = false,
  });

  bool get isOwner => role == Role.owner;
  bool get isOfficer => role == Role.officer;
  bool get hasInstitution => institutionId != null && institutionId!.isNotEmpty;

  AuthSession copyWith({
    String? userId,
    String? email,
    String? name,
    String? institutionId,
    Role? role,
    bool? hasCompletedOnboarding,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      institutionId: institutionId ?? this.institutionId,
      role: role ?? this.role,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

/// Multi-tenant auth session notifier
class AuthSessionNotifier extends StateNotifier<AuthSession?> {
  final HiveService _hiveService;

  AuthSessionNotifier(this._hiveService) : super(null);

  /// Load session for a user from Hive User table
  Future<void> loadSession(String email) async {
    final user = _hiveService.getUserByEmail(email);
    if (user != null) {
      final institution = user.institutionId != null
          ? _hiveService.getInstitutionById(user.institutionId!)
          : null;
      state = AuthSession(
        userId: user.id,
        email: user.email,
        name: user.name,
        institutionId: user.institutionId,
        role: user.role == 'owner' ? Role.owner : Role.officer,
        hasCompletedOnboarding: institution != null,
      );
    }
  }

  /// Restores [AuthSession] directly from a cached or stream-emitted [AuthUser].
  /// No secondary Hive lookup — all data is on the [AuthUser] object already.
  Future<void> loadSessionFromAuthUser(AuthUser authUser) async {
    state = AuthSession(
      userId: authUser.uid,
      email: authUser.email,
      name: authUser.displayName,
      institutionId: authUser.institutionId,
      role: authUser.role == UserRole.owner ? Role.owner : Role.officer,
      hasCompletedOnboarding: authUser.isLinkedToInstitution,
    );
  }

  /// Create a new institution (Path A - New Owner)
  Future<AuthSession> createInstitution({
    required String userId,
    required String email,
    required String name,
    required String institutionName,
    required String themePreset,
  }) async {
    // Create institution
    final institutionId = 'inst_${DateTime.now().millisecondsSinceEpoch}';
    final institution = Institution()
      ..id = institutionId
      ..name = institutionName
      ..themePreset = themePreset
      ..ownerId = userId;

    await _hiveService.insertInstitution(institution);

    // Create user with owner role
    final user = User()
      ..id = userId
      ..institutionId = institutionId
      ..email = email
      ..name = name
      ..role = 'owner';

    await _hiveService.insertUser(user);

    state = AuthSession(
      userId: userId,
      email: email,
      name: name,
      institutionId: institutionId,
      role: Role.owner,
      hasCompletedOnboarding: true,
    );

    return state!;
  }

  /// Join existing institution (Path B - Officer)
  Future<AuthSession> joinInstitution({
    required String userId,
    required String email,
    required String name,
    required String institutionId,
    required String role,
  }) async {
    final user = User()
      ..id = userId
      ..institutionId = institutionId
      ..email = email
      ..name = name
      ..role = role;

    await _hiveService.insertUser(user);

    state = AuthSession(
      userId: userId,
      email: email,
      name: name,
      institutionId: institutionId,
      role: role == 'owner' ? Role.owner : Role.officer,
      hasCompletedOnboarding: true,
    );

    return state!;
  }

  /// Check if user exists in database
  User? findUserByEmail(String email) {
    return _hiveService.getUserByEmail(email);
  }

  /// Get institution for current session
  Institution? get currentInstitution {
    if (state?.institutionId == null) return null;
    return _hiveService.getInstitutionById(state!.institutionId!);
  }

  /// Clear session on sign out
  void clearSession() {
    state = null;
  }

  /// Updates display name in-memory after a local profile save.
  /// Call this after writing the updated name to Hive cache.
  void updateName(String displayName) {
    if (state == null) return;
    state = state!.copyWith(name: displayName);
  }
}

/// Provider for multi-tenant auth session
final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession?>((ref) {
  final hiveService = ref.watch(hiveServiceProvider);
  return AuthSessionNotifier(hiveService);
});

/// Convenience provider to check if user has completed onboarding
final hasCompletedOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(authSessionProvider)?.hasCompletedOnboarding ?? false;
});

/// Convenience provider to get current institution
final currentInstitutionProvider = Provider<Institution?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session?.institutionId == null) return null;
  final hiveService = ref.watch(hiveServiceProvider);
  return hiveService.getInstitutionById(session!.institutionId!);
});

/// Convenience provider to check if current user is owner
final isOwnerProvider = Provider<bool>((ref) {
  return ref.watch(authSessionProvider)?.isOwner ?? false;
});
