import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;

class GoogleAuthService {
  static const _scopes = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/calendar.readonly',
  ];

  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.disconnect();

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  bool get isSignedIn => _googleSignIn.currentUser != null;

  Future<http.Client?> get authenticatedClient async {
    final account = _googleSignIn.currentUser;
    if (account == null) return null;
    return _googleSignIn.authenticatedClient();
  }
}