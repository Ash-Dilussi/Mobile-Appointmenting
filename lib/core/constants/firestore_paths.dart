// Firestore collection and document path constants
class FirestorePaths {
  FirestorePaths._();

  static const String users = 'users';
  static const String institutions = 'institutions';
  static const String officers = 'officers';

  static String userDoc(String uid) => '$users/$uid';
  static String institutionDoc(String id) => '$institutions/$id';
  static String officersSubcol(String institutionId) =>
      '$institutions/$institutionId/$officers';
  static String officerDoc(String institutionId, String uid) =>
      '$institutions/$institutionId/$officers/$uid';
}