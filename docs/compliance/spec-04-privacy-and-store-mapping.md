# Spec 04 — Privacy, Terms, and Store Data Mapping

**Status:** Code/app compliance baseline implemented; publication intentionally deferred  
**Authoritative clarification:** `store guideline files/04-privacy-policy-and-store-data-mapping v3.md`  
**Reviewed against source and current official material:** September 24, 2026  
**Distribution:** Worldwide  
**Public base URL:** `https://bookly-1f5f7.web.app`  
**Privacy/support email:** `bookly.support@gmail.com`

This document is an implementation and console-entry brief for an agent. It is
not legal advice. It deliberately separates confirmed source behavior from
publication work and console answers that still require the final binary.

The current delivery stage is code and app compliance only. Do not publish
placeholder legal pages or route Settings/registration to URLs that are not
live. Publication, live app links, and store-console submission remain a later
stage, but they remain mandatory before a production store submission.

## Hard Publication Gate

The following owner-supplied facts are not in the repository:

- `[[OWNER_PUBLIC_LEGAL_NAME]]`
- `[[OWNER_PUBLIC_OR_REGISTERED_BUSINESS_ADDRESS]]`

Do not publish the Privacy Policy or Terms, replace the Settings placeholders,
or mark either store mapping final until both values are supplied and the text
has received appropriate legal review. Do not invent, infer, or silently omit
them. Drafts may continue in parallel.

The owner must also accept/verify Google's applicable Firebase/Google Cloud
data-processing terms in the production console. That external action cannot
be proven by source code.

## Sri Lanka PDPA Readiness Gate Added by v3

Bookly's controller is expected to be established in Sri Lanka, so Sri Lankan
privacy counsel must review the final operating model even when a data subject
is elsewhere. This is not a launch-nearby issue to postpone until after store
submission.

The controlling official commencement evidence reviewed on September 24, 2026
is Extraordinary Gazette No. 2498/16 of July 22, 2026. Its text appoints
**January 1, 2027** for Sections 2 and 3, Part I (processing of personal data),
and Part III (controllers and processors). The Gazette does not, on its face,
list Part II (data-subject rights). The policy will still use the stricter
GDPR-baseline rights language, but counsel must confirm the operative date and
procedure for Sri Lankan Part II rights instead of treating an older DPA web
page or this repository as a legal conclusion.

The DPA download page currently labels the detailed DPO, personal-data-breach,
data-protection-impact-assessment, and rights/appeals instruments as drafts.
Their draft thresholds and time periods are useful readiness inputs, but must
not be hard-coded into the app, incident promises, or final policy until final
instruments and counsel are checked at publication time.

Before production release, the owner and counsel must therefore complete and
retain evidence of:

- controller/processor role allocation for Bookly, each institution, Firebase,
  and Google Calendar;
- the lawful-basis and transparency analysis for account, institution, local
  customer, Calendar, deletion, and support processing;
- a DPO designation assessment under the final Sri Lankan requirements;
- a DPIA screening and, if triggered, the completed assessment;
- a personal-data-breach response and notification runbook using the final
  binding timelines and contact points;
- a cross-border-transfer review for Firebase/Google processing outside Sri
  Lanka, including the applicable contractual safeguards; and
- a data-subject request process covering identity verification, access,
  correction, deletion, portability where applicable, objection/restriction,
  response records, and appeals/complaints.

These are operational/legal release controls. Spec 04 does not invent a new
data-export feature, and none should be represented as implemented merely by
listing it here.

## Confirmed v1 Decisions

- Distribution is worldwide from day one.
- Privacy-rights language uses a GDPR baseline: access, correction, deletion,
  portability, objection, and restriction.
- Sri Lanka PDPA review is a specific release gate, including commencement,
  DPO, DPIA, breach, data-subject-rights, and cross-border-transfer analysis.
- Account and institution deletion is intended to be immediate in v1, with no
  voluntary post-deletion retention window. The account-deletion backend and
  web request flow must be deployed and verified before this promise is live.
- Bookly v1 is not intended for protected health information, medical records,
  diagnoses, treatment details, or other regulated health data. Users must not
  enter such information in names, notes, appointments, or Calendar events.
- The support/privacy address is `bookly.support@gmail.com`.
- Firebase Hosting at `bookly-1f5f7.web.app` is the public host for v1.
- App-initiated call activity remains visible in Call History. System call-log
  ingestion and call recording are disabled in the public release.
- Contact import uses the operating system's single-contact picker. Bookly does
  not request broad address-book access and receives only the selected entry.

## Source-Verified Data Inventory

| Data and source | Storage/destination | Off device? | Purpose and notes |
|---|---|---:|---|
| Account UID, name, email, optional profile-photo URL, role, institution membership, email-verification state, password-change prompt, timestamps | Firebase Authentication and Firestore; selected fields cached in Hive | Yes | Authentication, account management, access control, and multi-tenant membership. Password credentials are handled by Firebase Authentication; Bookly does not store plaintext passwords. |
| Business/institution ID, owner ID, name, optional address/phone/email, theme preset, permanent ever-had-additional-staff flag, timestamps | Firestore at business creation; local Hive cache | Yes | Business setup, tenancy, contact details, appearance, and safe selection of the account-deletion flow. `false` is written for a new owner-only business, first Officer provisioning permanently changes it to `true`, and legacy/missing values remain unknown/cautious. Current Edit Business behavior updates the local copy; do not claim all later edits synchronize until that path is implemented and verified. |
| Officer name, email, UID, role, institution membership, password-change flag | Firebase Authentication and Firestore | Yes | Owner-invited staff authentication and authorization. |
| Subscription tier, expiry, feature overrides, optional external subscription identifiers | Firestore and local cache | Yes | Entitlement resolution and deletion guard. No live in-app purchase/payment collection is established in the reviewed v1 source; re-audit if billing ships. |
| Customers: name, phone, email, address, city, DOB, notes, appointment history | Hive on the device | No by default | Operational CRM. There is no active customer sync worker. A customer's name and selected appointment notes leave the device only when an Android user explicitly creates a Google Calendar event. |
| Appointments: times, services, prices, locations, notes, status, staff attribution | Hive on the device | No by default | Scheduling and local Insights. An explicitly Calendar-synced appointment sends the fields described below to Google. |
| Services, stations, leave requests, app-initiated call entries, and operational Insights inputs | Hive on the device | No | Local business operation. Public v1 does not read the system call log or record audio. |
| One contact selected in the OS contact picker: display name, first phone, first email | Copied into the customer form and then Hive if saved | No by default | User-directed form prefill. No broad contacts permission, contact-list scan, or OS contact identifier is retained. |
| New Calendar event: customer display name in event title, start/end time, and structured appointment-note text in description | User's primary Google Calendar | Yes, only when the Android user signs into Calendar and checks “Add to Google Calendar” | Optional app functionality. Bookly stores the returned event ID locally. The event remains under the user's Google account until the user removes it there, even if Bookly access is later revoked. |
| Existing Google Calendar event ID, title, start/end, and organizer display name within the requested date window | Read from the signed-in officer's primary Google Calendar and displayed in Bookly | Yes | Optional Android calendar overlay. The integration is per signed-in officer/device, not institution-wide. Current scopes are `calendar.events` and `calendar.readonly`; scope minimization should be reviewed separately. |
| Error message, source, optional error object, and stack trace | Device-local daily log files | No | Troubleshooting. Only error-level entries are persisted and files older than seven days are cleaned at app initialization. Do not deliberately place secrets or health data in logs. |
| Account/business deletion request metadata, authenticated identity, business staff-history flag, and current membership query | Firebase callable function; Hosting email-link flow when deployed | Yes | Security verification, selection of always-solo versus cautious deletion, and deletion execution. The final deployed behavior must be re-inventoried, including any provider/platform logs outside Bookly's application data. |

### Confirmed Absent from the Reviewed v1 Dependency Graph

- Advertising SDKs
- Product analytics SDKs
- Remote crash-reporting SDKs
- Background system call-log upload
- Call-audio collection or upload
- Customer/appointment Firestore synchronization

This absence is a snapshot, not a permanent declaration. Any dependency,
permission, API, or sync change reopens this inventory and both store mappings.

## Processor and Third-Party Roles

| Recipient | Role in this implementation | Data involved |
|---|---|---|
| Google Firebase Authentication, Firestore, Functions, and Hosting | Service provider/processor for Bookly's account, tenancy, entitlement, deletion, and hosted-page infrastructure, subject to the production account's accepted terms | Account, institution, staff, entitlement, and deletion-flow data |
| Google Sign-In | Authentication provider on Android; disabled for the first iOS release | Google account identity and OAuth credentials handled by Google/Firebase |
| Google Calendar | Optional third-party destination and source selected by an Android officer | Calendar events and the customer name/appointment-note content explicitly written to an event |
| Device operating system | Local storage, native contact picker, and external dialer handoff | Local app data; one selected contact; dialed phone number passed to the dialer |

## Google Play Data Safety Mapping

Use this as the conservative v1 answer sheet, then reconcile it in Play Console
against the final Android App Bundle and the current form wording. Google Play
defines collection around data transmitted off device; device-only processing
does not by itself require a “collected” answer. SDK behavior counts.

| Play data type | Collected? | Shared? | Required/optional | Purpose and feature |
|---|---:|---:|---|---|
| Personal info — Name | Yes | No for Firebase acting as service provider | Account required; institution/staff fields feature-dependent | Authentication, profile, company setup, staff management, account management |
| Personal info — Email address | Yes | No for Firebase acting as service provider | Account required | Authentication, profile, recovery, company/staff contact, deletion verification |
| Personal info — User IDs | Yes | No for Firebase acting as service provider | Required | Firebase UID, institution membership, authorization, entitlement, deletion |
| Personal info — Address | Yes | No for Firebase acting as service provider | Optional | Institution address entered during company setup; treat as personal conservatively for sole traders |
| Personal info — Phone number | Yes | No for Firebase acting as service provider | Optional | Institution phone entered during company setup |
| Photos and videos — Photos | Yes, conservatively | No for Firebase acting as service provider | Optional | A Google-auth profile-photo URL may be stored with the account. Verify final Google/Firebase behavior in the release account. |
| Calendar — Calendar events | Yes on Android when Calendar is enabled | **Yes, conservatively** to Google Calendar | Optional | Reads the officer's primary-calendar event metadata and writes selected appointment title/time/notes. Use a user-initiated-transfer exception only if the final Console wording and flow demonstrably qualify. |
| User-generated content / other content | Yes only for Calendar-synced appointment notes and institution fields | **Yes, conservatively** for note text sent to Google Calendar | Optional | Optional Calendar event description and company configuration |
| Contacts | No | No | N/A | The OS returns one user-selected contact and the resulting customer fields remain on-device by default; Bookly does not transmit the address book. Revisit if customer sync is added. |
| App activity | No | No | N/A | Operational activity and Insights are local; no analytics SDK is present. |
| App info and performance / Diagnostics | No | No | N/A | Error logs are local and no remote crash-reporting SDK is present. |
| Audio | No | No | N/A | Public v1 does not record calls. |
| Financial info | No for reviewed v1 | No | N/A | No live payment collection is established. Re-audit before enabling billing. |
| Health and fitness | No | No | N/A | Regulated health information is prohibited, not a supported use case. |
| Files/documents, location, messages, web browsing, device identifiers | No based on reviewed source | No | N/A | No matching transmitted flow found. Re-check SDK-generated identifiers in the final bundle. |

Additional Play answers for the reviewed design:

- Data is encrypted in transit by the Firebase/Google HTTPS APIs.
- A deletion-request mechanism exists in source but cannot be answered as live
  until the callable and Hosting page are deployed and verified.
- Firebase should be treated as a service provider only after the applicable
  production terms are accepted and the relationship remains within the Play
  definition. Google Calendar is listed as shared conservatively because it is
  a user-facing third-party product/destination.
- Required versus optional must be set per data type as shown, not globally.

## Apple App Privacy Mapping

Use this for the first iOS release only. Google Sign-In and Google Calendar are
release-gated off on iOS, so Android Calendar flows are not part of the first
iOS nutrition label. Reconcile the answers in App Store Connect against the
final IPA and every embedded SDK.

| Apple data type | Collected? | Linked to identity? | Tracking? | Purpose |
|---|---:|---:|---:|---|
| Contact Info — Name | Yes | Yes | No | Account, company, and staff management |
| Contact Info — Email Address | Yes | Yes | No | Authentication, recovery, account/company/staff management |
| Contact Info — Physical Address | Yes when supplied for an institution | Yes | No | Company setup |
| Contact Info — Phone Number | Yes when supplied for an institution | Yes | No | Company setup |
| Identifiers — User ID | Yes | Yes | No | Firebase identity, membership, authorization, entitlement, deletion |
| Photos or Videos — Photos | Yes, conservatively, when an existing profile includes a Google profile-photo URL | Yes | No | Profile display; verify whether the final iOS account path can receive this field |
| Other User Content | Yes | Yes | No | Institution configuration stored in Firestore |
| Purchases / Financial Info | No for reviewed v1 | N/A | No | No live iOS billing/payment flow is established |
| Contacts | No | N/A | No | One OS-selected contact is processed and stored on-device only; no address book is uploaded |
| Usage Data / Diagnostics | No | N/A | No | No analytics or remote crash SDK; local logs do not leave the device |
| Sensitive Info / Health & Fitness / Audio / Location | No | N/A | No | Not collected in reviewed v1; health data is prohibited and call recording is disabled |

Apple “collected” generally concerns data transmitted off the device and
retained beyond servicing the request. The final App Store answers must also
include third-party SDK practices, even when Bookly does not directly inspect
the data.

## Privacy Policy Draft Content

The publication agent should turn this section into the final hosted policy
only after replacing both owner tokens, completing legal review, deploying the
deletion flow, and re-auditing the final binaries.

### Identity and contact

Bookly is provided by `[[OWNER_PUBLIC_LEGAL_NAME]]`, located at
`[[OWNER_PUBLIC_OR_REGISTERED_BUSINESS_ADDRESS]]`. Privacy requests may be sent
to `bookly.support@gmail.com`.

### Information Bookly handles

Bookly processes account and company information needed to authenticate users,
assign Owner or Officer permissions, operate an institution workspace, resolve
feature access, and handle account deletion. This can include a name, email
address, Firebase user identifier, optional profile image, role, institution
membership, company name and optional business contact details.

Customer records, appointments, services, locations, leave requests,
app-initiated call entries, and operational Insights are stored locally on the
device in v1 and are not synchronized to Bookly's Firestore backend. Users are
responsible for the security, backup, and lawful handling of local business and
customer data on their devices.

When a user chooses contact import, the operating system displays its own
single-contact picker. Bookly receives only the selected contact's display
name, first phone number, and first email address for form prefill. Bookly does
not request access to browse or upload the full address book.

On Android, a user may separately connect a Google account for Calendar. Bookly
can display event title, time, and organizer information from that user's
primary calendar. If the user explicitly enables sync for an appointment,
Bookly sends the customer's display name, appointment time, and selected
appointment-note text to Google as a Calendar event. Users should avoid placing
sensitive information in Calendar event titles or notes.

Bookly keeps error-level diagnostic logs locally on the device for up to seven
days. The reviewed v1 app contains no advertising, analytics, or remote crash-
reporting SDK.

### Purposes and lawful basis

Information is used to provide the requested app and account functionality,
secure and administer accounts, enforce institution permissions, support
users, comply with valid legal obligations, and protect Bookly and its users.
Depending on jurisdiction and context, processing is based on performance of a
contract, legitimate interests in secure service operation, consent for
optional integrations, and compliance with law.

### Sharing and processors

Bookly uses Google Firebase services for authentication, cloud account and
institution records, hosted deletion pages, and deletion processing. Google
acts under the applicable production service and data-processing terms. Google
Calendar receives and supplies event data only when an Android user connects
that service and uses the integration. Bookly does not sell personal data and
does not use it for cross-app advertising or tracking.

### Retention and deletion

Bookly does not intentionally retain deleted v1 account or institution data for
an additional business retention period. When the deployed deletion flow
successfully completes, Bookly deletes the covered Firebase account and cloud
records and clears covered local Bookly data at the next authenticated state
check on each affected device. Calendar events previously created in Google
Calendar remain controlled by the user's Google account and may need to be
deleted there.

Until deployment and multi-device verification are complete, this paragraph is
a target behavior and must not be published as an operational guarantee.

### Rights

Subject to applicable law, a person may request access to, correction of,
deletion of, or portability of personal data, and may object to or request
restriction of certain processing. Requests may be sent to
`bookly.support@gmail.com`. Bookly may need to verify the requester's identity.
Users may also update available profile/company details in the app, disconnect
Google access, delete Calendar events in Google Calendar, or use the deployed
account-deletion flow. A user may complain to the data-protection authority
available in their jurisdiction.

Before publication, Sri Lankan counsel must reconcile this voluntary
GDPR-baseline promise with the then-operative PDPA provisions, final DPA
instruments, response periods, appeal wording, and any permitted limitations.

### International processing, security, children, and changes

Because Bookly is offered worldwide and uses Google services, data may be
processed outside the user's country under the safeguards offered by the
applicable provider terms and law. Bookly uses access controls and encrypted
network connections, but no system can guarantee absolute security. Bookly is
not directed to children below the minimum digital-consent age applicable in
their jurisdiction. Material policy changes should be dated, published at the
same stable URL, and communicated when required.

## Terms of Service Draft Content

The final Terms must identify `[[OWNER_PUBLIC_LEGAL_NAME]]` and
`[[OWNER_PUBLIC_OR_REGISTERED_BUSINESS_ADDRESS]]`, state an effective date,
select governing law/dispute terms with legal advice, and be linked directly
from registration before acceptance language is used.

Minimum required clauses:

1. **Service and eligibility.** Bookly is an appointmenting and lightweight
   business-operations tool. Users must be legally capable of accepting the
   Terms and must supply accurate account/company information.
2. **Account security and roles.** Users are responsible for credentials,
   authorized staff, Owner/Officer assignment, activity under their accounts,
   and prompt notice of suspected compromise.
3. **Customer data responsibility.** The institution/user determines what
   customer and appointment information is entered and must have a lawful basis
   and any required notice or consent. Local data is device-resident in v1;
   users are responsible for device security and appropriate backups.
4. **No protected health information.** Bookly v1 is not a medical-record,
   clinical, emergency, or regulated-health-information service. Users must not
   enter diagnoses, treatment information, medical histories, test results,
   insurance information, or other protected health information into Bookly or
   Calendar notes. Bookly must not be relied upon for medical decisions or
   emergencies.
5. **Google integrations.** Android users may connect Google services. Their use
   is also governed by Google's terms. Calendar content sent to Google remains
   in the user's Google account until removed there; revoking Bookly access does
   not automatically erase previously created events.
6. **Acceptable use.** Prohibit unlawful activity, unauthorized access,
   malicious code, abuse, rights infringement, deceptive use, and attempts to
   bypass access controls or disrupt the service.
7. **Availability and changes.** Features may change or be suspended for
   security, maintenance, legal, or operational reasons. Do not promise an SLA
   that is not actually supported.
8. **Plans and billing.** The reviewed v1 has no live payment flow. Do not add
   payment, renewal, cancellation, or refund promises until a real billing
   system and store-compliant terms exist.
9. **Deletion and termination.** Explain user-requested deletion, sole-owner and
   live-subscription guards, institution-wide impact, local-device purge timing,
   and Bookly's right to suspend unlawful or harmful use. This must match the
   deployed Spec 03 behavior.
10. **Disclaimers, liability, indemnity, governing law, and disputes.** Obtain
    jurisdiction-specific legal drafting before worldwide publication; do not
    copy generic clauses without review.
11. **Contact and changes.** Use `bookly.support@gmail.com`, publish effective
    and update dates, and provide legally required notice of material changes.

## Code/App Compliance Checklist — Current Stage

- [x] Confirm no active customer/appointment backend synchronization.
- [x] Confirm Calendar is per connected officer/device and first-iOS-release
      Calendar UI is disabled.
- [x] Confirm dependency graph contains no ads, analytics, or remote crash SDK.
- [x] Keep native single-contact picker and remove broad Android/iOS contacts
      authorization from source.
- [x] Regress every app-source Android manifest and Dart source against broad
      contacts access, not only the current customer screen/main manifest.
- [x] Verify Spec 04 v3's January 1, 2027 date against Gazette No. 2498/16 and
      record the Gazette's exact scope without guessing Part II commencement.
- [ ] Validate the picker on physical Android and iOS devices with no broad
      contacts prompt.

## Deferred Publication and Operational Checklist

- [ ] Re-check Gazette notices, the amended Act, and final DPA instruments at
      publication time; do not treat the currently published DPO/breach/DPIA/
      rights drafts as binding final text.
- [ ] Receive owner legal name and public/registered address.
- [ ] Complete appropriate legal review for worldwide distribution and the
      Sri Lanka PDPA, including Part II commencement, controller/processor
      roles, DPO, DPIA, breach, data-subject requests, and cross-border flows.
- [ ] Create and retain the operational privacy records/runbooks identified in
      the Sri Lanka PDPA readiness section.
- [ ] Verify applicable Google data-processing terms are accepted.
- [ ] Deploy and verify Spec 03 Functions, email-link auth, and deletion page.
- [ ] Publish `/privacy/` and `/terms/` on Firebase Hosting with no tokens or
      placeholders.
- [ ] Replace Settings and registration legal placeholders/text with working
      links and record anonymous URL checks.
- [ ] Re-audit the exact AAB/IPA dependencies, permissions, network behavior,
      privacy manifests, and SDK disclosures.
- [ ] Enter and save Play Data Safety answers from the final Android mapping.
- [ ] Enter and save App Store Connect App Privacy answers from the final iOS
      mapping.
- [ ] Capture dated screenshots/exported console answers for release evidence.

## Official References Reviewed

- Google Play Data Safety guidance:
  <https://support.google.com/googleplay/android-developer/answer/10787469>
- Google Play account-deletion requirements:
  <https://support.google.com/googleplay/android-developer/answer/13327111>
- Apple App Privacy management:
  <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy>
- Google Calendar OAuth scopes:
  <https://developers.google.com/workspace/calendar/api/auth>
- Firebase privacy and security information:
  <https://firebase.google.com/support/privacy>
- Google Cloud/Firebase data-processing terms:
  <https://firebase.google.com/terms/data-processing-terms>
- Sri Lanka Extraordinary Gazette No. 2498/16 (July 22, 2026):
  <https://www.dpa.gov.lk/Gazet/2498-16_E.pdf>
- Sri Lanka Personal Data Protection (Amendment) Act, No. 22 of 2025:
  <https://www.dpa.gov.lk/acts/22-2025_E_251104_201549%20%281%29.pdf>
- Sri Lanka DPA downloads, including instruments currently labelled as drafts:
  <https://www.dpa.gov.lk/guidelines.php>
