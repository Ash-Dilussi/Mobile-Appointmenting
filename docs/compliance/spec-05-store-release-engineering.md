# Spec 05 — Store Release Engineering

**Status:** Code-side release baseline implemented; external release gates open  
**Authoritative checklist:** `store guideline files/spec 2 remedies/05-store-release-engineering-checklist.md`  
**Reviewed:** September 24, 2026  

This is the operational handoff for an agent preparing Bookly for Google Play
or App Store submission. Source implementation, local tests, deployment,
console configuration, signed artifacts, and physical-device acceptance are
separate states. Do not call Spec 05 complete until every acceptance row below
is verified against the final binaries.

## Current Official Baseline

- From August 31, 2026, Google Play requires new phone/tablet apps and updates
  to target Android 16 / API 36 or higher. Bookly now explicitly targets API
  36; it does not rely on Flutter's older API 35 default or assume eligibility
  for an extension.
- Android Gradle Plugin 8.10 is the first stable AGP line with official API 36
  support. Bookly uses patched AGP 8.10.1 with the existing compatible Gradle
  8.12 wrapper.
- Google currently requires apps targeting API 35+ to support 16 KB page sizes
  on 64-bit devices, with the update-submission enforcement date published as
  February 1, 2027. The final production bundle must be checked in Play, not
  inferred from a debug build.

Official references:

- <https://support.google.com/googleplay/android-developer/answer/11926878>
- <https://developer.android.com/build/releases/agp-8-10-0-release-notes>
- <https://developer.android.com/guide/practices/page-sizes>
- <https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance>

## Discovery Results

- Android previously used `targetSdk = flutter.targetSdkVersion`, which
  resolved to API 35 in Flutter 3.32.5, and the release build explicitly used
  the debug signing key.
- Codemagic currently contains an iOS/TestFlight workflow. There is no Android
  production-signing workflow or documented manual release owner.
- Development placeholders were reachable from Home, Settings, and Station
  Management. The router also exposed an unfinished billing screen containing
  placeholder Stripe URLs, and Settings exposed destructive sample-data tools.
- The reviewed dependency and source inventory uses provider/OS HTTPS and
  secure storage but contains no app-authored encryption algorithm. This is an
  engineering observation, not the final export-compliance declaration.

## Implemented in Source

1. Android explicitly targets API 36 and uses AGP 8.10.1.
2. Release signing uses a dedicated `release` signing configuration. It may be
   supplied by ignored `android/key.properties` or the documented
   `BOOKLY_ANDROID_*` environment variables.
3. A release task fails immediately if any signing value or the keystore file
   is missing. There is no fallback to the debug key.
4. Keystores and real signing property files remain excluded from version
   control. `android/key.properties.example` documents the required shape only.
5. `ReleaseScope.developmentOnlyDestinationsEnabled` removes the following
   from a release build:
   - the `/coming-soon` route and all notification/help/legal/map triggers;
   - the unfinished `/upgrade` billing route with placeholder checkout URLs;
   - Settings' destructive Load Sample Data tools; and
   - unpublished Terms/Privacy acceptance copy on registration.
6. Contact Support now opens a real, user-initiated email to
   `bookly.support@gmail.com`; failure to open an email app is handled.
7. The inaccurate Settings hint that missed calls are tracked automatically
   now states that calls started from Bookly appear in Call History.

The development-only fallback remains available in debug builds. It must not
be used as evidence that Notifications, Help Center, maps, billing, Terms, or
Privacy are implemented.

## Android Signing Handoff

Do not generate or commit a production keystore until the owner answers the
two open ownership/process questions below. After that decision:

1. Generate the upload key in the owner-approved secure location.
2. Copy `android/key.properties.example` to ignored
   `android/key.properties`, or inject all four `BOOKLY_ANDROID_*` variables.
3. Keep the keystore, passwords, and recovery material outside source control.
4. Build `flutter build appbundle --release`.
5. Verify the AAB certificate is the production upload certificate, upload to
   an internal Play track, install the Play-generated build, and record the
   certificate fingerprint and Play App Signing enrollment evidence.
6. Test key-loss recovery and record at least two authorized custodians or the
   approved single-custodian plus escrow arrangement.

## Release-Time Gates Carried Forward From Spec 04

These items are intentionally deferred now and mandatory at release time:

- obtain the owner's exact public legal name and public/registered address;
- complete worldwide and Sri Lanka PDPA legal review, including Part II
  timing, controller/processor roles, DPO, DPIA, breach, data-subject-request,
  and cross-border-transfer requirements;
- re-check the Gazette and final DPA instruments rather than relying on current
  drafts;
- accept and retain evidence of the applicable Google/Firebase data-processing
  terms;
- deploy and verify the Spec 03 deletion backend and public email-link flow;
- publish live `/privacy/` and `/terms/` pages with no tokens or placeholders;
- replace the hidden/development legal entries with working in-app links and
  link registration copy only after both documents are live;
- re-audit the final AAB and IPA, then enter Play Data Safety and App Store
  Privacy answers from those exact artifacts; and
- validate the native contact picker on physical Android and iOS devices.

## Final Store-Release Checklist

### Build and signing

- [x] Source target set to API 36.
- [x] API-36-compatible AGP configured and a debug AAB built locally.
- [x] Debug signing fallback removed; missing production signing fails closed.
- [ ] Owner/custodian and backup/recovery plan approved.
- [ ] Final production upload keystore created and secured.
- [ ] Production-signed AAB built, certificate verified, and installed from an
      internal Play track on physical hardware.
- [ ] Final AAB passes Play's 64-bit, 16 KB page-size, integrity, and pre-launch
      checks with no blocking issue.

### App surface

- [x] Development placeholders, unfinished billing, and sample-data tools are
      excluded from release-mode navigation/source conditions.
- [x] Contact Support has a real email handoff.
- [ ] Walk every Home, Settings, station, feature-gate, deep-link, and reviewer
      path in the signed release build and confirm no placeholder or dead end.
- [ ] Restore Terms/Privacy links only after the live pages pass anonymous URL
      checks.

### iOS / Spec 02 carry-forward

- [ ] Register/confirm the Firebase iOS app and final bundle ID.
- [ ] Supply the real Firebase plist through the Codemagic secret.
- [ ] Confirm Apple Team ID and final bundle ID.
- [ ] Configure App Store Connect API credentials in Codemagic.
- [ ] Build, upload, install, and verify a real TestFlight build on a physical
      iPhone.

### Store consoles and review access

- [ ] Create final reviewer accounts; never commit their credentials.
- [ ] Put the credentials and the following role note only in the stores'
      secure review fields:
      `Bookly has Owner and Officer roles. The supplied Owner account can create
      or manage the institution, services, stations, and staff. The Officer
      account can manage daily bookings/customers within that institution.`
- [ ] Verify login, company setup, booking, customer, Calendar scope, account
      deletion, and role behavior with the supplied accounts.
- [ ] Complete Play Data Safety and App Store Privacy from the final binaries.
- [ ] Complete Play content rating and Apple age rating from actual v1 behavior.
- [ ] Have the Account Holder answer Apple export compliance. Source review
      found no custom encryption; do not set `ITSAppUsesNonExemptEncryption`
      until the final dependency inventory and exemption answer are approved.

### Listing assets

- [ ] Capture screenshots from the final release build for Login, Home,
      Calendar, Booking, Customers, app-initiated Call History, and Settings.
- [ ] Use representative non-sensitive demo data and verify no real customer,
      staff, email, phone, or institution data appears.
- [ ] Do not show system call-log ingestion, recording, missed-call claims,
      voice booking, Google features on iOS, Coming Soon screens, developer
      tools, or placeholder billing.
- [ ] Confirm every screenshot, description claim, support URL, deletion URL,
      privacy URL, and Terms URL matches the shipped platform behavior.

## Acceptance Status

| Acceptance criterion | Status | Evidence / remaining work |
|---|---|---|
| Required target API | Locally verified | API 36 + AGP 8.10.1; debug AAB build passed. Re-check policy and final AAB at submission. |
| Production signing | Implemented, not configured | Fail-closed release configuration exists; owner, key, backup, signed build, and install are open. |
| No production placeholders | Implemented, not device-verified | Release gates remove routes/triggers; signed-release walkthrough remains open. |
| Final privacy forms | Open | Spec 04 publication and exact final binaries are required first. |
| Accurate listing assets | Open | Capture only after final signed platform builds are stable. |
| Spec 02 owner-only items | Open | All five items and physical TestFlight verification remain mandatory. |

## Local Validation Evidence

- Focused Dart analysis completed with no issues.
- Fourteen cross-spec compliance tests passed.
- AGP 8.10.1 built a debug AAB successfully; its bundle contains arm64-v8a,
  armeabi-v7a, and x86_64 native libraries.
- An unsigned/unconfigured release task stops before packaging with the intended
  production-signing error instead of using the debug key.
- A validation-only release build progressed through Flutter release AOT and
  release dependency compilation after the cross-drive Kotlin cache workaround,
  but final packaging did not complete because Google Maven repeatedly
  terminated TLS downloads for required Flutter/AGP analysis artifacts. A
  bounded retry remained network-bound and was stopped. No release AAB is
  claimed; all ephemeral validation keys and any validation artifact were
  removed.

Repeat the production-signed release build on the approved release host/CI with
stable Google Maven access. Do not reinterpret the successful debug bundle or
partial validation build as the final acceptance result.

## Open Owner Decisions

1. Who owns/manages the Android production upload keystore, and what exact
   backup, recovery, and succession process is approved?
2. Should Android releases be added to Codemagic, or remain a controlled manual
   process? The repository currently automates iOS only.

These decisions must be supplied by the owner. An agent must not generate the
real key, choose its custodian, upload artifacts, or commit secrets by inference.
