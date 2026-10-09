# Store Compliance Watchlist for Agents

**Last reviewed:** September 24, 2026  
**Scope:** Specs 01–05 in `store guideline files/`  
**Release state:** Open — Bookly is not store-submission ready

Read this file during the mandatory agent bootstrap. It exists so incomplete
deployment, console, legal, and real-device work is not lost after the source
implementation lands. Bring up the relevant open gate whenever a task touches
its trigger. Keep `docs/agents/project-status.md` and `../Concern_Tracking.md`
synchronized when a gate materially changes.

## Status Vocabulary

- **Implemented:** the change exists in the current working tree.
- **Locally verified:** relevant static checks/tests pass on the current host.
- **Deployed/configured:** the required external service or store-console state
  is live in the intended production project.
- **End-to-end verified:** the real build and real service flow passed on the
  required physical devices/accounts.
- **Complete:** all required states above and every acceptance criterion for the
  spec are satisfied. Do not use this word earlier.

Every compliance handoff must state which of these states was actually reached.

## Spec 01 — Call Recording and Call-Log Release Gate

**Current state:** Source gate implemented and locally verified; real-device
release behavior remains open.

The public release manifest excludes system call-log ingestion, microphone
recording, direct calling, and dormant components. App-initiated call activity
remains in Call History by product decision. The dormant implementation is
available only behind the explicit debug build property.

Still required before completion:

- Install the release build on physical Android hardware and confirm no call
  log, microphone, or direct-call permission prompt appears.
- Place a call through Bookly and confirm only the in-app initiated event is
  recorded; confirm no system call history or audio is ingested.
- Exercise the dormant debug flag separately and confirm disabling it restores
  the public-release behavior.
- Re-run merged-manifest checks after any Android plugin, manifest, Gradle, or
  call-feature change.

Raise this spec when work touches telephony, permissions, Android manifests,
Call History, Insights call metrics, build flavors, or release builds.

## Spec 02 — iOS Release Baseline

**Current state:** Credential-independent source and hosted-CI baseline are
locally verified; signing, TestFlight, and physical-device validation remain
open.

Still required before completion:

- Confirm the provisional bundle identifier `com.ashDilussi.bookly` is final.
- Complete Apple Developer enrollment and create the App Store Connect app,
  signing assets, API key, and Codemagic credential groups.
- Supply the real `bookly-1f5f7` `GoogleService-Info.plist` through the CI
  secret path and verify its bundle ID matches the selected identifier.
- Run the Codemagic workflow, produce a signed IPA, upload it to TestFlight,
  and install/test it on a physical iPhone.
- Re-check the generated iOS privacy manifest/SDK declarations against the
  final dependency graph.

Raise this spec when work touches iOS, Firebase configuration, bundle IDs,
OAuth, CocoaPods, signing, CI/CD, archive/export, TestFlight, or App Store
Connect. Ask the owner who controls and backs up signing credentials before
making signing operational.

## Spec 03 — Account Deletion and Provider Scope

**Current state:** Source implementation and focused local checks pass; the
backend and public flow are not deployed or end-to-end verified.

On September 26, 2026, local Auth/Firestore/Functions emulator journeys also
passed for Spec 08a provisioning, Officer lifecycle/history, removed-Officer
access denial, and deletion. This is local evidence only; it does not satisfy
the deployment or physical-device gates below.

Spec 08 extends this deletion boundary. Newly created businesses store
`hasEverHadAdditionalStaff=false`; first Officer provisioning atomically and
permanently changes it to `true`. A direct solo deletion request is promoted to
full business deletion only when the callable sees an explicit `false` marker
and finds no current member other than the owner. Missing/legacy markers remain
on the cautious sole-owner path. Do not treat the simplified client copy as
the security decision.

Spec 08a makes the related identity boundary server-authoritative. The trusted
`provisionBusiness` transaction owns Business creation, owner membership, and
an opaque hashed idempotency receipt; `createOfficer` commits membership plus
permanent history; `removeOfficer` clears remote membership before local cache
changes. Rules read `users/{uid}` rather than role/institution custom claims.
The current release supports one Business per identity. These Functions/Rules
changes are source-only until explicitly deployed and verified.

Still required before completion:

- Deploy Firebase Functions and Hosting to `bookly-1f5f7`.
- Enable Firebase email-link authentication and authorize
  `bookly-1f5f7.web.app`.
- Validate officer deletion, sole-owner blocking, institution deletion, and
  next-auth-check local purge with real accounts on at least two devices.
- Validate always-solo direct deletion, solo-to-team growth, Officer removal,
  and an offline/stale client against the server-side staff-history check.
- Validate same-key retry after a lost callable response creates exactly one
  Business, then observe at least one scheduled orphan-reconciliation run and
  inspect its logs before release.
- Validate Google OAuth grant revocation for Android Google-authenticated
  accounts and validate the public verified-email deletion flow.
- Confirm live-subscription deletion remains blocked if billing ships.
- Link the public deletion URL from store listings and the privacy policy.

Raise this spec when work touches authentication, user/institution records,
roles, subscriptions, Firebase Functions/Hosting, OAuth, local caches, privacy
pages, or store account-deletion declarations.

## Spec 04 — Privacy Policy and Store Data Mapping

**Current state:** v3 decisions are authoritative. The technical draft and
permission remedy are implemented and locally verified; publication,
store-console entries, and device validation remain blocked.

Locked v3 decisions:

- Worldwide distribution from day one; use GDPR-baseline rights language.
- Public base URL: `https://bookly-1f5f7.web.app`.
- Privacy/support email: `bookly.support@gmail.com`.
- Immediate deletion with no intentional retention window for v1.
- Protected health information and medical records are prohibited for v1.
- Contact import must use the OS-owned single-contact picker with no broad
  contacts permission.
- Code/app compliance proceeds now, while legal-page publication and live app
  links are intentionally deferred to a later stage. Deferral does not waive
  those release requirements.
- Sri Lanka PDPA readiness is a release gate. Gazette No. 2498/16 appoints
  January 1, 2027 for Sections 2–3, Part I, and Part III. Do not overstate the
  Gazette as commencing Part II; counsel must confirm rights commencement and
  procedure against the final legal instruments.

Still required before completion:

- Obtain the owner's exact public legal name and public/registered business
  address. This is a hard publication gate: do not publish the policy or Terms,
  and do not mark store mappings final, while these fields are unknown.
- Obtain legal review/sign-off for worldwide publication and specifically the
  Sri Lanka PDPA: controller/processor roles, Part II rights timing, DPO
  designation, DPIA triggers, breach duties, and cross-border transfers. The
  DPA currently publishes detailed instruments in these areas as drafts, so
  agents must re-check final official instruments rather than hard-code draft
  thresholds or timelines.
- Accept/verify Google's applicable Firebase/Cloud data-processing terms in
  the production console.
- Publish final Privacy Policy and Terms pages without placeholders, link them
  from Settings and registration, and verify both URLs anonymously.
- Enter the final Play Data Safety and Apple App Privacy answers based on the
  exact release binary, including all third-party SDK behavior.
- Validate native contact selection on physical Android and iOS devices and
  confirm neither platform requests broad contacts access.
- Refresh the inventory after any SDK, permission, storage, sync, logging,
  billing, ads, analytics, crash reporting, or data-retention change.
- Include `businessProvisioning` receipts in the final inventory: they contain
  a SHA-256-derived opaque request document ID plus owner UID, Business ID,
  status, and timestamps; they are server-only and are deleted with the
  Business. Confirm the final policy/store mapping accurately describes this
  account/business setup metadata without implying it is customer content.
- Before production, retain the counsel/owner-approved processing inventory,
  lawful-basis analysis, DPO decision, DPIA screening, breach runbook,
  cross-border safeguards, and data-subject-request procedure.

The working draft and mappings live in
`docs/compliance/spec-04-privacy-and-store-mapping.md`.

Raise this spec whenever work touches any personal/business data, permissions,
SDKs, remote APIs, storage, diagnostics, synchronization, Calendar, deletion,
legal text, Settings legal links, registration consent, or store forms. If the
owner supplies the legal name/address, immediately surface the publication and
legal-review tasks rather than treating the new information as completion.

## Spec 05 — Store Release Engineering Checklist

**Current state:** Code-side hardening is implemented; final signing, artifacts,
store-console work, and device acceptance are not complete. Execute the final
pass only against the production binaries after Specs 01–04 are stable.

Still required before completion:

- Re-verify the Play target API requirement at submission time. Source now
  explicitly targets API 36 with AGP 8.10.1; build the final Android App Bundle
  with production signing and confirm the target in Play Console.
- Identify the production-keystore owner and document secure backup/recovery;
  decide whether releases are CI/CD or a controlled manual process.
- Release-mode code hides all Coming Soon, unfinished billing, unpublished
  legal, map/help/notification, and sample-data surfaces. Contact Support is a
  real email handoff. A signed-build navigation/deep-link walkthrough is still
  required, and live legal links must be restored after publication.
- The signed navigation walkthrough must now cover both Business Setup choices,
  the solo confirmation and `Not now` Calendar escape, full linked-owner
  Settings parity, first-Officer growth, and both account-deletion branches.
- Prepare reviewer credentials/instructions that exercise each role safely.
- Reconcile Play Data Safety, Apple App Privacy, privacy manifests, and export
  compliance against the final binary and dependency graph.
- Run architecture, 16 KB page-size, pre-launch, content-rating, age-rating,
  accessibility, screenshot/metadata, release-build, and physical-device checks.
- Confirm all five owner-only Spec 02 items and a physical-iPhone TestFlight
  install; do not infer completion from the Codemagic YAML.
- Complete a clean full analyzer/test/build pass and record exact results.

Raise this spec for any store-submission, production build, signing, dependency
upgrade, target-SDK, release metadata, reviewer-access, screenshot, content
rating, encryption/export, or production-visible navigation task.

The detailed implementation evidence and release runbook live in
`docs/compliance/spec-05-store-release-engineering.md`.

## Cross-Spec Triggers

| When this changes | Required reminder/action |
|---|---|
| Permission, plugin, SDK, or remote API | Re-audit Specs 01, 02, 04, and the final Spec 05 binary. |
| Authentication, account, role, subscription, or cache behavior | Re-audit Spec 03 deletion coverage and Spec 04 disclosures. |
| Data model, persistence, synchronization, logging, or retention | Update the Spec 04 inventory/policy/mappings and deletion coverage before release. |
| Firebase/Google console access becomes available | Surface Spec 03 deployment/email-link work and Spec 04 data-processing-terms verification. |
| Owner legal name/address becomes available | Complete legal review, publication, app links, and final store mappings for Spec 04. |
| Sri Lanka Gazette/DPA instrument or privacy operating model changes | Re-check Spec 04's PDPA commencement, DPO, DPIA, breach, rights, and cross-border gates with counsel. |
| iOS or CI/release work | Surface outstanding Spec 02 signing/TestFlight/device gates. |
| Any release/store submission request | Run all open items here; do not skip directly to Spec 05. |

## Non-Negotiable Handoff Rule

Never collapse “code exists,” “tests pass,” “deployed,” “console configured,”
and “real-device verified” into one status. A final response that touches a
compliance spec must name the remaining external and validation gates, even if
the requested source change itself is finished.
