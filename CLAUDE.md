# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**In-Call Appointment Handler** — A Flutter cross-platform mobile app (iOS & Android) for receptionists to manage customer appointments during/after phone calls.

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

**Pattern:** Feature-First Clean Architecture
- `lib/core/` — Shared utilities, theme, router, database
- `lib/features/` — Feature modules organized by domain (auth, home, calendar, booking, customers, services, settings, call_history)

**State Management:** Riverpod 2.6+ (`flutter_riverpod`, `riverpod_annotation`)
- Providers live in `presentation/providers/` within each feature
- `StreamProvider`/`FutureProvider` for reactive Hive data
- `hiveServiceProvider` in `features/home/presentation/providers/home_provider.dart` provides HiveService

**Routing:** GoRouter with ShellRoute for bottom navigation
- Routes defined in `lib/core/router/app_router.dart`
- Shell route provides 5-tab bottom navigation: Home, Calendar, Call History, Customers, Settings
- Full-screen routes outside shell for: `/booking`, `/booking/edit/:id`, `/booking/confirmation/:appointmentId`, `/appointment/:id`, `/customer/:id`, `/services`

**Database:** Hive NoSQL
- `HiveService` in `lib/core/database/hive_service.dart` — single source of truth for all CRUD
- Box names defined as constants in HiveService
- Stream methods for reactive updates: `watchAllCustomers()`, `watchUpcomingAppointments()`, `watchAppointmentsForDate()`, etc.
- Generated adapter files (*.g.dart) — do not edit manually

## Database Collections

| Model | TypeId | Purpose |
|-------|--------|---------|
| Customer | 0 | Customer info: name, phoneNumber, email, address |
| Service | 1 | Services offered: title, defaultDurationMinutes, cost, description |
| Appointment | 2 | Booked appointments: customerId, serviceId, startTime, endTime, status, staffId, stationId, notes |
| CallLog | 3 | Call history: phoneNumber, timestamp, direction, durationSeconds, isMissed, followedUp, linkedAppointmentId |
| SyncQueueItem | 4 | Queue items for backend sync |
| ServiceStation | 5 | Service stations/locations: name |
| AppointmentService | 7 | Line items for appointments: appointmentId, serviceId, quantity |

**Appointment statuses:** `upcoming`, `confirmed`, `ongoing`, `done`, `cancelled`

## Design System: "The Tactile Concierge"

**Aesthetic:** Organic Minimalism — "The Polished Pebble" with soft, rounded corners and generous whitespace.

**Primary Colors:**
- Primary: `#904D00` (Solar Orange Dark)
- Primary Container: `#FF8C00` (Pebble Orange)

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

Dummy data auto-seeds on app startup via `lib/seed_dummy_data.dart` (called in `main.dart` after `HiveService.init()`). The `force` parameter enables reseeding:
```dart
Future<void> seedDummyData(HiveService hiveService, {bool force = false}) async
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, database init, error handling, seed data |
| `lib/app.dart` | Root MaterialApp with theme and router |
| `lib/core/router/app_router.dart` | GoRouter config, auth redirect logic |
| `lib/core/database/hive_service.dart` | HiveService with all CRUD operations |
| `lib/seed_dummy_data.dart` | Seeds sample data for testing |
| `lib/core/theme/app_colors.dart` | Design system color tokens |
| `lib/core/theme/app_spacing.dart` | Spacing and radius constants |
| `lib/features/home/presentation/providers/home_provider.dart` | HiveService provider and data providers |
| `lib/features/booking/presentation/screens/booking_screen.dart` | New/edit appointment (supports `appointmentId` for edit mode) |
| `lib/features/booking/presentation/screens/appointment_detail_screen.dart` | View appointment details |
| `lib/features/calendar/presentation/screens/calendar_screen.dart` | Calendar with busy day indicators |

## Navigation Routes

Bottom navigation (inside ShellRoute):
- `/home` — HomeScreen
- `/calendar` — CalendarScreen
- `/call-history` — CallHistoryScreen
- `/customers` — CustomersScreen
- `/settings` — SettingsScreen

Full-screen routes (outside shell):
- `/booking` — New appointment (accepts `?phone=`, `?callLogId=`, `?date=` query params)
- `/booking/edit/:id` — Edit appointment (pass `appointmentId`)
- `/booking/confirmation/:appointmentId` — Booking confirmation
- `/appointment/:id` — Appointment detail view
- `/customer/:id` — Customer profile
- `/services` — Service management

## Provider Organization

Each feature has providers in `presentation/providers/`. Use `ref.watch(homeHiveProvider)` to access HiveService:
```dart
final homeHiveProvider = Provider<HiveService>((ref) => ref.watch(hiveServiceProvider));
```

## Bug Fix History

### Hive Stream Bugs (Call History)

#### 1. "stream has already been listened to" Error
| Attribute | Value |
|-----------|-------|
| **Type** | Hive Single-Subscription Stream Error |
| **Symptom** | Tab navigation between "All Calls" and "Missed" tabs throws "bad state: stream has already been listened to" |
| **Root Cause** | Hive's `Box.watch()` is single-subscription. Original code used `StreamController.broadcast` which doesn't properly forward initial events |
| **Solution** | Use fresh `StreamController` (non-broadcast) with immediate `controller.add()` BEFORE returning stream |
| **Files** | `lib/core/database/hive_service.dart` |

#### 2. Call History Spinner Forever (Data Not Loading)
| Attribute | Value |
|-----------|-------|
| **Type** | Stream Timing / Event Drop |
| **Symptom** | Call History screen shows loading spinner indefinitely |
| **Root Cause** | `StreamController.broadcast` with `onListen` callback fires AFTER the watch subscription is set up. Seed data events were emitted and lost before listener attached |
| **Solution** | Call `controller.add()` IMMEDIATELY before returning stream - same working pattern as `watchAllAppointments()` |
| **Files** | `lib/core/database/hive_service.dart` |

#### 3. Duplicate watchAllCallLogs Definition
| Attribute | Value |
|-----------|-------|
| **Type** | Code Organization / Compile Issue |
| **Symptom** | Compile errors due to duplicate method definition |
| **Root Cause** | Two `watchAllCallLogs` definitions existed - one placed before `init()` at lines 22-31, and the actual implementation later |
| **Solution** | Removed duplicate early definition. Single implementation follows working stream pattern |
| **Files** | `lib/core/database/hive_service.dart` |

### Data Integrity Bugs

#### 4. insertSyncItem Missing ID Assignment
| Attribute | Value |
|-----------|-------|
| **Type** | Data Integrity Bug |
| **Symptom** | SyncQueueItem objects had null IDs after insert |
| **Root Cause** | `insertSyncItem()` did not set `item.id = key` unlike all other insert methods |
| **Solution** | Added `item.id = key` assignment before returning key |
| **Files** | `lib/core/database/hive_service.dart` |

#### 5. seedDummyData Not Tracking All IDs
| Attribute | Value |
|-----------|-------|
| **Type** | Data Integrity Bug |
| **Symptom** | Appointment IDs and CallLog IDs were not captured during bulk insert |
| **Root Cause** | Insert methods returned keys but these weren't stored for later reference |
| **Solution** | Changed to track all returned IDs: `final id = await hive.insertX(item); idList.add(id!);` |
| **Files** | `lib/seed_dummy_data.dart` |

#### 6. seedDummyData Could Not Reseed
| Attribute | Value |
|-----------|-------|
| **Type** | Development Workflow Bug |
| **Symptom** | Could not re-seed database during development - guard returned early if any data existed |
| **Root Cause** | Early return guard `if (existingCustomers.isNotEmpty) return;` prevented reseeding without manual file deletion |
| **Solution** | Added `force` parameter to `seedDummyData()` and `clearAllData()` method. `main.dart` passes `force: true` |
| **Files** | `lib/seed_dummy_data.dart`, `lib/core/database/hive_service.dart`, `lib/main.dart` |

### Navigation Bugs

#### 7. BookingScreen Close Button Error
| Attribute | Value |
|-----------|-------|
| **Type** | Navigation Error |
| **Symptom** | `context.pop()` fails when no navigation stack to pop |
| **Solution** | Use `context.canPop()` check first, fallback to `context.goNamed('home')` |
| **Files** | `lib/features/booking/presentation/screens/booking_screen.dart` |

#### 8. Appointment Detail Navigation Not Working
| Attribute | Value |
|-----------|-------|
| **Type** | Navigation Error |
| **Symptom** | Tapping appointment cards on Home screen did nothing |
| **Solution** | Changed to proper route-based navigation via `context.goNamed('appointment-detail', ...)` |
| **Files** | `lib/features/home/presentation/screens/home_screen.dart` |

### Feature Enhancements

#### 9. Calendar Busy Day Indicators
| Attribute | Value |
|-----------|-------|
| **Type** | Feature Enhancement |
| **Description** | Added color-coded dots on calendar dates showing appointment density per day |
| **Solution** | Provider calculates appointment counts per day, normalized to 0-1 level. `calendarBuilders.markerBuilder` renders colored dots |
| **Files** | `lib/features/calendar/presentation/screens/calendar_screen.dart` |

## Critical Stream Pattern (Bugs #1/#2 Root Cause)

**CORRECT - buffers initial data before listener subscribes:**
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

**WRONG - drops pre-listener events:**
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
- All box names and collection constants defined in `HiveService`
- `withValues(alpha: x)` instead of deprecated `withOpacity(x)`

## Spacing System (4-point grid)

```dart
// Base values
xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32

// Common use cases
screenPadding: 20, cardPadding: 16, sectionSpacing: 24, itemSpacing: 12

// Radii (matches design tokens above)
radiusSm: 12, radiusMd: 16, radiusLg: 24, radiusXl: 32, radiusFull: 9999
```
