# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**In-Call Appointment Handler** — A Flutter cross-platform mobile app (iOS & Android) for receptionists to manage customer appointments during/after phone calls. Supports multi-institution (multi-tenant) usage with offline-first data persistence and cloud sync.

```
d:\Projects\Vibe test\Mobile Appointmenting\
├── lib/
│   ├── core/                    # Shared utilities (theme, router, database, services)
│   ├── features/                # Feature modules (auth, home, calendar, booking, etc.)
│   └── main.dart                # Entry point
├── app screens/                  # UI mockups
└── screen ref/                  # Screen reference images
```

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
- `hiveServiceProvider` in `lib/main.dart` provides HiveService singleton
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

| Entity | Core Fields |
|--------|-------------|
| **Customer** | `id`, `institutionId`, `name`, `phoneNumber`, `email`, `notes`, `synced` |
| **Appointment** | `id`, `institutionId`, `customerId`, `serviceId`, `startTime`, `endTime`, `status`, `staffId`, `stationId`, `notes`, `synced` |
| **CallLog** | `id`, `institutionId`, `phoneNumber`, `timestamp`, `direction`, `durationSeconds`, `isMissed`, `followedUp`, `linkedAppointmentId`, `handledByUserId`, `synced` |
| **Service** | `id`, `institutionId`, `title`, `defaultDurationMinutes`, `cost`, `description`, `isActive`, `synced` |
| **ServiceStation** | `id`, `institutionId`, `name`, `synced` |
| **AppointmentService** | `appointmentId`, `serviceId`, `quantity` (line items) |
| **SyncQueueItem** | `id`, `tableName`, `recordId`, `action`, `createdAt` |

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

Dummy data auto-seeds on app startup via `lib/seed_dummy_data.dart` (called in `main.dart` after `HiveService.init()`):
```dart
Future<void> seedDummyData(HiveService hiveService, {bool force = false}) async
```
To re-seed, use the `force` parameter or call `HiveService.clearAllData()`.

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, database initialization, error handling, seed data, `hiveServiceProvider` definition |
| `lib/app.dart` | Root MaterialApp with theme and router |
| `lib/core/router/app_router.dart` | GoRouter configuration, auth redirect logic |
| `lib/core/database/hive_service.dart` | HiveService with all CRUD operations and stream methods |
| `lib/seed_dummy_data.dart` | Seeds sample data for testing |
| `lib/core/theme/app_theme.dart` | Theme configuration |
| `lib/core/theme/app_colors.dart` | Design system color tokens |
| `lib/core/theme/app_spacing.dart` | Spacing and radius constants |
| `lib/core/theme/app_typography.dart` | Typography styles |
| `lib/core/services/call_detection_service.dart` | Call detection integration |
| `lib/core/services/call_recording_service.dart` | Call recording via device microphone |
| `lib/features/home/presentation/screens/main_shell.dart` | Bottom navigation shell with 5 tabs |
| `lib/features/calendar/presentation/screens/calendar_screen.dart` | Calendar view with busy day indicators |
| `lib/features/booking/presentation/screens/voice_booking_screen.dart` | Voice-to-booking with speech-to-text (disabled) |

## Navigation Routes

Bottom navigation (inside ShellRoute):
- `/home` — HomeScreen
- `/calendar` — CalendarScreen
- `/call-history` — CallHistoryScreen
- `/customers` — CustomersScreen
- `/settings` — SettingsScreen

Full-screen routes (outside shell):
- `/booking` — New appointment (accepts `?phone=`, `?callLogId=`, `?date=` query params for pre-filling)
- `/booking/edit/:id` — Edit appointment
- `/booking/confirmation/:appointmentId` — Booking confirmation
- `/appointment/:id` — Appointment detail view
- `/customer/:id` — Customer profile
- `/services` — Service management

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

`hiveServiceProvider` is defined in `lib/main.dart` and must be overridden in the `ProviderScope`.

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

- Auth state managed via `AuthStateNotifier` in `lib/features/auth/presentation/providers/auth_provider.dart`
- GoRouter `redirect` callback checks `authState.status == AuthStatus.authenticated`
- Unauthenticated users redirected to `/login`
- Authenticated users redirected away from auth routes to `/home`
- **Secure Storage:** `flutter_secure_storage` used for storing auth tokens securely on device

## Splash Screen

Configured via `flutter_native_splash.yaml` with Solar Orange (#904D00) background.

## Bug Fix History (Selected)

| Bug | Cause | Fix |
|-----|-------|-----|
| Call History spinner forever | `StreamController.broadcast` with `onListen` fires AFTER subscription; seed data events lost | Fresh `StreamController` with immediate `controller.add()` before returning |
| Stream "already listened" error | Hive's `Box.watch()` is single-subscription; `broadcast()` doesn't forward initial events | Same fix as above — use fresh `StreamController` |
| `insertSyncItem` missing ID | Did not set `item.id = key` unlike other insert methods | Added `item.id = key` assignment |
| seedDummyData not tracking IDs | Returned IDs not captured during bulk insert | Track all: `idList.add(id!)` after each insert |
| seedDummyData couldn't reseed | Guard returned early if data existed | Added `force` parameter and `clearAllData()` method |
| BookingScreen close crash | `context.pop()` fails with no stack to pop | Check `context.canPop()` first, fallback to `context.goNamed('home')` |
| Appointment cards not navigable | Tapping cards did nothing | Changed to `context.goNamed('appointment-detail', ...)` |

## Available Skills & MCP Tools

### Claude Code Skills (Slash Commands)

| Skill | Trigger | Use When |
|-------|---------|----------|
| `update-config` | `/update-config` | Configure settings, permissions, hooks, env vars |
| `simplify` | `/simplify` | Review code for reuse, quality, efficiency |
| `loop` | `/loop` | Set up recurring tasks/polls |
| `claude-api` | `/claude-api` | Building apps with Claude API/SDK |
| `ui-ux-pro-max` | `/ui-ux-pro-max` | UI/UX design intelligence (50+ styles, 161 palettes, 57 font pairings) |

### Stitch MCP Tools (Google AI UI Generation)

| Tool | Purpose |
|------|---------|
| `mcp__stitch__create_project` | Create new Stitch project |
| `mcp__stitch__list_projects` | List all Stitch projects |
| `mcp__stitch__get_project` | Get project details |
| `mcp__stitch__list_screens` | List screens in a project |
| `mcp__stitch__get_screen` | Get screen details |
| `mcp__stitch__generate_screen_from_text` | Generate screen from text prompt |
| `mcp__stitch__edit_screens` | Edit existing screens with text prompt |
| `mcp__stitch__generate_variants` | Generate variant designs |
| `mcp__stitch__create_design_system` | Create design system (colors, typography, shapes) |
| `mcp__stitch__update_design_system` | Update design system |
| `mcp__stitch__apply_design_system` | Apply design system to screens |
| `mcp__stitch__list_design_systems` | List design systems |

**Use Stitch when:** Generating new UI screens, creating design systems, editing/applying styles to existing screens.