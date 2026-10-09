# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues for `Ash-Dilussi/Mobile-Appointmenting`. See `docs/agents/issue-tracker.md`.

### Triage labels

Triage uses the standard `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix` labels. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context product whose authoritative domain documentation lives in the parent product workspace. See `docs/agents/domain.md`.

### Current project status

Read `docs/agents/project-status.md` for the dated working-tree snapshot,
implemented scope, verification state, and release blockers. Treat
"implemented in code" and "release-validated" as separate claims.

## Project Overview

**In-Call Appointment Handler** — A Flutter cross-platform mobile app (iOS & Android) for receptionists to manage customer appointments during/after phone calls. Supports multi-institution (multi-tenant) usage with offline-first data persistence and cloud sync.

**Current status (September 20, 2026):** MVP functionality is broadly present
in the integration working tree, including booking/CRM improvements, semantic
theming, Insights, and tenant-scoped reporting foundations. The app is not yet
release-ready: the working tree is large and uncommitted, the auth
profile-recovery design is still pending implementation, platform compliance
and cloud-sync verification remain open, and call/staff KPI release gates need
real-device evidence. See `docs/agents/project-status.md` for the precise
snapshot and validation notes.

```
d:\Projects\Vibe test\Mobile Appointmenting\
├── lib/
│   ├── core/                    # Shared utilities (theme, router, database, services)
│   ├── features/                # Feature modules (auth, home, calendar, booking, etc.)
│   └── main.dart                # Entry point
├── app screens/                  # UI mockups
└── screen ref/                  # Screen reference images
```

### MVP / First Release Scope (Locked September 2, 2026)

- Voice-assisted booking is intentionally excluded from the MVP. The booking
  microphone action is hidden by `ReleaseScope.voiceBookingEnabled`; retain the
  dormant implementation for future development.
- Do not restore `speech_to_text` or expose the voice UI as part of unrelated
  MVP work. Treat it as a separately planned feature requiring native build,
  permission/privacy, UX, and automated-test validation.
- Other roadmap items remain future work and should be delivered incrementally
  after MVP hardening.
- Verified local Dart SDK: `3.8.1` stable on `windows_x64`.

## Architecture

**Pattern:** Feature-First Clean Architecture with Local-First Sync Bridge

```
lib/
├── core/                   # Global components (Router, Theme, Constants, Database, Services)
├── shared/                 # Reusable widgets (Buttons, InputFields)
└── features/
    └── [feature_name]/
        ├── domain/         # Models & Repository interfaces
        ├── data/           # Repository implementations
        └── presentation/   # Riverpod providers, Screens, & Widgets
```

**State Management:** Riverpod 2.6+ (`flutter_riverpod`, `riverpod_annotation`)

- Providers live in `presentation/providers/` within each feature
- Use `StreamProvider`/`FutureProvider` for reactive Hive data
- `hiveServiceProvider` in `lib/core/providers/hive_service_provider.dart`
  provides the overridable HiveService dependency; `main.dart` supplies the
  initialized instance through `ProviderScope`
- Repository pattern decouples UI from storage

**Routing:** GoRouter with ShellRoute for bottom navigation

- Routes defined in `lib/core/router/app_router.dart`
- Shell route provides 5-tab bottom navigation: Home, Calendar, Call History, Customers, Settings
- Full-screen routes outside shell for: `/booking`, `/booking/edit/:id`, `/booking/confirmation/:appointmentId`, `/appointment/:id`, `/customer/:id`, `/services`

**Database:** Hive NoSQL (local cache) + Firestore (cloud sync)

- `HiveService` in `lib/core/database/hive_service.dart` — single source of truth for all local CRUD
- Box names defined as constants in HiveService
- Stream methods for reactive updates: `watchAllCustomers()`, `watchUpcomingAppointments()`, etc.
- Generated adapter files (`*.g.dart`) — do not edit manually

## Multi-Tenant Data Model (PRD v3.0)

All records include `institutionId` for strict data isolation between businesses.

| Entity                 | Core Fields                                                                                                                                                     |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Customer**           | Nullable `id`/institution/timestamps; empty-safe `name`, `phoneNumber`, and contact text; independent `address`/`city`; optional `dob`; structured `notes`; `synced` |
| **Appointment**        | `id`, `institutionId`, `customerId`, `serviceId`, `startTime`, `endTime`, `status`, `staffId`, `stationId`, ordered structured `notes`, `synced`                |
| **AppointmentNote**    | Embedded note: stable UUID, required user-written title, optional description, `createdAt`, `updatedAt`; legacy appointment free text remains unmigrated       |
| **CallLog**            | `id`, `institutionId`, `phoneNumber`, `timestamp`, `direction`, `durationSeconds`, `isMissed`, `followedUp`, `linkedAppointmentId`, `handledByUserId`, `synced` |
| **Service**            | `id`, `institutionId`, `title`, `defaultDurationMinutes`, `cost`, `description`, `isActive`, `colorValue`, `synced`                                             |
| **ServiceStation**     | `id`, `institutionId`, `name`, `synced`                                                                                                                         |
| **AppointmentService** | `appointmentId`, `serviceId`, `quantity` (line items)                                                                                                           |
| **SyncQueueItem**      | `id`, `tableName`, `recordId`, `action`, `createdAt`                                                                                                            |
| **Institution**        | Internal tenant; user-facing Business details/theme/owner and nullable permanent `hasEverHadAdditionalStaff` deletion-safety marker                           |

**Appointment statuses:** `upcoming`, `confirmed`, `ongoing`, `done`, `cancelled`

## Sync Bridge Architecture

- **Read Flow:** UI watches `StreamProvider` → Listens to **Hive** → Firestore Snapshot Listener updates Hive filtered by `institutionId`
- **Write Flow:** User action → Notifier writes to **Hive** (instant UI update) → Adds to **Sync Queue** → `SyncController` pushes to **Firestore** when online
- **Conflict Policy:** Server Timestamp (Last Write Wins). "Conflict Detected" banner shown for critical collisions

## Design System: "The Tactile Concierge"

**Aesthetic:** Organic Minimalism — "The Polished Pebble" with soft, rounded corners and generous whitespace.

**Primary Colors:**

- Primary: `#904D00` (Solar Orange Dark)
- Primary Container: `#FF8C00` (Pebble Orange)
- On Primary Container: `#FFFFFF`

**Secondary Colors:**

- Secondary: `#5F5E5E` (Deep Charcoal)
- Surface: `#F9F9F9` (Off-White)
- Surface Container Lowest: `#FFFFFF` (Cards)

**Typography:** Inter font family (via `google_fonts` package)

**Corner Radii:**

- SM: 12px, MD: 16px, LG: 24px, XL: 32px, Full: 9999px

**No-Line Rule:** Boundaries use background color shifts, not 1px borders. Containment via tonal contrast.

**Glassmorphism:** For floating overlays — `surfaceContainerLowest` at 70% opacity with 20-32px backdrop blur.

**Buttons:** Full radius (9999px) or XL (32px), minimum height 56px. On press, scale to 96%.

### Theme Color Usage in Widgets and Components

All feature UI must obtain themeable colors from the active semantic scheme:

```dart
final colors = Theme.of(context).colorScheme;
```

Use `ColorScheme` roles for backgrounds, surfaces, text, icons, borders,
dividers, shadows, overlays, states, and gradients. Do not use `AppColors.*`,
raw `Color(0x...)`, or `Colors.*` in themeable widget UI; those values belong
in `AppColorSchemes`/theme construction. Pass semantic colors into shared
widgets that cannot read a `BuildContext`. Exceptions are restricted to
intentionally invariant system, legal-brand, or domain-status colors and must
include an inline reason plus contrast validation across all five presets and
both brightness modes. Derive opacity with `withValues(alpha: ...)`.

## Multi-Tenant Company Theming

Company color themes are stored in `Institution.themePreset` as a `StylePreset` enum name. The active preset is exposed via `stylePresetProvider` and applied to the `MaterialApp` in `app.dart` using `AppTheme.fromPreset()`.

**Five presets available:**
| Preset | Display Name | Primary Color |
|--------|-------------|---------------|
| `solarOrange` | Solar Orange | #904D00 |
| `clinicTeal` | Clinic Teal | #00796B |
| `midnightCharcoal` | Midnight Charcoal | #37474F |
| `forestGreen` | Forest Green | #2E7D32 |
| `royalPurple` | Royal Purple | #6A1B9A |

**How it works:**

- `stylePresetProvider` in `lib/core/theme/style_preset_provider.dart` reads `Institution.themePreset` via `currentInstitutionProvider`
- Falls back to `solarOrange` if no institution or themePreset is set
- `app.dart` watches `stylePresetProvider` and builds themes dynamically using `AppTheme.fromPreset(preset, brightness)`
- Theme changes propagate reactively across all screens without restart

**Owner workflow:** Settings > Edit Company > Theme Color selector (chip-based with color swatches)

## Common Commands

```bash
cd "Mobile Appointmenting"

# Clean and restore (fixes cache conflicts)
flutter clean && flutter pub get

# Generate code (Hive adapters, Riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
dart run build_runner watch --delete-conflicting-outputs

# Run the app
flutter run

# Lint analysis
flutter analyze

# Run a single test
flutter test test/path/to/test_file.dart

# Run all tests
flutter test

# Build for Android
flutter build apk --debug

# Build for iOS
flutter build ios --debug
```

## Seed Data

Dummy data seeds once in debug builds from `appInitProvider`, after Hive initialization. Normal startup uses `force: false` and preserves existing developer data:

```dart
Future<void> seedDummyData(HiveService hiveService, {bool force = false}) async
```

To explicitly re-seed during development, invoke the `force` parameter or call `HiveService.clearAllData()` from a deliberate developer action; never force-clear data on every startup.

## Key Files

| File                                                                  | Purpose                                                                                               |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `lib/main.dart`                                                       | App entry point, database initialization, error handling, seed data, and root provider overrides      |
| `lib/core/providers/hive_service_provider.dart`                       | Overridable `hiveServiceProvider` declaration                                                          |
| `lib/app.dart`                                                        | Root MaterialApp with theme and router                                                                |
| `lib/core/router/app_router.dart`                                     | GoRouter configuration, auth redirect logic                                                           |
| `lib/core/database/hive_service.dart`                                 | HiveService with all CRUD operations and stream methods                                               |
| `lib/seed_dummy_data.dart`                                            | Seeds sample data for testing                                                                         |
| `lib/core/theme/app_theme.dart`                                       | Theme configuration                                                                                   |
| `lib/core/theme/app_colors.dart`                                      | Design system color tokens                                                                            |
| `lib/core/theme/app_spacing.dart`                                     | Spacing and radius constants                                                                          |
| `lib/core/theme/app_typography.dart`                                  | Typography styles                                                                                     |
| `lib/core/widgets/unsaved_changes_guard.dart`                         | Shared baseline-aware X/system-Back guard for full-screen add/edit forms                              |
| `lib/core/services/call_detection_service.dart`                       | Call detection integration                                                                            |
| `lib/core/services/call_recording_service.dart`                       | Call recording via device microphone                                                                  |
| `lib/features/home/presentation/screens/main_shell.dart`              | Bottom navigation shell with 5 tabs                                                                   |
| `lib/features/calendar/presentation/screens/calendar_screen.dart`     | Calendar view with busy day indicators                                                                |
| `lib/core/config/release_scope.dart`                                 | Locked MVP release-scope switches; voice booking remains hidden                                       |
| `lib/features/booking/presentation/screens/booking_screen.dart`       | Booking flow with structured appointment-note editing plus dormant post-MVP voice-booking prototype    |
| `lib/features/customers/presentation/widgets/customer_note_card.dart` | Editable/read-only structured customer-note presentation                                               |
| `lib/features/booking/presentation/widgets/appointment_note_card.dart` | Shared editable/read-only structured appointment-note presentation                                    |

## Navigation Routes

Bottom navigation (inside ShellRoute):

- `/home` — HomeScreen
- `/calendar` — CalendarScreen
- `/call-history` — CallHistoryScreen
- `/customers` — CustomersScreen
- `/settings` — SettingsScreen

Full-screen routes (outside shell):

- `/business/setup` — solo/team fork for unlinked users; solo creates the real
  institution model and offers a skippable Calendar step. Both paths share the
  trusted `InstitutionRepository`/`provisionBusiness` callable boundary with a
  persisted idempotency key; retry repairs the same deterministic Business.
- `/booking` — New appointment (accepts `?customerId=`, `?phone=`, `?callLogId=`, `?date=` query params; customer id is resolved before phone fallback)
- `/booking/edit/:id` — Edit appointment
- `/booking/confirmation/:appointmentId` — Booking confirmation
- `/appointment/:id` — Appointment detail view
- `/customer/:id` — Customer profile
- `/services` — Service management
- `/insights` — tenant-scoped operational Insights from Settings; owner-only
  sections are authorized at route construction, while call/staff KPIs remain
  visibly gated pending real-device verification
- `/delete-account` — role-aware personal/business deletion confirmation;
  the trusted callable verifies staff history and current membership before
  accepting the simplified always-solo path
- `/coming-soon` — reusable temporary fallback for deliberately exposed,
  unfinished destinations; accepts a user-facing `feature` query parameter

### Coming Soon Navigation Pattern

Do not leave visible enabled controls with empty or TODO-only callbacks. During
development, route deliberately exposed unfinished destinations through the
single named route:

```dart
context.pushNamed(
  'coming-soon',
  queryParameters: const {'feature': 'Notifications'},
);
```

Use `pushNamed` to preserve Back behavior. Reuse
`lib/shared/screens/coming_soon_screen.dart`; do not create feature-specific
placeholder pages or snackbars. Track every trigger in the parent
`Concern_Tracking.md` Dead UI section. This fallback is not valid for auth
recovery, errors, loading/offline states, permissions, access control, billing,
legal/privacy/consent/safety/support obligations, and must not remain visible
in a production release.

## Provider Organization

Each feature has its providers in `presentation/providers/`:

- `auth_provider.dart` — AuthStateNotifier for authentication state
- `home_provider.dart` — UpcomingAppointmentsProvider, RecentCustomersProvider, etc.

Use `ref.watch(homeHiveProvider)` to access HiveService in feature widgets:

```dart
final homeHiveProvider = Provider<HiveService>((ref) {
  return ref.watch(hiveServiceProvider);
});
```

`hiveServiceProvider` is defined in
`lib/core/providers/hive_service_provider.dart` and must be overridden in the
root `ProviderScope`.

## Critical Hive Stream Pattern

Hive's `Box.watch()` is single-subscription. Using `StreamController.broadcast` drops initial events causing "stream has already been listened" errors and spinner-forever bugs.

**CORRECT — buffers initial data before listener subscribes:**

```dart
Stream<List<T>> watchAllItems() {
  final controller = StreamController<List<T>>();
  controller.add(getAllItems());  // IMMEDIATELY add before returning
  final subscription = _box.watch().listen((_) {
    controller.add(getAllItems());
  });
  controller.onCancel = () => subscription.cancel();
  return controller.stream;
}
```

**WRONG — drops pre-listener events:**

```dart
Stream<List<T>> watchAllItems() {
  return StreamController.broadcast(  // DON'T USE
    onListen: () => controller.add(getAllItems()),
  ).stream;
}
```

## Code Style

- Use `sealed` class for union types where appropriate
- Use Dart 3 switch expressions for pattern matching
- Keep widgets lean — no business logic in UI
- Use `StreamProvider`/`FutureProvider` for async data from Hive
- Database operations are async — use `async/await` in providers
- All box names and collection constants defined in `HiveService` class
- `withValues(alpha: x)` instead of deprecated `withOpacity(x)`
- Generated files (`*.g.dart`) should not be manually edited

## Spacing System (4-point grid)

```dart
// Base values
xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32

// Common use cases
screenPadding: 20, cardPadding: 16, sectionSpacing: 24, itemSpacing: 12

// Radii (matches design tokens above)
radiusSm: 12, radiusMd: 16, radiusLg: 24, radiusXl: 32, radiusFull: 9999
```

## Platform Compliance

Before platform or release work, read
`docs/agents/store-compliance-watchlist.md`. Its Spec 01–05 reminders are active
gates: surface the matching open deployment, console, legal, signing, and
real-device work whenever a task touches a listed trigger. The current Spec 04
technical draft is `docs/compliance/spec-04-privacy-and-store-mapping.md`.
Spec 04 v3 adds a Sri Lanka PDPA readiness gate: verify current Gazette and DPA
instruments at publication time and require counsel review of commencement,
controller/processor roles, DPO, DPIA, breach, rights, and cross-border flows.
Spec 05 source hardening is documented in
`docs/compliance/spec-05-store-release-engineering.md`: Android targets API 36,
release signing must fail closed without owner-supplied credentials, and
development placeholders/billing/sample-data tools must stay unreachable in
release mode. External signing, store-console, asset, and device gates remain
open until verified against the final binaries.
Never treat local implementation or tests as proof of deployment or store
acceptance.

When developing features, consider these platform guidelines for app review success:

### Apple App Store

- **Privacy Details:** Data collection disclosure required (phone numbers, contacts, etc.)
- **Background Modes:** Only when strictly necessary; call detection requires justification
- **Permissions:** Request at point of use with clear rationale
- **User Safety:** Content filtering for notes/comments

### Google Play

- **Privacy & Security:** Data safety form must match actual data handling
- **Sensitive Permissions:** `READ_PHONE_STATE`/`READ_CALL_LOG` require justification and privacy policy
- **Family Safety:** Follow Families Policy if targeting children

### General Checklist

- [ ] Privacy policy URL in app store listings
- [ ] Data collection explained in app description
- [ ] User consent before collecting sensitive data
- [ ] All permissions have clear in-app purpose
- [ ] No deceptive or misleading functionality

## Auth Flow

### Registration/Profile Provisioning

Follow the parent
`../AUTH_REGISTRATION_RECOVERY_FLOW.md` for every registration, login, Google
sign-in, cold-start auth restoration, Firestore `users/{uid}`, or Hive auth-cache
change. Firebase identity creation and application-profile provisioning are
separate states. Use an idempotent profile repair path, bound retries and
spinners, preserve successfully created accounts, and route unresolved setup to
an actionable recovery state. Do not allow a matching cached UID to suppress
repair of a profile known to be provisional, missing, or incomplete.

**Status:** This is the required target behavior; the documented implementation
gaps remain pending until the recovery work is completed and tested.

- Auth state managed via `AuthStateNotifier` in `lib/features/auth/presentation/providers/auth_provider.dart`
- GoRouter `redirect` callback checks `authState.status == AuthStatus.authenticated`
- Unauthenticated users redirected to `/login`
- Authenticated users redirected away from auth routes to `/home`
- **Secure Storage:** `flutter_secure_storage` used for storing auth tokens securely on device

## Splash Screen

Configured via `flutter_native_splash.yaml` with Solar Orange (#904D00) background.

## Bug Fix History (Selected)

| Bug                                      | Cause                                                                                                | Fix                                                                                                                                        |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Sparse local customers / missing ids | Hive cast absent strings/timestamps as required values and customer insert did not persist the generated key | Generate typed defaults, make timestamps nullable, persist/backfill ids from Hive keys, and guard customer UI/actions |
| Legacy customer DOB/city and booking handoff | Appended DOB lacked an explicit compatibility default, Town reused address, and Profile handed Booking only a phone | Add legacy-safe DOB/city fields and generated adapter, keep address/city independent, and resolve customerId before phone fallback |
| Startup splash stall / long delay        | Auth resolution rebuilt GoRouter at `/splash`, transition-only listeners missed completed init, and remote/maintenance work gated navigation | Keep router stable, navigate from durable init state, follow live auth state, use cached entitlements with background refresh, and remove destructive startup races |
| Call History spinner forever             | `StreamController.broadcast` with `onListen` fires AFTER subscription; seed data events lost         | Fresh `StreamController` with immediate `controller.add()` before returning                                                                |
| Stream "already listened" error          | Hive's `Box.watch()` is single-subscription; `broadcast()` doesn't forward initial events            | Same fix as above — use fresh `StreamController`                                                                                           |
| `insertSyncItem` missing ID              | Did not set `item.id = key` unlike other insert methods                                              | Added `item.id = key` assignment                                                                                                           |
| seedDummyData not tracking IDs           | Returned IDs not captured during bulk insert                                                         | Track all: `idList.add(id!)` after each insert                                                                                             |
| seedDummyData couldn't reseed            | Guard returned early if data existed                                                                 | Added `force` parameter and `clearAllData()` method                                                                                        |
| BookingScreen close crash                | `context.pop()` fails with no stack to pop                                                           | Check `context.canPop()` first, fallback to `context.goNamed('home')`                                                                      |
| Appointment cards not navigable          | Tapping cards did nothing                                                                            | Connect appointment history entries to the read-only `appointment-detail` route                                                           |
| Existing Booking tiles opened the wrong destination | The desired destination changed during routing refinement while earlier flows also replaced their origin | Push `appointment-detail` from Dashboard/Calendar, keep Edit as a second-step `booking-edit` action, preserve caller stacks, and retain Home Quick Book |
| Upcoming Booking tiles inert after restart | Appointment insert assigned the generated Hive key only in memory, so cold-reloaded records had null IDs and disabled tile callbacks | Persist the assigned ID, backfill historical IDs from canonical Hive keys at startup, and verify both paths through disk-backed tests |
| authSessionProvider empty on fresh login | Explicit auth methods (`register`/`signIn`) set AuthState but never called `loadSessionFromAuthUser` | Added `await _ref.read(authSessionProvider.notifier).loadSessionFromAuthUser(user)` before `_routeByInstitution` in all three auth methods |
| Login error banner persisted | `MaterialBanner` visibility was owned by `ScaffoldMessenger`; later source fixes were not present in the older compiled APK still running on the emulator | Replace it with a page-owned warning, auto-clear after 10 seconds, assert no `MaterialBanner` exists, then rebuild/reinstall and verify both paths on the Pixel Tablet |
| KPI data could cross tenants or imply unavailable calls were zero | Legacy global reads/write paths omitted institution scope, status outcomes were not actionable, and completed native calls were transient | Stamp and scope active data paths, add appointment outcomes, aggregate via institution-required HiveService queries, visibly exclude legacy null-tenant rows, and gate call/staff KPIs until real-device verification |
| Account deletion was local-only/nonexistent | A Hive row deletion could not coordinate Firebase Auth, Firestore membership/institution data, OAuth cleanup, or other devices | Add the trusted callable, role-aware Settings flow, verified-email Hosting page, subscription guard, and next-auth-check Hive purge; deployment/E2E validation remains required |
| Solo/team provisioning and Officer lifecycle could diverge | Business creation/linking and Officer removal were split between direct client and local writes; the staff-history marker was convention-only | Use idempotent callable transactions behind `InstitutionRepository`, server-authoritative Officer create/remove, remote-first cache invalidation, permanent history, and a daily orphan reconciler; deployment/device validation remains required |

## Available Skills & MCP Tools

### Claude Code Skills (Slash Commands)

| Skill           | Trigger          | Use When                                                               |
| --------------- | ---------------- | ---------------------------------------------------------------------- |
| `update-config` | `/update-config` | Configure settings, permissions, hooks, env vars                       |
| `simplify`      | `/simplify`      | Review code for reuse, quality, efficiency                             |
| `loop`          | `/loop`          | Set up recurring tasks/polls                                           |
| `claude-api`    | `/claude-api`    | Building apps with Claude API/SDK                                      |
| `ui-ux-pro-max` | `/ui-ux-pro-max` | UI/UX design intelligence (50+ styles, 161 palettes, 57 font pairings) |

### Stitch MCP Tools (Google AI UI Generation)

| Tool                                     | Purpose                                           |
| ---------------------------------------- | ------------------------------------------------- |
| `mcp__stitch__create_project`            | Create new Stitch project                         |
| `mcp__stitch__list_projects`             | List all Stitch projects                          |
| `mcp__stitch__get_project`               | Get project details                               |
| `mcp__stitch__list_screens`              | List screens in a project                         |
| `mcp__stitch__get_screen`                | Get screen details                                |
| `mcp__stitch__generate_screen_from_text` | Generate screen from text prompt                  |
| `mcp__stitch__edit_screens`              | Edit existing screens with text prompt            |
| `mcp__stitch__generate_variants`         | Generate variant designs                          |
| `mcp__stitch__create_design_system`      | Create design system (colors, typography, shapes) |
| `mcp__stitch__update_design_system`      | Update design system                              |
| `mcp__stitch__apply_design_system`       | Apply design system to screens                    |
| `mcp__stitch__list_design_systems`       | List design systems                               |

**Use Stitch when:** Generating new UI screens, creating design systems, editing/applying styles to existing screens.
