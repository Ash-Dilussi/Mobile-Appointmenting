# Bookly — Play Store / App Store Compliance Gap Analysis

**Scope of this report:** Bookly, public consumer distribution, both Google Play and Apple App
Store. Per your decisions: iOS ships **without** call recording for now; Android keeps it.

**Method note (read this first):** Only 5 files were available for direct review —
`MainActivity.kt`, `auth_repository.dart`, `register_screen.dart`, `app_init_provider.dart`, and
the project's own conventions skill. Following this project's own discovery-first rule (§1 of the
Bookly skill), everything below is labeled **Confirmed** (read directly from those files) or
**Unknown — needs discovery** (inferred risk, not yet verified against the actual repo). Do not let
a fix-spec agent treat an "Unknown" item as settled — §"Discovery Required Before Fix Specs" at the
end lists exactly what to open next.

---

## 1. Blocker-severity findings

These will get the app rejected, suspended, or expose you to legal risk. Nothing else matters until
these have a decided direction.

### 1.1 Automatic call recording with zero consent/disclosure UX
**Status: Confirmed, from `MainActivity.kt`.**

`registerCallReceiver()` auto-calls `startRecording()` the instant `TelephonyManager` reports
`EXTRA_STATE_OFFHOOK` — i.e. the moment either party answers. There is no user-facing consent
screen, no audible tone, no on-screen "this call is being recorded" indicator, and no code path
that could inform the *other* party on the line at all.

Why this is a blocker, independent of any store rule:
- Roughly half of US states (and many other countries) are **all-party consent** jurisdictions for
  call recording. An app that records by default, silently, the moment a call connects is a
  wiretapping-law problem for whoever operates it, not just a store-policy problem for you.
- Google Play's policy on background audio/call recording requires **prominent, in-context
  disclosure and affirmative consent** before recording starts, not a line buried in a privacy
  policy. Auto-start-on-OFFHOOK does not meet this even if permissions are otherwise fine.
- Apple has no equivalent capability at all (already decided: not shipping on iOS).

This needs a **product decision**, not a code patch: does Bookly (a) drop automatic recording and
require the receptionist to tap "record" with a visible on-screen recording indicator for the
duration of the call, (b) play an audible announcement to both parties before recording begins, or
(c) restrict the feature to jurisdictions/customers where the business itself is the one legally
responsible for consent (common for call-center software, but requires an explicit
"you are the responsible party for obtaining consent" agreement in-app, not silence). This decision
should happen before any fix spec is written, since it changes the shape of the Kotlin code.

### 1.2 Recording permission request is a non-functional stub
**Status: Confirmed, from `MainActivity.kt`.**

```kotlin
private fun requestRecordingPermission(): Boolean {
    // In real implementation, would request permission via Activity
    // For now, assume permission is granted via permission_handler package
    return true
}
```

This always returns `true` without ever invoking Android's runtime permission dialog for
`RECORD_AUDIO`. Combined with `hasRecordingPermission()` checking `checkSelfPermission` elsewhere,
this means the method channel can report "permission granted" to Flutter when it may not
actually be. This is both a functional bug (recording will throw at the `MediaRecorder.prepare()`
call on a real device without the permission already granted some other way) and a compliance
issue — Play policy requires a genuine runtime request with rationale before a dangerous permission
is used, not an assumed grant.

### 1.3 No foreground service for background audio capture
**Status: Confirmed, from `MainActivity.kt`.**

`startRecording()` is invoked from a `BroadcastReceiver` callback and runs `MediaRecorder` directly
in the Activity's process, with no foreground service, no persistent notification, and no
`FOREGROUND_SERVICE_MICROPHONE` service type. On Android 10+ this is likely to be killed by
background execution limits the moment the call screen backgrounds Bookly (which it will — the
system Phone app takes foreground during a call). On Android 14+, a microphone-using foreground
service **must** declare `android:foregroundServiceType="microphone"` and show a notification for
as long as it records; omitting this is both a runtime reliability bug and a Play Console policy
violation (undisclosed background microphone use).

### 1.4 Mic-only capture likely can't record the other party at all
**Status: Confirmed pattern (`AudioSource.MIC`), consequence needs device testing.**

`setAudioSource(MediaRecorder.AudioSource.MIC)` captures the phone's microphone only. Since
Android 9/10, the OS deliberately blocks third-party apps from tapping the actual call audio path
(`VOICE_CALL`/`VOICE_DOWNLINK` sources are system-only) specifically to stop this pattern. In
practice this means Bookly may currently record the receptionist's side clearly and the caller
faintly/not at all, or throw a `SecurityException` outright on many OEM builds while a call is
active. This isn't a store-policy item — it's whether the core feature works as designed on the
devices customers will actually use. Needs verification on real hardware before writing more spec
around "call recording" as if it reliably captures both sides.

### 1.5 iOS: confirm no dead call-recording code ships in the iOS build
**Status: Decided (no iOS recording), needs a verification step.**

Since `MainActivity.kt` is Android-only Kotlin, there's no iOS equivalent to strip — good. The
discovery step here is narrower: confirm the Dart-side recording feature (whatever calls the
`RECORD_CHANNEL`/`RECORD_EVENT_CHANNEL` method channels from Flutter) is conditionally hidden on
iOS rather than present-but-broken, since Apple app review will reject a UI that visibly offers a
non-functional feature just as readily as one that crashes.

---

## 2. High-severity findings

### 2.1 Google Sign-In without Sign in with Apple
**Status: Confirmed interface (`auth_repository.dart` declares `signInWithGoogle()`); UI usage not
yet confirmed (login screen wasn't in the reviewed set).**

App Store Review Guideline 4.8 requires that if an app offers any third-party/social login (Google
included), it must also offer **Sign in with Apple** as an equivalent option, with narrow
exceptions (e.g. education/enterprise apps using their own account system exclusively). Since
you've confirmed Bookly is a public consumer app, the exception almost certainly doesn't apply. If
`signInWithGoogle()` is actually wired to a button in the login screen (not yet confirmed), this is
an automatic App Store rejection until Sign in with Apple is added.

### 2.2 No confirmed in-app account deletion
**Status: Unknown — needs discovery.** Not visible in any of the 5 reviewed files.

Both stores require self-service account deletion reachable from inside the app (Play's
"Account/Data deletion" requirement, and Apple Guideline 5.1.1(v)) whenever the app supports account
creation — which it clearly does (`registerWithEmail`). If this screen doesn't exist yet, it's a
required build item, not just a settings toggle to surface.

### 2.3 No confirmed privacy policy content covering audio recordings
**Status: Unknown — needs discovery.**

Call recordings are about as sensitive as user data gets (potentially containing health info if
customers are clinics, per the skill's own description of Bookly's users). Both stores' Data
Safety / Privacy Nutrition Label forms require disclosing: what's collected (audio, phone numbers,
customer names), why, whether it's shared with third parties (Firebase, Google Calendar API per the
skill's dependency list), how long it's retained, and whether users can delete it. None of this can
be assessed without seeing the actual privacy policy (if one exists) and the retention/deletion
logic in `HiveService` and the native `recordings/` directory.

### 2.4 Google Calendar OAuth scope verification
**Status: Unknown — needs discovery.**

The skill file confirms `google_sign_in` + `googleapis` are dependencies for Calendar integration.
If the OAuth scopes requested are "sensitive" or "restricted" (most Calendar write scopes are),
Google requires a **CASA security assessment** and an OAuth consent screen verification process
that can take weeks — this is a scheduling risk for a submission date, not a code risk, and is
easy to miss until Play Console rejects the OAuth client at review time.

### 2.5 Institution-scoping inconsistency as a privacy/data-isolation issue
**Status: Confirmed, from the skill file (§4 known traps) — flagged here because it's now also a
compliance angle, not just a code-quality one.**

`getAllCustomers`/`getCustomerByPhone` not scoping by `institutionId` while `getCustomersForInstitution`
does means that in a multi-tenant deployment, one business's customer data could be visible to
another's session if any live screen calls the unscoped methods. If Bookly is multi-tenant (multiple
businesses' data in the same Hive boxes on a shared backend, or synced), this is a data-isolation
bug with real privacy-disclosure consequences, not just a matching bug. Needs discovery: is
Bookly's Firebase/Firestore backend multi-tenant, and which screens call the unscoped methods.

---

## 3. Medium-severity findings

- **`insertCallLog` never sets `customerId`** (confirmed, skill file). Not a store blocker, but if
  any privacy-disclosure or data-export feature is built later ("export my data"), a broken
  customer↔call linkage will produce incomplete/incorrect exports — relevant to GDPR/CCPA-style
  data-access requests if you ever operate in those markets.
- **`getCustomerByPhone` exact-string match** (confirmed, skill file). Functional bug; also matters
  if phone-number matching is ever used to gate access to recordings by customer identity.
- **Two parallel call-log systems** (`CallLog` typeId 3 vs `CallLogEntry` typeId 10, confirmed,
  skill file). Not a store issue by itself, but any fix spec for recording-consent or retention
  logic must target the *live* one (`CallLog`, wired to `/call-history`) — writing compliant
  retention/deletion logic against the dead `CallLogEntry` path would ship a fix that does nothing.

---

## 4. Unknowns that block writing an accurate fix spec

Every item below is a genuine "don't know yet," not a soft-pedaled blocker. Per the skill's own
discovery-first convention, these need to be opened and read — not assumed — before the next round
of fix specs is written:

1. **`AndroidManifest.xml`** — full permission list, `foregroundServiceType` declarations, target
   SDK version (Play requires targeting a recent API level; older targets get suspended
   automatically), and whether `READ_CALL_LOG`/`PROCESS_OUTGOING_CALLS` are declared anywhere
   (if so, the default-dialer restriction from §1.1 applies in full force, not just the consent
   angle).
2. **`ios/Runner/Info.plist`** — confirm no leftover `NSMicrophoneUsageDescription` implies a
   recording feature that doesn't exist on iOS, and check what usage strings *are* present
   (contacts, calendar, etc.) against what the app actually does.
3. **`pubspec.yaml`** — full dependency list including any analytics/crash/ad SDKs not mentioned in
   the skill file; these drive both stores' data-collection disclosures and iOS App Tracking
   Transparency requirements if any cross-app tracking is involved.
4. **Login screen** (not `register_screen.dart` — the sign-*in* screen) — confirms whether
   `signInWithGoogle()` is actually surfaced to users (§2.1).
5. **Settings/account/profile screens** — confirms whether account deletion exists (§2.2).
6. **`hive_service.dart`** — confirms recording retention/deletion behavior, and whether recordings
   or customer data sync to a remote backend (Firestore) or stay device-local, which changes the
   Data Safety disclosure significantly either way.
7. **Actual privacy policy document/URL**, if one exists.
8. **`app_router.dart`** — confirms which screens are live/reachable, per the skill's "check what's
   wired to a route" rule, before any fix spec references a screen as an integration point.
9. **Whichever Dart file calls the `RECORD_CHANNEL`/`RECORD_EVENT_CHANNEL`/`CHANNEL`/`EVENT_CHANNEL`
   method channels from `MainActivity.kt`** — this is where the consent-UX decision from §1.1
   actually gets implemented, and it wasn't in the reviewed set.

---

## 5. Recommended next fix-spec documents

Once the discovery items above are confirmed and the product decision in §1.1 is made, I'd break
the remediation into separate, independently-executable specs rather than one giant document —
matching the skill's own guidance that specs should be scoped and explicit about what's confirmed
vs. what the executing agent still needs to check:

1. **`01-call-recording-consent-and-reliability.md`** — redesigns the recording trigger/consent UX
   per the §1.1 decision, adds a real runtime permission request (§1.2), adds the foreground
   service + notification (§1.3), and specifies the device-testing needed to confirm §1.4 before
   claiming the feature works.
2. **`02-android-manifest-and-permission-hardening.md`** — once Manifest is read, an exact diff of
   permissions to add/remove/justify, plus the Play Console "Restricted Permissions" declaration
   text.
3. **`03-auth-parity-and-account-deletion.md`** — Sign in with Apple (§2.1) and self-service account
   deletion (§2.2), scoped to whichever architecture the `auth` feature already uses (per the
   skill's §3 note that `auth` uses clean architecture — don't bolt on a different pattern).
4. **`04-privacy-policy-and-data-safety-mapping.md`** — a literal field-by-field mapping from what
   the app actually collects/stores/shares (once §4.6–4.7 are confirmed) to Play's Data Safety form
   and Apple's Privacy Nutrition Label, plus the privacy-policy copy itself.
5. **`05-multi-tenant-data-isolation-fix.md`** — only if discovery confirms Bookly is multi-tenant;
   fixes the institution-scoping gap in §2.5.
6. **`06-store-listing-technical-checklist.md`** — the non-code items: target API level, 64-bit
   compliance, screenshots/content rating questionnaire, export-compliance (encryption) declaration,
   OAuth consent screen verification timeline (§2.4).

I'd suggest starting with #1, since it's the one finding that changes actual product behavior (not
just disclosures), and every other spec's accuracy depends on it being settled first.
