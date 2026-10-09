import 'package:flutter/foundation.dart';

/// Product-scope switches for the current public release.
///
/// These switches describe deliberate release decisions, not runtime settings.
/// A deferred feature should remain hidden until its product scope, native
/// dependencies, permissions, and tests are explicitly approved for release.
abstract final class ReleaseScope {
  /// Placeholder destinations, unfinished billing, and destructive sample-data
  /// tooling are development aids only. They must not be reachable from a
  /// production binary submitted to either store.
  static const bool developmentOnlyDestinationsEnabled = !kReleaseMode;

  /// The first iOS release uses email/password authentication only. Google
  /// OAuth remains available on the platforms whose native configuration is
  /// already part of the release baseline.
  static bool get googleSignInEnabled =>
      defaultTargetPlatform != TargetPlatform.iOS;

  /// Google Calendar uses the same native Google OAuth redirect flow and is
  /// therefore outside the first iOS release scope.
  static bool get googleCalendarSyncEnabled =>
      defaultTargetPlatform != TargetPlatform.iOS;

  /// Voice-assisted booking is intentionally excluded from the MVP/first
  /// release. Dormant implementation code is retained for future development.
  static bool get voiceBookingEnabled => false;

  /// Keep call-derived KPIs visibly unavailable until Android ingestion and
  /// call-to-booking linkage pass the required real-device verification.
  static bool get callInsightsVerified => false;

  /// Staff KPIs include call-derived values and follow the same verification
  /// gate. Appointment attribution is collected now but is not presented as a
  /// complete performance view on its own.
  static bool get staffInsightsVerified => false;
}
