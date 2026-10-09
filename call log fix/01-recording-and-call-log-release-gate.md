# Spec 01 — Recording & Call-Log Release Gate (v1 public build)

**Goal:** Ship the first public Play/App Store build with automatic call recording and system
call-log ingestion fully disabled, without deleting the underlying Android code, and without
leaving any broken UI behind.

**Depends on:** nothing. This is the first thing to implement — every later spec assumes this one
is done.

**Amendment:** the original plan for the Calls tab/screen (§4 point 5 below, originally "hide or
show a disabled state") is superseded by **Spec 01a — Call Activity via Dial Intent**. The Calls
tab stays visible in v1; it's repowered by app-initiated call activity instead of the system call
log. Everything else in this spec (manifest, native recording gate, permission requests) is
unchanged. Implement Spec 01a as part of this same release gate, not as a later fast-follow.

---

## 1. Confirmed facts (do not re-derive — read from prior review)

- `MainActivity.kt` starts recording automatically on `EXTRA_STATE_OFFHOOK` via a phone-state
  `BroadcastReceiver`, with no consent UX.
- `AndroidManifest.xml` declares `READ_PHONE_STATE`, `READ_CALL_LOG`, `RECORD_AUDIO`,
  `READ_CONTACTS`, legacy storage permissions, `INTERNET`. No foreground service is declared.
- Native code reads the system call-log content provider after each completed call to populate
  number/direction/timestamp/duration.
- `CallRecordingService` (Dart) exists and calls `Permission.microphone.request()`, but has no live
  caller from any screen.
- The canonical, live call-history feature is `CallLog` (typeId 3), rendered at `/call-history` in
  the bottom nav. `CallLogEntry` (typeId 10) is a separate legacy system — out of scope here, see
  Spec 08.
- `MediaRecorder.AudioSource.VOICE_COMMUNICATION` is currently used (not `MIC`), but this is still
  not an authorized carrier-call downlink source — reliability of capturing both call parties is
  unverified on real hardware.

## 2. Decision (already made — implement, don't re-debate)

For the v1 public release:
- Automatic recording is **disabled**, not deleted. The receiver, `MediaRecorder` logic, and method
  channels stay in the codebase, gated behind a compile-time or remote flag that defaults to off.
- `READ_CALL_LOG` and any code path that reads the system call-log provider is **removed from the
  public build**. Completed-call ingestion via the system call log does not ship in v1.
- `RECORD_AUDIO` is **not requested** anywhere in v1 if no feature uses it. Do not request a
  dangerous permission for a disabled feature — this is itself a Play policy problem (unnecessary
  permission requests get flagged in review).
- Any UI that currently displays call-log-derived data (missed-call counts, call-history entries
  sourced from the system log, "Insights" built on call analytics) must **not silently show empty
  or zero** — it must be visibly disabled/hidden, or replaced with a "coming soon" state that is
  honest about the feature being unavailable, not broken.

## 3. Discovery steps for the executing agent (confirm before editing)

1. Find every call site that reads from `READ_CALL_LOG` / the system call-log provider (native
   Kotlin and any Dart code consuming its output via method channel) and list them before touching
   anything.
2. Find every screen/widget that displays data derived from that ingestion path (call-history rows,
   missed-call badges, any "Insights" or analytics screen) — confirm which are reachable from the
   bottom nav / `app_router.dart` today.
3. Confirm whether any *manually entered* call-log data (not system-log-derived) exists in the
   `CallLog` collection — if customers/staff can log calls manually today, that path is unaffected
   by this spec and must keep working.
4. Confirm the exact current value of the recording feature flag/config mechanism used elsewhere in
   the app (if any config/remote-flag system already exists, reuse it rather than inventing a new
   one).

## 4. Functional requirements

1. **Manifest:** remove `android.permission.READ_CALL_LOG` from the public build's
   `AndroidManifest.xml`. If a build-flavor system exists or is easy to add (debug/internal vs.
   public release), prefer gating the permission there over a runtime no-op, since Play scans the
   manifest itself, not just runtime behavior.
2. **Native call-log ingestion:** disable the code path that queries the system call-log provider
   in the public build. Do not delete it — comment/flag it clearly as dormant, pending the
   default-Phone-handler decision noted in Open Questions below.
3. **Auto-recording trigger:** disable the `startRecording()` call inside the `OFFHOOK` branch of
   the phone-state receiver for the public build. The receiver itself can remain registered for
   other state events if other features depend on it (confirm in discovery step 1) — only the
   auto-record trigger is gated.
4. **Permission requests:** remove any onboarding/permission-priming screen that requests
   `RECORD_AUDIO` or call-log access if the only consumer of that permission is now-disabled
   recording. Re-add this once Spec 03 (future recording redesign) ships.
5. **UI honesty:** any screen currently showing call-log-derived data must be updated so it never
   silently shows an empty list, crashes, or surfaces a raw permission-denied error to the end
   user. For the main Calls/call-history screen specifically, implement **Spec 01a** — it stays
   visible and populated, repowered by app-initiated activity rather than the system log. Any
   *other* call-log-derived UI not covered by Spec 01a (e.g. missed-call badges elsewhere in the
   app, an "Insights" screen built on call analytics) should fall back to a clearly-labeled
   unavailable/disabled state, since Spec 01a doesn't produce missed-call or analytics data.
6. **Feature flag:** the disabled code should be reachable again by flipping one flag/config value
   for future internal testing, without needing to re-write the manifest or UI gating by hand.

## 5. Explicitly out of scope

- Redesigning recording to be consent-based/user-initiated — that's Spec 03.
- Deciding whether Bookly ever becomes a default Phone/Assistant handler to legitimately regain
  `READ_CALL_LOG` — that's a business decision, not a code task (see Open Questions).
- Touching the legacy `CallLogEntry` system — that's Spec 08.
- Anything about `RECORD_AUDIO`'s eventual re-introduction — that belongs to Spec 03, once consent
  UX exists.

## 6. File-by-file task list

- [ ] `AndroidManifest.xml` — remove `READ_CALL_LOG` from public build variant
- [ ] `MainActivity.kt` — gate the `OFFHOOK` auto-record call and the call-log-provider read behind
      the feature flag from discovery step 4
- [ ] Every screen found in discovery step 2 — replace call-log-derived UI with an honest
      disabled/unavailable state
- [ ] Onboarding/permission-priming screen (if one requests `RECORD_AUDIO` today) — remove that
      request for v1

## 7. Testing requirements

- Fresh install, make and receive a real call: confirm no recording starts, no call-log entry is
  auto-created, no `RECORD_AUDIO` permission prompt appears.
- Confirm the app does not crash or show a raw permission-denied exception anywhere the disabled
  feature used to render.
- Confirm manual call-logging (if it exists per discovery step 3) still works normally.
- Confirm the feature flag can flip the whole path back on in a debug build for future dev work.

## 8. Acceptance criteria

- [ ] `READ_CALL_LOG` does not appear in the public build's manifest.
- [ ] No call is auto-recorded in the public build under any circumstance.
- [ ] No screen shows a broken or silently-empty state where call-log data used to appear.
- [ ] `RECORD_AUDIO` is not requested anywhere in the public build.
- [ ] Feature flag confirmed to fully restore the old behavior in a non-public build.

## 9. Open questions (resolve before/alongside implementation, don't guess)

- Is "disabled but dormant" the permanent plan, or should the app pursue becoming an approved
  default Phone/Assistant/Call-screening handler later to legitimately regain `READ_CALL_LOG`? This
  is a multi-month product/business decision, not something to default into.
- ~~If completed-call history is a core value prop, what's the v1 fallback?~~ **Resolved:** Spec
  01a — app-initiated Call Activity via Dial Intent. Store/marketing copy should describe calls
  "made through Bookly," not automatic call-history detection (see Spec 01a §4 and Spec 04's store
  copy note).
