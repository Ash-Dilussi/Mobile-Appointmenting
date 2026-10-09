# Project Status for Agents

**Snapshot date:** September 26, 2026  
**Branch:** `main`  
**Package version:** `1.0.0+1`  
**Overall state:** Active MVP integration and hardening; not release-ready

This file is the short operational status for agents entering the repository.
The parent product documents remain authoritative for scope, behavior, and
locked decisions. Update this snapshot when a material feature, blocker,
validation result, or release-readiness condition changes.

## Executive Summary

The Flutter app has broad MVP functionality in the current working tree:
authentication and onboarding, multi-tenant data scoping, appointment booking,
customer CRM, services and service locations, calendar views, call history,
staff/settings flows, institution theming, and operational Insights. Recent
hardening added structured customer and appointment notes, persisted/backfilled
Hive identities, required booking locations, unsaved-change protection,
semantic status/badge components, tenant-scoped analytics, and direct Call
History-to-Booking navigation.

Unlinked authenticated users now enter the solo/team Business Setup fork; Home
and Settings retain a fallback CTA. Both paths share an idempotent trusted
callable transaction for Business creation and Firestore membership before
Hive cache publication. Owners provision and remove Officer membership through
server-authoritative callables, and Officers may sign in on separate devices. Operational
bookings/customers/calls remain device-local by explicit product decision.
Temporary-password change is optional and the Settings action updates the real
Firebase Auth password.

This is an integration workspace, not a clean release candidate. At the time
of this snapshot, git reports 130 modified/deleted tracked files and 71
untracked paths relative to commit `21ebfa8` (July 27, 2026). The tree combines
pre-existing user work with the changes recorded here; preserve unrelated
edits. Do not infer that a feature is shipped merely
because it exists in this working tree or in a status document.

## Implemented in the Working Tree

- Five-tab application shell: Home, Calendar, Call History, Customers, and
  Settings, with stack-preserving detail and edit navigation.
- Local-first Hive data layer with Firebase authentication/Firestore
  integration, institution-aware active query paths, and startup maintenance
  for historical missing customer, service, station, and appointment IDs.
- Appointment create/edit/detail/confirmation flow with customer resolution,
  quick-add, multiple services, required service-station selection, structured
  notes, outcomes, conflict checks, and optional Android Google Calendar sync.
- Customer CRM with search, permission-free OS-owned single-contact import,
  independent address/city, optional DOB and derived age, structured notes,
  profile history, and guarded actions for sparse legacy records.
- Public-v1 call activity no longer reads the Android system call log or starts
  automatic recording. Calls initiated from a known customer context are
  persisted with customer/staff attribution before the external dialer opens;
  the Calls screen labels them "Call initiated" and discloses its scope.
- Service and service-location management with service colors, owner/officer
  UI controls, persisted IDs, and Service Detail-to-Booking handoff.
- Tenant-scoped Insights for appointments, customers, services, booked value,
  calls, and staff. Call and staff sections remain release-gated pending
  real-device ingestion/linkage verification.
- Semantic `ColorScheme` migration and reusable surface, button, badge, form,
  date-picker, appointment-tile, and unsaved-changes components.
- A shared Coming Soon route for development-time feedback from unfinished
  destinations. It is tracked debt and is not feature completion.
- Firestore-authoritative company membership and Owner/Officer roles, with
  security rules that prevent self-promotion and cross-institution Officer
  provisioning. Hive remains the local session/operational cache.
- Solo/team Business Setup now gates unlinked registration, login, and cold
  start. Solo setup auto-provisions the existing institution model, confirms
  the editable default name, and makes Google Calendar explicitly optional;
  linked solo owners use the same Customers, Services, Service Locations, and
  Staff Management capabilities as team owners.
- Account deletion now distinguishes a known always-solo business from legacy
  or ever-staffed businesses. Officer creation permanently flips the history
  marker in Firestore and Hive; the callable rechecks marker plus membership.
- Spec 08a moves solo/team provisioning behind `InstitutionRepository` and a
  persisted idempotency key. One server transaction creates the Business,
  links the owner, and writes its receipt; a daily reconciler handles stale
  atomic records. Officer create/remove are trusted server operations, and
  removal changes local Hive state only after the remote unlink succeeds.
- One Business per Firebase identity is the explicit v1 constraint. A future
  multi-Business feature requires a first-class membership-model migration.
- 11 feature modules and 47 Dart test files are currently present.

## Locked Scope

- Voice-assisted booking is post-MVP. `ReleaseScope.voiceBookingEnabled` is
  `false`; the microphone entry point remains hidden and no speech dependency
  should be restored during unrelated MVP work.
- Null-tenant legacy rows are excluded from tenant analytics rather than being
  silently attributed to a business.
- All new or modified UI must use semantic theme colors as specified in the
  parent `AGENTS.md`.
- Automatic call recording and system call-log ingestion remain dormant behind
  the Android `booklyDormantCallIntegration` build property, which defaults to
  false. Their dangerous permissions exist only in the debug manifest and are
  absent from the merged public release manifest.
- The first iOS release uses email/password authentication only. Google Sign-In
  and Google Calendar controls are hidden there; Android OAuth behavior is
  unchanged.
- The Google-auth restriction is enforced below the UI as well: accidental or
  programmatic Google sign-in calls are rejected on iOS. Android remains
  enabled.

## Release Blockers and Open Validation

1. Authentication/profile recovery is still a documented target design, not a
   completed flow. Implement and test idempotent `ensureProfile`, bounded
   provisioning states, and the actionable recovery screen described in
   `../../../AUTH_REGISTRATION_RECOVERY_FLOW.md`.
2. Platform compliance remains open: the Spec 04 v3 privacy/Terms and store-form
   drafts exist, and broad contacts authorization has been removed, but owner
   legal identity/address, Sri Lanka PDPA and worldwide legal review, live
   hosted pages, final-binary store mappings, and console verification remain
   outstanding. Publication is intentionally deferred during the current
   code/app-compliance stage; it is still mandatory before production. The
   public Android call-log/recording permission gate is complete.
3. Firestore offline-to-online synchronization and conflict behavior are not
   verified end to end. Google Calendar error and token edge cases also need
   stress testing.
4. The credential-independent iOS baseline and hosted release workflow are
   implemented: iOS 13 deployment, CocoaPods wiring, removal of unnecessary
   contacts plus dormant microphone/phone and placeholder OAuth declarations,
   iOS Google OAuth UI gates, Firebase secret injection, and a
   Codemagic pod/sign/build/TestFlight pipeline. Release remains blocked on
   confirming provisional bundle ID `com.ashDilussi.bookly`, completing Apple
   enrollment/API credentials, supplying the real `GoogleService-Info.plist`
   for `bookly-1f5f7`, running the hosted build, and validating its TestFlight
   install on a physical iPhone. System call detection is not part of the
   public-v1 Calls design.
5. Call/staff KPI sections remain release-gated: app-initiated events do not
   establish call outcomes, duration, missed calls, or conversion by themselves.
6. Release-mode source now removes all Coming Soon routes/triggers, unfinished
   billing, unpublished legal links, and sample-data tooling; Contact Support
   opens a real email handoff. This still requires a signed-build walkthrough,
   and real Terms/Privacy links must be restored after publication.
7. A clean full `flutter analyze`, complete `flutter test`, release build, and
   end-to-end device pass are still required against the consolidated working
   tree.
8. Store-compliant account deletion is implemented in source but is not yet
   deployed or validated end to end. Deploy Functions/Hosting, enable and
   authorize Firebase email-link authentication, then verify officer deletion,
   sole-owner blocking, institution deletion across two devices, OAuth grant
   revocation, and the public email-link flow against `bookly-1f5f7`.
9. Spec 08/08a solo onboarding, atomic retry, recovery UX, and Officer
   lifecycle pass focused local source checks, but the Firestore Rules/Functions
   changes are not deployed. Validate a new solo account, a deliberately lost
   provisioning response, first-Officer growth, Officer removal on a second
   device, and both deletion paths with real accounts/devices before release.

## Verification Snapshot

- On September 26, 2026, focused Spec 08a analysis reported no Dart issues;
  nine provisioning/onboarding/team-form Flutter tests passed. Functions
  TypeScript compilation and four unit tests passed. Two Firebase emulator
  journeys passed against Auth, Firestore Rules, and callable Functions,
  covering atomic detailed/solo provisioning, same-key lost-response retry,
  forged-write denial, Officer lifecycle/history, removed-user access denial,
  and both relevant deletion paths. The scheduled reconciler was discovered
  but not executed because this suite did not run Pub/Sub. A full Flutter run again
  reproduced 15 pre-existing booking/customer widget-fixture failures while
  the Spec 08a tests passed; its Call History tail again stopped producing
  output after 254 passes and was interrupted. These failures are outside the
  auth/settings/functions/rules files changed by Spec 08a and remain separately
  open; they are not represented as a green full-suite result.
  Full `flutter analyze --no-pub` completed with no errors or warnings and 13
  existing info-level lints confined to the two development scripts.
  Functions dependencies were advanced to `firebase-admin` 14.5 and
  `firebase-functions` 7.4; build/unit/emulator checks remained green and
  `npm audit --omit=dev` reports zero vulnerabilities.

- On September 25, 2026, the focused Spec 08 Flutter suite passed 15 tests
  covering Hive compatibility, Business Setup routing/copy, Home fallback,
  deletion presentation, and existing Home behavior. The Functions TypeScript
  build and three unit tests also passed. This is local evidence only.
- A broader September 25 `flutter test` run reached 250 passes and reported 16
  failures before it stopped producing output and was interrupted. One startup
  route-name incompatibility introduced during Spec 08 was fixed immediately;
  the complete three-test startup-navigation file then passed. The other 15
  observed failures are in the already-open booking/customer test cluster and
  remain outside Spec 08; a clean completed full suite is still required.

- Historical focused verification recorded in `Concern_Tracking.md` includes a
  93-test auth/startup/entitlement/Hive/service-color suite and Pixel Tablet
  checks for startup, login-warning dismissal, and Service Detail persistence.
  Those results cover their dated fixes, not the entire current working tree.
- On September 20, 2026, full `flutter analyze --no-pub` completed with no
  errors or warnings and 14 pre-existing info-level lints. A focused 26-test
  auth/session/Home suite passed, including unassigned-role preservation,
  persistent company setup CTA, optional password prompt, and auth form checks.
  A complete-suite attempt progressed to 215 passes and 16 failures before
  hanging in the legacy call-history tests and being stopped. The failures are
  concentrated in pre-existing booking/customer widget mocks and one Calendar
  navigation fixture. The Home/Firebase construction regression exposed by
  that attempt was fixed and its navigation test now passes; a complete rerun
  remains outstanding. The onboarding-focused suite remains green. Firebase
  Rules emulator tests remain outstanding.
- On September 23, 2026, the call-compliance implementation passed targeted
  static analysis, 53 core/unit tests, an isolated Call History widget
  regression, Android debug Kotlin compilation with the dormant integration
  enabled, and release-manifest merging. The merged release manifest contains
  neither `READ_CALL_LOG`, `RECORD_AUDIO`, nor `CALL_PHONE`. The broader legacy
  Call History widget file still contains pre-existing fake-async Hive writes
  that can stall when run as one suite.
- On September 23, 2026, the credential-independent iOS baseline passed
  targeted static analysis and 10 focused iOS/auth tests. `Info.plist` has no
  contacts, microphone, phone, or OAuth URL-scheme declaration because contact
  import now uses the OS-owned picker; the project and Podfile target iOS 13;
  and Google Sign-In plus
  Calendar controls are release-gated off on iOS while remaining enabled on
  Android. Native CocoaPods/archive/device validation could not run on this
  Windows host; the hosted workflow described below supersedes that local-only
  limitation once owner credentials are supplied.
- On September 23, 2026, Spec 02 v3 added a hosted Codemagic macOS workflow
  that restores and validates the ignored Firebase plist, extracts matching
  compile-time Firebase options, installs CocoaPods, creates/fetches App Store
  signing assets, builds a signed IPA, and uploads it to TestFlight. YAML
  parsing, targeted static analysis, and 12 focused iOS/auth tests pass locally.
  The workflow itself has not run because the Firebase and Apple credential
  groups do not yet exist; therefore no signed IPA or TestFlight device result
  is claimed.
- On September 23, 2026, Spec 03 Part A discovery found Login as the only live
  Google authentication surface and no Firestore logic branching on provider
  type. A data-layer platform guard was added so Google auth cannot be invoked
  on iOS even outside the hidden UI. Targeted analysis is clean and 7 focused
  auth platform/form tests pass. Part B now has a deployable Admin callable,
  role-aware in-app confirmation, a verified-email Hosting request page, a
  live-subscription hard stop, and next-auth-check Hive purging. Targeted Dart
  analysis, six Flutter tests, TypeScript compilation, and two server guard
  tests pass. Deployment and real-project/multi-device acceptance remain open.
- On September 24, 2026, the Spec 04 v3 technical clarification was recorded in
  `docs/compliance/spec-04-privacy-and-store-mapping.md`. It inventories local
  versus remote data, drafts GDPR-baseline policy/Terms content, and maps Play
  and Apple disclosures. Contact import now retains the native one-contact
  picker while removing Android `READ_CONTACTS`, iOS contacts usage copy, and
  the runtime permission request. The app-wide regression now scans every Dart
  source and Android source manifest for broad contacts access and guards the
  dependency list against common ads, analytics, performance, attribution, and
  remote-crash SDKs. Official Gazette No. 2498/16 was verified as appointing
  January 1, 2027 for Sections 2-3, Part I, and Part III; it does not expressly
  list Part II, and the detailed DPO, breach, DPIA, and rights instruments on
  the DPA site are still marked as drafts. Publication remains blocked on the
  owner's public legal name/address, appropriate legal review (including Part
  II timing, DPO, DPIA, breach, data-subject requests, and cross-border flows),
  Google data-processing-terms verification, live pages, final store-console
  entry, and physical-device picker validation. Focused verification for the
  strengthened v3 baseline passed with no analyzer issues and all eight focused
  Spec 04/iOS release tests passing.
- On September 24, 2026, Spec 05 explicitly set Android target API 36, upgraded
  to API-36-compatible AGP 8.10.1, replaced debug release signing with a
  fail-closed production configuration, and gated every placeholder, unfinished
  billing route, and destructive developer tool out of release mode. Contact
  Support now opens the documented support email and misleading automatic
  missed-call copy was corrected. Focused analysis passed, all 14 cross-spec
  compliance tests passed, and a debug AAB built successfully with arm64-v8a,
  armeabi-v7a, and x86_64 libraries. A release task was also verified to stop
  with an actionable error when production signing is absent. Production key
  ownership, signing, internal-track installation, 16 KB/Play checks, store
  forms/assets, reviewer accounts, and every Spec 02 owner-only item remain open.
  An ephemeral-key release validation reached release AOT/dependency work but
  could not complete because Google Maven repeatedly terminated required TLS
  downloads; the retry was bounded and all temporary keys/artifacts were
  removed. No production or validation release AAB is retained or claimed.

## Immediate Agent Priorities

1. Preserve and consolidate the existing integration work; do not discard the
   dirty working tree or edit unrelated user changes.
2. Restore a reliable analyzer/test run, then capture exact passing/failing
   results here.
3. Complete the auth profile-recovery implementation because it is an explicit
   correctness gap in every authenticated entry path.
4. Continue the external release-compliance gates using
   `docs/agents/store-compliance-watchlist.md`, then validate the release-only
   navigation gates in the final signed builds.
5. Validate app-initiated dialer handoff on real Android and iOS hardware,
   followed by cloud-sync and release-build validation.

## Source-of-Truth Map

- Engineering rules and locked decisions: `../../../AGENTS.md`
- Full architecture and implementation context: `../../../CLAUDE.md`
- Release priorities: `../../../ROADMAP.md`
- Product scope: `../../../product_requirements_document.md`
- Defects and reusable fixes: `../../../Concern_Tracking.md`
- Auth recovery target: `../../../AUTH_REGISTRATION_RECOVERY_FLOW.md`
- Screen-by-screen behavior: `../../../CURRENT_SCREEN_MANIFEST.md`
- App-local commands and key files: `../../CLAUDE.md`
- Persistent Specs 01–05 gates and reminder triggers:
  `store-compliance-watchlist.md`
- Spec 04 technical draft and store mappings:
  `../compliance/spec-04-privacy-and-store-mapping.md`
- Spec 05 implementation evidence and release runbook:
  `../compliance/spec-05-store-release-engineering.md`
