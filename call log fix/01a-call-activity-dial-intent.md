# Spec 01a — Call Activity via Dial Intent (replaces system call-log dependency)

**Goal:** Keep the Calls tab live and populated in v1, without `READ_CALL_LOG`, by having Bookly
log its own "call initiated" events when a user taps to call a customer from within the app.

**Depends on:** Spec 01 (manifest/native gating). Implement as part of the same release, not a
later fast-follow — the Calls tab should never ship in a permanently-hidden or permanently-empty
state.

**Resolves:** the "hide the Calls tab" item in Spec 01's original plan, and Spec 01's second open
question about a v1 fallback for call history.

---

## 1. Confirmed facts

- Google Play's own policy page for SMS/Call Log permissions names the **Dial Intent** as the
  sanctioned alternative for apps that only need to initiate a call, and states explicitly that it
  **does not require the `CALL_PHONE` permission**
  (support.google.com/googleplay/android-developer/answer/10208820, "Alternatives to common uses"
  table). The same page lists "Call recorder" as a use case that is never permitted, confirming
  that no consent-UX design fixes that specific feature — only removing it does (per Spec 01).
- `url_launcher` is already a project dependency (confirmed via the project's conventions skill's
  dependency list) — no new package is needed to open the dialer.
- The live, canonical call-history model is `CallLog` (Hive typeId 3), rendered at `/call-history`.
  Per the project's own known-trap warning, there is already a second, dormant call-log system
  (`CallLogEntry`, typeId 10) — **this spec must not create a third one.**
- The project's Hive convention is append-only `@HiveField(N)` numbering — never renumber or reuse
  an existing field index.
- A known historical bug (`insertCallLog` never sets `customerId`) affected the old
  system-log-derived insert path. This new insert path is triggered directly from a customer's
  screen, so `customerId` is already known at the call site — there's no excuse to repeat that bug
  here; treat setting it correctly as a hard requirement, not an incidental nice-to-have.
- Per your decision: **no outcome-capture prompt in v1.** Entries are logged as "Call initiated"
  only — no "Connected / No answer / Busy / Cancelled" follow-up UI this release.

## 2. Decision

- Add a "Call" action (at minimum on the customer profile screen; extend to appointment detail if
  a phone number is shown there too — confirm scope in discovery step 3) that:
  1. Writes a new `CallLog` entry immediately (customerId, phone number, timestamp, initiating
     staff/user, and a new field marking it as app-initiated — see §4) — **before** opening the
     dialer, so the record exists even if the user backgrounds or kills the app right after.
  2. Opens the system dialer pre-filled with the number via a `tel:` URI, using `url_launcher`. The
     user explicitly presses Call themselves — Bookly never dials directly and never requests
     `CALL_PHONE`.
- The Calls screen keeps rendering from `CallLog` exactly as it does today — no new data source,
  no new provider architecture. Existing historical rows (including any created by the
  now-disabled system-log path before this release) are left as-is and still shown; nothing is
  backfilled or relabeled retroactively.
- Add a short, honest disclosure in the Calls screen (e.g. a persistent banner or subtitle): calls
  made through Bookly are shown here; calls made or received outside the app are not.

## 3. Discovery steps for the executing agent

1. Confirm the current highest `@HiveField(N)` index in the `CallLog` model before adding any new
   field — do not assume a number, read it.
2. Confirm whether a manual call-logging UI already exists anywhere in the app (Spec 01's discovery
   flagged this as unconfirmed). If it exists, this new app-initiated flow should reuse the same
   underlying `HiveService` insert method where possible, distinguished by the new source field —
   not a second parallel insert path.
3. Enumerate every screen where a customer/contact phone number is shown and a "Call" action would
   make sense (customer profile at minimum; check appointment detail, any call-history row itself,
   and search results) — confirm the full scope with the person before limiting this to just one
   screen.
4. Confirm how the currently-logged-in staff/user identity is normally captured elsewhere in the
   app (existing session/provider pattern) so the new `CallLog` entry's staff attribution uses that
   established pattern rather than a new one.
5. Confirm `call_history_screen.dart`'s current rendering logic handles a `CallLog` row with no
   duration/outcome value gracefully (it will need to, since these new rows won't have one) — check
   before assuming it needs a UI change versus already tolerating nulls.

## 4. Functional requirements

1. **Model change:** add an append-only field to `CallLog` marking an entry's origin (e.g. an enum
   or bool distinguishing app-initiated vs. legacy/manual) — exact naming left to the executing
   agent, but it must not renumber any existing `@HiveField` index.
2. **Insert logic:** new/extended `HiveService` method that writes a `CallLog` entry with
   `customerId` always populated from the call site (never optional, never inferred later).
3. **Dial action:** use `url_launcher`'s `launchUrl` with a `tel:` URI
   (`Uri(scheme: 'tel', path: phoneNumber)`), `LaunchMode.externalApplication`. Do not gate this
   behind `canLaunchUrl` alone on iOS — iOS's `canLaunchUrl` for the `tel` scheme returns false
   unless `tel` is whitelisted in `LSApplicationQueriesSchemes` in `Info.plist`; either add that
   whitelist entry or attempt the launch directly with a try/catch fallback that shows a clear
   error if it genuinely fails (e.g. on a device with no telephony capability).
4. **UI copy:** add the disclosure line described in §2 to the Calls screen. Update any store-facing
   copy that previously described "call history" as automatic detection (coordinate with Spec 04's
   store-copy note) to describe calls made through the app instead.
5. **No new permissions:** confirm this feature adds zero entries to `AndroidManifest.xml` and no
   new `Info.plist` usage-description key (the `tel:` scheme whitelist entry in
   `LSApplicationQueriesSchemes`, if used, is not a usage-description permission and needs no
   user-facing justification).

## 5. Explicitly out of scope

- The "How did it go?" outcome-capture prompt — not in v1 per your decision. Worth flagging as a
  natural fast-follow once there's user feedback on whether it's wanted, but don't build it now.
- Retroactively relabeling or backfilling historical `CallLog` rows created before this release.
- Missed-call detection or any other data that genuinely requires the system call log — that stays
  gated per Spec 01 until/unless the default-handler question in Spec 01's open questions is
  resolved.
- Migrating or touching `CallLogEntry` (typeId 10) — separate legacy-cleanup spec.

## 6. File-by-file task list

- [ ] `CallLog` Hive model — add the new append-only field
- [ ] `HiveService` (or wherever `CallLog` inserts live) — new/extended insert method requiring
      `customerId`
- [ ] Customer profile screen (and any other screens confirmed in discovery step 3) — add the Call
      action, wired to insert-then-launch
- [ ] `call_history_screen.dart` — add the disclosure copy; confirm/adjust null-duration handling
- [ ] `ios/Runner/Info.plist` — add `tel` to `LSApplicationQueriesSchemes` if `canLaunchUrl` gating
      is used

## 7. Testing requirements

- Tap Call from the customer screen: confirm a `CallLog` entry is created immediately with the
  correct `customerId`, phone number, timestamp, and staff attribution, before the dialer even
  opens.
- Confirm the system dialer opens pre-filled and **does not auto-dial** — the user must press Call
  themselves.
- Cancel out of the dialer without calling: confirm the "Call initiated" entry still exists (this
  is expected behavior, not a bug, given no outcome capture in v1).
- Confirm this flow triggers zero new permission prompts on both Android and iOS.
- Confirm the Calls screen renders both new app-initiated rows and any pre-existing historical rows
  without crashing on missing fields.
- Test on a real iOS device specifically for the `tel:` launch — simulator behavior for phone
  intents is unreliable and not sufficient verification by itself.

## 8. Acceptance criteria

- [ ] Calls tab remains visible and populated in the public v1 build.
- [ ] No `CALL_PHONE`, `READ_CALL_LOG`, or any new permission is requested by this feature.
- [ ] Every new `CallLog` entry created via this flow has `customerId` populated.
- [ ] Calls screen discloses that it shows Bookly-initiated calls only.
- [ ] Works on both Android and iOS via a single shared code path (`url_launcher`), not
      platform-specific dialing logic.

## 9. Open questions

- Which screens beyond the customer profile should get the Call action for v1 (appointment detail,
  search results, elsewhere)? Discovery step 3 should surface the full list — confirm scope before
  the agent limits this to a single screen by default.
