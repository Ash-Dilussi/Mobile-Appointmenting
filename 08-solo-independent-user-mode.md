# Spec 08 — Solo/Independent User Mode

**Implementation status (2026-09-25):** Implemented in the working tree and
covered by focused local Flutter and Functions tests. Firebase Rules/Functions
deployment plus real-device solo-to-team and deletion verification remain open;
this document does not claim release completion.

**Production-hardening follow-up (2026-09-26):** Spec 08a replaces direct
Business/Officer membership writes with idempotent callable transactions,
server-authoritative Officer removal, strict prototype Rules, recovery UI, and
a repository boundary. Treat `08a-solo-mode-production-hardening.md` as the
current security/data-integrity authority for this flow.

**Goal:** Let someone who has no interest in setting up a multi-staff business still get full use
of Bookly — appointments, customers, services, service locations, and optional Google Calendar
sync — without ever being asked to "create a company."

**Not part of the store-compliance chain (Specs 01–06)** — this is a product feature addition.

---

## 1. Confirmed facts

- Bookly's data model is institution-scoped throughout — customers, services, appointments, and
  call logs are all keyed by `institutionId` (confirmed repeatedly across Specs 01–07's discovery).
- Google Calendar sync (`calendar.events`, `calendar.readonly` scopes) already exists as an
  optional, user-enabled feature (confirmed in Spec 03/04 discovery) — this spec surfaces it for
  solo users, it doesn't build it from scratch.
- Spec 03 already defines sole-owner account-deletion handling (block with two paths: delete the
  institution, or cancel — no self-service transfer). Every solo user created by this spec is, by
  definition, a sole-owner institution, so this spec must coordinate with that logic (Decision 6).
- Spec 07 established the precedent of auditing and unifying inconsistent user-facing terminology
  ("Manage Stations" vs. "Service Location"). This spec extends that same discipline to "Company."

## 2. Decisions

1. **Onboarding fork:** replace the single "Create Company" step with an upfront choice — working
   solo vs. managing a team. Exact copy TBD, but the solo option's own label should avoid the word
   "company" entirely.
   - **Solo** → auto-provision an institution behind the scenes (Decision 2), skip straight into
     the main app.
   - **Team** → today's "Create Company" flow, unchanged.
2. **Auto-provisioned institution:** generate a sensible default name (e.g. "{display name}'s
   Business"), set the registering user as owner, skip any staff-invite step. Show a brief,
   one-time confirmation during onboarding (e.g. "We've set up your business as '{name}' — rename
   this anytime in Settings") rather than making it invisible — assumption, flag if you'd rather it
   stay silent until the user looks in Settings themselves. The name is editable later; no forced
   extra data entry at signup beyond what solo users already provide.
3. **Full feature parity:** solo users get Customers, Services, Service Locations, and Staff
   Management — nothing hidden. This gives a natural growth path: a solo user can invite their
   first staff member later with zero data migration, since they're already on the same institution
   model underneath.
4. **Terminology:** rename "Company" to "Business" (or agreed equivalent) **app-wide**, not
   conditionally per account type — simpler to build/maintain, and arguably reads more naturally for
   team accounts too (a salon or clinic isn't colloquially a "company" either). Extend Spec 07's
   terminology audit to cover every "Company"/institution-facing string.
5. **Google Calendar sync:** available to solo users on the same terms as team users (already
   built). Surface it as a suggested, fully skippable step during solo onboarding ("Want to bring in
   appointments you already have in Google Calendar?") — not required to use the app.
6. **Coordination with Spec 03's deletion logic:** track whether an institution has ever had more
   than one officer. If it hasn't, "delete my account" maps directly to full, simple deletion
   without Spec 03's more cautious two-path messaging — that messaging exists to protect other
   people's data/livelihood, which doesn't apply to someone who has always been alone. If an
   institution has ever had multiple officers (even if some later left), keep Spec 03's original
   flow unchanged.

## 3. Discovery steps for the executing agent

1. Confirm the exact current registration/onboarding files and where "Create Company" is
   triggered, to find the right insertion point for the solo/team fork.
2. Confirm every current use of "Company"/institution-facing terminology in user-visible strings —
   extend Spec 07's naming-audit discovery rather than starting a separate one.
3. Confirm how Staff Management currently checks the owner role, to verify a solo owner sees it
   through normal owner-permission logic with no special-casing needed.
4. Confirm the institution schema's required vs. optional fields at creation time (Firestore rules/
   validation) so the auto-provisioned default doesn't fail validation for fields a real "Create
   Company" flow would normally collect from the user directly.
5. Confirm whether "has this institution ever had more than one officer" is derivable from existing
   data (an officer-count field, membership history) or needs a new field added for Decision 6.

## 4. Functional requirements

1. Add the solo/team onboarding fork ahead of the existing company-creation step.
2. Implement auto-provisioning for the solo path: institution creation with defaults, owner
   assignment, skip the staff-invite step, one-time naming confirmation per Decision 2.
3. Rename "Company" → "Business" (or the agreed term) across every string found in discovery step 2.
4. Confirm Staff Management, Services, and Service Locations render normally for solo/owner
   accounts with no additional gating beyond existing role checks.
5. Add the optional, skippable Google Calendar sync prompt to solo onboarding, reusing the existing
   integration — no new Calendar functionality being built here.
6. Add the "ever had more than one officer" tracking and branch Spec 03's deletion Cloud Function
   accordingly.

## 5. Explicitly out of scope

- A genuinely separate no-institution data model — rejected in favor of auto-provisioning (this
  was an explicit decision, not a default).
- Changing Spec 03's deletion flow for any institution that has ever had multiple officers — only
  the always-been-alone case gets the simplified path.
- Multi-currency, invoicing, or other business-specific features unrelated to the solo/team
  distinction itself.

## 6. File-by-file task list

- [x] Registration/onboarding screen(s) — add the solo/team fork
- [x] Institution-creation service/provider — auto-provisioning logic for the solo path
- [x] Every user-facing screen/string found in discovery step 2 — "Company" → "Business" rename
- [x] Staff Management, Services, Service Locations screens — confirm no changes needed beyond
      existing role checks (verification task, likely no code change)
- [x] Solo-onboarding flow — optional Google Calendar sync prompt
- [x] Spec 03's deletion Cloud Function — add the single-officer-ever check from Decision 6

## 7. Testing requirements

- New solo signup never sees "company"-labeled UI or a company-creation form; lands directly in a
  working app with sensible, editable defaults.
- Existing team-based "Create Company" flow is unaffected by this change.
- A solo user invites a staff member later; confirm existing data (customers, appointments)
  survives untouched and the account now behaves like a normal multi-officer institution.
- Terminology is consistent everywhere post-rename — no leftover "Company" strings.
- Google Calendar sync is accessible and genuinely skippable during solo onboarding.
- An always-solo owner's account deletion is simple and direct; an owner whose institution has ever
  had other officers still gets Spec 03's original two-path flow, unchanged.

## 8. Acceptance criteria

- [x] A solo signup completes with zero company-specific UI or required fields beyond what a team
      signup already collects.
- [x] Full feature parity confirmed in routing/role logic for solo accounts (Customers, Services, Service Locations,
      Staff Management).
- [x] "Business" is the only user-facing label used app-wide — no naming inconsistency
      reintroduced.
- [x] Solo-to-team growth path uses the existing institution and requires no data migration.
- [x] Deletion behavior branches on officer history per Decision 6 in source and unit tests.
- [ ] Deploy the Firestore Rules and callable, then verify new solo, first Officer,
      removed Officer, legacy/unknown history, stale/offline client, and two-device deletion
      against the real Firebase project.

## 9. Resolved copy decisions

- The fork labels are **Just me** and **My team**; the app-wide user-facing
  term is **Business**. Internal institution model and legacy route/class names
  remain unchanged to avoid a data or navigation migration.
- Solo setup shows the one-time **Your business is ready** confirmation and
  editable generated name. The optional Calendar card provides both Connect
  and **Not now**; it remains absent from the first iOS release under the
  existing release-scope gate.
- New businesses store a known-false staff-history marker. First Officer
  provisioning permanently sets it true. Legacy/missing values are deliberately
  treated as unknown and keep the cautious Spec 03 deletion flow.
