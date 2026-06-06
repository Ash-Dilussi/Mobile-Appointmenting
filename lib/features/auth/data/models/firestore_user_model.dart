import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/auth_user.dart';

class FirestoreUserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String role;
  final String institutionId;
  final bool isEmailVerified;
  final Timestamp createdAt;

  const FirestoreUserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    required this.institutionId,
    required this.isEmailVerified,
    required this.createdAt,
  });

  factory FirestoreUserModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FirestoreUserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      role: data['role'] as String? ?? 'unknown',
      institutionId: data['institutionId'] as String? ?? '',
      isEmailVerified: data['isEmailVerified'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'role': role,
        'institutionId': institutionId,
        'isEmailVerified': isEmailVerified,
        'createdAt': createdAt,
      };

  AuthUser toAuthUser() => AuthUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        role: UserRoleX.fromString(role),
        institutionId: institutionId,
        isEmailVerified: isEmailVerified,
        createdAt: createdAt.toDate(),
      );

  static FirestoreUserModel newUserSkeleton({
    required String uid,
    required String email,
    required String displayName,
    String? photoUrl,
    required bool isEmailVerified,
  }) =>
      FirestoreUserModel(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        role: 'unknown',
        institutionId: '',
        isEmailVerified: isEmailVerified,
        createdAt: Timestamp.now(),
      );
}