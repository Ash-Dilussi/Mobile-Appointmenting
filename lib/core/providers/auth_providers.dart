import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/google_auth_service.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});