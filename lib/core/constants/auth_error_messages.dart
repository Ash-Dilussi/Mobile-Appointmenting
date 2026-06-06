const Map<String, String> kAuthErrorMessages = {
  'user-not-found': 'No account found with this email address.',
  'wrong-password': 'Incorrect password. Please try again.',
  'invalid-credential': 'The email or password is incorrect.',
  'email-already-in-use': 'An account already exists with this email.',
  'invalid-email': 'Please enter a valid email address.',
  'weak-password': 'Password must be at least 6 characters.',
  'user-disabled': 'This account has been disabled. Contact support.',
  'network-request-failed': 'No internet connection. Please check your network.',
  'too-many-requests': 'Too many attempts. Please wait and try again.',
  'operation-not-allowed': 'This sign-in method is not enabled.',
  'requires-recent-login': 'Please sign in again to continue.',
  'account-exists-with-different-credential':
      'An account with this email exists using a different sign-in method.',
  'google_sign_in_cancelled': 'Google sign-in was cancelled.',
  'no_firebase_user': 'Authentication failed. Please try again.',
  'token_revoked': 'Your session has expired. Please sign in again.',
  'unknown': 'Something went wrong. Please try again.',
};

String authErrorMessage(String? code) =>
    kAuthErrorMessages[code] ?? kAuthErrorMessages['unknown']!;