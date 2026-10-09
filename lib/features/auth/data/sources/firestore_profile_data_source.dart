import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../models/firestore_user_model.dart';

class FirestoreProfileDataSource {
  final FirebaseFirestore _firestore;

  FirestoreProfileDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Future<FirestoreUserModel?> fetchProfile(String uid) async {
    final doc = await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .withConverter<FirestoreUserModel>(
          fromFirestore: (snap, _) => FirestoreUserModel.fromDocument(snap),
          toFirestore: (model, _) => model.toMap(),
        )
        .get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> upsertProfile(FirestoreUserModel model) async {
    await _firestore
        .collection(FirestorePaths.users)
        .doc(model.uid)
        .set(model.toMap(), SetOptions(merge: true));
  }

  Future<void> acknowledgePasswordChangePrompt(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).update({
      'shouldPromptPasswordChange': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<FirestoreUserModel?> watchProfile(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).snapshots().map(
        (snap) => snap.exists ? FirestoreUserModel.fromDocument(snap) : null);
  }
}
