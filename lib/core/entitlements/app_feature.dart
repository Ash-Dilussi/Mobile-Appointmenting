// lib/core/entitlements/app_feature.dart
//
// SINGLE SOURCE OF TRUTH for every named capability in the app.
// Rules:
//  - Never use raw strings like 'callRecording' anywhere else in the codebase.
//  - Add new features here first, then add them to plan_tier.dart's matrix.
//  - The comment on each member is the human-readable name shown in upgrade UI.

enum AppFeature {
  // ── Scheduling — always free ──────────────────────────────────────────────
  /// Basic appointment / booking management
  basicScheduling,

  /// View and manage your own call log history
  callLog,

  /// Simple dashboard stats (counts, basic summaries)
  basicReporting,

  // ── Pro tier ─────────────────────────────────────────────────────────────
  /// Auto-record calls and store audio files (MainActivity.kt already wired)
  callRecording,

  /// Full analytics: trends, filters, export-ready charts
  advancedAnalytics,

  /// Export call logs and reports to CSV / PDF
  exportData,

  /// Invite additional staff to the institution
  multiUser,

  /// Unlock all colour theme presets beyond the default
  customTheme,

  /// Recurring / repeating appointment rules
  recurringScheduling,

  // ── Enterprise tier ───────────────────────────────────────────────────────
  /// REST API access for third-party integrations
  apiAccess,

  /// Remove Bookly branding from client-facing screens
  whiteLabel,

  /// Dedicated support channel
  prioritySupport,
}

/// Human-readable labels used in UpgradeScreen / FeatureGate tooltips.
extension AppFeatureLabel on AppFeature {
  String get displayName {
    switch (this) {
      case AppFeature.basicScheduling:
        return 'Basic Scheduling';
      case AppFeature.callLog:
        return 'Call Log';
      case AppFeature.basicReporting:
        return 'Basic Reporting';
      case AppFeature.callRecording:
        return 'Call Recording';
      case AppFeature.advancedAnalytics:
        return 'Advanced Analytics';
      case AppFeature.exportData:
        return 'Export Data';
      case AppFeature.multiUser:
        return 'Multi-User Access';
      case AppFeature.customTheme:
        return 'Custom Themes';
      case AppFeature.recurringScheduling:
        return 'Recurring Appointments';
      case AppFeature.apiAccess:
        return 'API Access';
      case AppFeature.whiteLabel:
        return 'White Label';
      case AppFeature.prioritySupport:
        return 'Priority Support';
    }
  }

  String get upgradeReason {
    switch (this) {
      case AppFeature.callRecording:
        return 'Automatically record and store calls for review and compliance.';
      case AppFeature.advancedAnalytics:
        return 'Get deep insight into trends, team performance, and booking patterns.';
      case AppFeature.exportData:
        return 'Export your data to CSV or PDF anytime.';
      case AppFeature.multiUser:
        return 'Invite your whole team and manage permissions.';
      case AppFeature.customTheme:
        return 'Brand your app with your company colours.';
      case AppFeature.recurringScheduling:
        return 'Set up repeating appointments with a single click.';
      case AppFeature.apiAccess:
        return 'Connect Bookly to your existing tools via REST API.';
      case AppFeature.whiteLabel:
        return 'Remove Bookly branding for a fully white-labelled experience.';
      case AppFeature.prioritySupport:
        return 'Get a dedicated support channel with faster response times.';
      default:
        return 'Upgrade your plan to unlock this feature.';
    }
  }
}
