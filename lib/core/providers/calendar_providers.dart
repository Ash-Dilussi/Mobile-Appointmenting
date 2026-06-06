import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/google_calendar_service.dart';
import 'auth_providers.dart';

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService(ref.watch(googleAuthServiceProvider));
});