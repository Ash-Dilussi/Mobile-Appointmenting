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
  final bool shouldPromptPasswordChange;

  const AuthSession({
    required this.userId,
    required this.email,
    this.name,
    this.institutionId,
    this.role,
    this.hasCompletedOnboarding = false,
    this.shouldPromptPasswordChange = false,
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
    bool? shouldPromptPasswordChange,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      institutionId: institutionId ?? this.institutionId,
      role: role ?? this.role,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      shouldPromptPasswordChange:
          shouldPromptPasswordChange ?? this.shouldPromptPasswordChange,
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
        role: _roleFromStoredValue(user.role),
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
      role: _roleFromAuthUser(authUser.role),
      hasCompletedOnboarding: authUser.isLinkedToInstitution,
      shouldPromptPasswordChange: authUser.shouldPromptPasswordChange,
    );
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

  void acknowledgePasswordChangePrompt() {
    if (state == null) return;
    state = state!.copyWith(shouldPromptPasswordChange: false);
  }
}

Role? _roleFromStoredValue(String role) => switch (role) {
      'owner' => Role.owner,
      'officer' => Role.officer,
      _ => null,
    };

Role? _roleFromAuthUser(UserRole role) => switch (role) {
      UserRole.owner => Role.owner,
      UserRole.officer => Role.officer,
      UserRole.unknown => null,
    };

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
