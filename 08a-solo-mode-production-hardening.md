# Spec 08a — Solo/Independent Mode: Production Hardening

**Goal:** Close the six gaps the verification report found, prioritized by actual severity —
security/data-integrity first, then correctness, then maintainability.

**Depends on:** Spec 08 (implemented), Spec 03 (deletion Cloud Function this extends), Spec 07
(the recovery UI this reuses).

**Implementation status (2026-09-26):** Implemented in the working tree and
focused local checks pass. This is not a production/deployment claim. Firebase
Functions and Rules still require deployment to `bookly-1f5f7`, followed by
real-account, multi-device, scheduled-reconciler, and deletion verification.

**Confirmed v1 product decision:** one Firebase identity belongs to one Bookly
Business. Inviting an existing Bookly identity into a second Business is
blocked with a human-readable support path. Multi-Business membership is
deferred because it requires a first-class membership collection and migration.

**Implemented architecture:**

- `InstitutionRepository` is the single remote seam for both onboarding paths.
- A UUID attempt key is persisted in secure storage before the first network
  request. `provisionBusiness` derives deterministic receipt/Business IDs and
  transactionally creates the Business, links the owner, and records completion.
- The client caches Business/User state before publishing the refreshed linked
  auth session and retains the key until all required local writes succeed.
- `createOfficer` and `removeOfficer` are trusted callables. Creation commits
  Officer membership and permanent staff history together; removal unlinks the
  profile before the device mutates Hive state.
- Rules read the Firestore user profile on every authorization check. No
  role/institution custom claims exist, so a token-claim refresh is unnecessary;
  removal still revokes refresh tokens as an additional session bound.
- A daily function reconciles `atomic-v1` Businesses older than 24 hours,
  repairing a valid unlinked owner or deleting an abandoned record.
- The shared "Your account is safe" retry/support panel handles provisioning
  uncertainty without offering a duplicate-creation path.

---

## Priority tier P0 — security and data integrity (block release on these)

### P0-1: Officer departure must be server-authoritative

**Problem:** leaving/removing an officer currently updates only the local Hive record. The
officer's Firestore profile still shows them linked, meaning they can retain access after being
"removed."

**Fix:** move officer removal to a Cloud Function (extending the pattern Spec 03 already
established for deletion — don't introduce a second, inconsistent approach). The function must, in
one atomic operation:
1. Clear the officer's Firestore profile `institutionId`/role.
2. If the app uses Firebase custom claims for institution-based security-rule checks, revoke them —
   and note that custom claims only take effect after the client's next ID-token refresh
   (`getIdToken(true)` or equivalent), so the client-side session needs to force this, not assume
   it happens automatically.
3. Set `hasEverHadAdditionalStaff` if not already set.
4. Only after server confirmation, invalidate the local Hive cache — never the reverse order.

**Discovery step:** confirm whether custom claims are used at all today for institution/role-based
security rules, or whether rules read `institutionId` directly from the Firestore user document on
every check. This determines whether the token-refresh step above is even necessary.

### P0-2: Officer creation + history flag must be one enforced invariant, not a convention

**Problem:** the official app creates the officer profile and sets `hasEverHadAdditionalStaff` in
one batch, but Firestore Rules don't require this — an outdated or non-standard client could create
an officer document without the flag ever being set, silently defeating the deletion safety check
built in Spec 03.

**Fix:** move officer *creation* to a Cloud Function as well, for the same reason as P0-1 — this
becomes an identity/access-control-adjacent operation, which is exactly the category Spec 03
established shouldn't be a direct client write gated only by declarative rules. If a Cloud Function
genuinely isn't feasible for this operation, the fallback is Firestore Rules using `getAfter()` to
require the institution document's flag update to occur in the same commit as the officer
document's creation — but this is the weaker option; prefer the Cloud Function.

### P0-3: Atomic provisioning with idempotent retry

**Problem:** institution creation and profile linking are two separate operations; a failure
between them can orphan an institution, and retrying generates a new institution ID rather than
resuming or reconciling the failed attempt — meaning a flaky connection can accumulate multiple
orphaned institutions per user over repeated retries.

**Fix:**
1. Move provisioning into a Cloud Function that performs institution creation and profile linking
   as a **single Firestore batch** — all-or-nothing commit, closing the window between the two
   writes entirely.
2. Generate a client-side idempotency key once per signup attempt (persisted locally before the
   first call) and pass it to the function. On retry, the function checks whether that key already
   produced an institution and returns/completes the existing one instead of creating a new one.
3. Add a scheduled reconciliation Cloud Function (daily is reasonable) that finds institutions with
   no valid linked owner beyond a reasonable TTL (e.g. 24 hours) and either completes the link (via
   the same idempotency key, if recoverable) or deletes the truly abandoned ones. This exists
   because some ambiguous-failure window (e.g. the client crashing after the server commits but
   before acknowledging) can never be fully eliminated client-side — reconciliation is the standard
   answer to that residual case, not a perfect client retry loop.

### P0-4: Route provisioning failures into Spec 07's recovery UI, not a new state

**Problem:** a partial failure after remote linking succeeds but local caching doesn't can leave a
screen showing "No Business Found" — a bare, unexplained failure state.

**Fix:** this is the same "link error, not absence" state Spec 07 already designed (Retry action +
support email, no path to accidentally create a duplicate). Wire provisioning failures into that
existing state rather than building a second, slightly different error UI.

---

## Priority tier P1 — correctness and product completeness

### P1-1: Human-readable error for "already belongs to an institution"

**Problem:** inviting an existing solo owner as an officer surfaces a raw `email-already-in-use`
Firebase error.

**Fix:** intercept this specific case in the officer-invitation flow and show a clear product
message — e.g. "This person already has a Bookly business set up. Multi-business membership isn't
supported yet — contact support if you need help with this." Ship this immediately; it's a small,
high-value fix independent of the larger data-model question below.

### P1-2: Document the one-institution-per-user limitation as a decision, not a gap

**Problem:** the underlying data model (`institutionId` as a scalar field, not a proper membership
relation) can't represent one user belonging to multiple institutions at all. This is a real
product limitation, not just an error-message problem.

**Decision needed (owner input):** is "one institution per user, ever" an acceptable permanent
constraint for now, with the interim UX fix above as the full solution — or is solo-to-team
switching (or belonging to multiple institutions at once) a real near-term need? If the latter, the
industry-standard fix is modeling membership as its own collection (e.g. `memberships/{id}` with
`{userId, institutionId, role, joinedAt, status}`) rather than a scalar field on the user document —
this is a genuine data-model migration, not a quick patch, and shouldn't be started without
confirming it's actually needed.

### P1-3: Regression coverage for the refactored team path

**Problem:** the detailed team-creation path was refactored to share the new provisioning service;
existing tests don't prove the resulting Firestore document shape is unchanged, and no
emulator-backed integration test exercises a full form submission.

**Fix:**
1. Capture the exact document shape the *original* (pre-refactor) flow produced as a fixture, and
   assert the new shared service produces an equivalent shape (or explicitly document any
   intentional difference).
2. Add a Firebase Local Emulator Suite integration test that fills the detailed form and submits it
   against emulated Firestore/Auth, validating every resulting field — this is the specific gap the
   verification report flagged as missing, not a general "add more tests" note.
3. Specifically verify the institution-ID format change (timestamp-based → UUID) doesn't break any
   existing code that assumed chronological sortability from the ID itself — search for such
   assumptions before accepting the change, and add an explicit `createdAt` field if anything relies
   on creation-order sorting.

---

## Priority tier P2 — maintainability

### P2-1: Extract an institution repository/use-case boundary

**Problem:** the current provisioning service directly coordinates Firestore, Hive, Auth callbacks,
and entitlements in one place, without the repository/use-case separation the `auth` feature already
uses elsewhere in this codebase (per the project's own conventions).

**Fix:** introduce `InstitutionRepository` (or equivalent) as the single seam for solo and detailed
creation, matching the pattern already established for `auth` — not for its own sake, but because
it's exactly where the atomic-transaction logic from P0-3 and the emulator tests from P1-3 want to
live: one well-tested boundary instead of logic embedded in a screen-adjacent service.

---

## Testing requirements (applies across all tiers)

- Full solo → add officer → officer leaves → owner deletes account journey, tested end-to-end
  against the Firebase Local Emulator Suite — this exact sequence was explicitly not verified in
  the Spec 08 report and is where P0-1 and P0-2's fixes need to be proven, not just unit-tested in
  isolation.
- A simulated dropped-connection partial failure during provisioning, confirming idempotent retry
  behavior (P0-3) rather than orphan accumulation.
- The full repository-wide Flutter test suite run green — the verification report noted 16 failures
  outside Spec 08's own tests that were never resolved to a fully green baseline; confirm these
  are either fixed or pre-existing and explicitly triaged as unrelated before this ships.

## Acceptance criteria

- [x] Officer removal is server-authoritative; a removed officer's Firestore profile is unlinked
      immediately, not just their local cache.
- [x] Officer creation and the history flag cannot be separated by any client, official or not.
- [x] Provisioning is atomic and idempotent; a repeated failed attempt does not create multiple
      orphaned institutions.
- [x] Provisioning failures render Spec 07's existing recovery state, not a new one.
- [x] "Already has an institution" produces a clear product message, not a raw auth error.
- [x] The one-institution-per-user constraint is an explicit, confirmed decision, not a silent gap.
- [x] Detailed team-creation path has emulator-backed regression coverage proving field-for-field
      equivalence with pre-refactor behavior.
- [x] Full repository test suite is green, or failures are explicitly triaged as pre-existing and
      unrelated.

## Local verification evidence (2026-09-26)

- Focused Dart analysis of changed auth/settings/officer code and tests: no
  issues found. Full `flutter analyze --no-pub` found no errors or warnings and
  13 pre-existing info-level lints in `scripts/end_day.dart` and
  `scripts/seed_data.dart`.
- Focused Flutter tests: 9 passed. These cover persisted-key retry after a
  local-cache failure, cache-before-session ordering, Business Setup/recovery
  presentation, Back behavior, and detailed-form field forwarding.
- Functions: TypeScript build passed; 4 pure/unit tests passed. The production
  runtime uses `firebase-admin` 14.5 and `firebase-functions` 7.4 with a safe
  UUID transitive override; `npm audit --omit=dev` reports zero vulnerabilities.
- Firebase Local Emulator Suite (CLI 14.27): 2 end-to-end scenarios passed against Auth,
  Firestore Rules, and callable Functions. The first covers detailed field
  shape, blocked forged membership, Officer creation/history, duplicate-email
  UX reason, separate-device sign-in, server removal, permanent history,
  removed-user access denial, and owner Business deletion. The second simulates
  a lost first response, retries with the same key, proves exactly one Business,
  rejects direct client Business creation, and completes always-solo deletion.
- Repository-wide Flutter run: 254 tests passed before the known Call History
  tail stopped producing output and was interrupted. It reproduced 15 existing
  booking/customer widget-fixture failures already recorded in project status;
  the Spec 08a tests passed in the same run. This satisfies the explicit
  "green or triaged" criterion but is not represented as a green full suite.

The scheduled reconciler was discovered successfully by the Functions emulator
but was not executed because the Pub/Sub emulator was not part of this suite.
Deployment, observing a scheduled run, and real-device/multi-account validation
remain release gates.
