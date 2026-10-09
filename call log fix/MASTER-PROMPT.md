# Master Prompt — Bookly Store-Compliance Remediation

Paste everything below this line into the coding agent's session (Claude Code or equivalent) with
the Bookly repo open. It assumes all 6 files are present in the repo (suggested location:
`docs/compliance/`) alongside the existing `bookly-flutter-conventions` skill.

---

You are implementing store-compliance fixes for Bookly, a Flutter appointment-booking app, ahead of
its first public Google Play and App Store submission. Six documents govern this work:

- `00-store-compliance-ground-rules.md` — permanent rules for this project, not just this task.
  Everything you do, on this task and every future one, must follow this document. Read it first
  and keep it loaded for the rest of the session.
- `01-recording-and-call-log-release-gate.md`
- `01a-call-activity-dial-intent.md` — implement together with 01, not separately; it replaces 01's
  original "hide the Calls tab" plan with a populated, store-compliant Calls tab.
- `02-ios-release-baseline.md`
- `03-auth-parity-and-account-deletion.md`
- `04-privacy-policy-and-store-data-mapping.md`
- `05-store-release-engineering-checklist.md`

Also load the existing `bookly-flutter-conventions` skill for this project before touching any
code — it documents real traps in this codebase (parallel call-log systems, an exact-match phone
bug, mixed architecture by feature) that are easy to reintroduce if you don't check for them first.

## Execution order

Work through the specs in this order — later ones assume earlier ones are done:

1. **Spec 01, together with Spec 01a**, first, always. 01 disables the highest-risk behavior (auto
   call recording, `READ_CALL_LOG`); 01a replaces the resulting gap with a store-compliant,
   populated Calls tab powered by app-initiated call activity instead of the system call log. Every
   other spec's data-inventory/UI assumptions depend on both being done together.
2. **Spec 02** (iOS baseline) next — independent of 03/04/05, but do it before 03's iOS-login-parity
   work so you're not reconfiguring the same iOS build twice.
3. **Spec 03** (auth parity + account deletion) — the account-deletion backend work here is the
   largest single piece; don't compress it to fit a deadline.
4. **Spec 04** (privacy policy + data mapping) — do this *after* 01–03 so the data inventory
   reflects final behavior instead of needing a rewrite.
5. **Spec 05** (release engineering) last — it's the final pre-submission pass and re-checks work
   from all the specs before it.

## Rules for how you work through each spec

- **Read the whole spec before writing any code.** Each one has Confirmed Facts, Discovery Steps,
  Functional Requirements, Explicitly Out of Scope, a File-by-File Task List, Testing Requirements,
  Acceptance Criteria, and Open Questions — in that order for a reason.
- **Do the Discovery Steps for real, before implementing.** They exist because the original gap
  analysis was written without full repo access — some of what's in "Confirmed Facts" may have
  shifted since. If discovery contradicts a Confirmed Fact, trust discovery and flag the
  discrepancy back to me; don't silently proceed on the stale assumption.
- **Stop at every Open Question.** Do not invent legal/business facts (entity name, address,
  support email, target countries, retention periods, subscription/refund policy) or make a
  product decision that a spec flagged as needing owner input. Surface the question and wait.
- **Respect Explicitly Out of Scope.** If you notice a related improvement while working, note it
  for later rather than expanding the current change — each spec was scoped deliberately.
- **Run the Testing Requirements before you call a spec done.** Acceptance Criteria are checkboxes
  I'll expect to see actually verified, not assumed.
- **Apply the ground-rules doc continuously**, not just as a one-time reference. If implementing a
  spec surfaces a new permission, new data field, new SDK, or new background process not already
  covered by that spec, run it through the relevant ground-rules checklist before proceeding, and
  raise it as a new item if it triggers a "stop and ask."

## What to report back to me

After each spec:
- A short summary of what changed (file-by-file is fine).
- Confirmation of which Acceptance Criteria passed, and how you verified each one.
- Any Open Questions from that spec that are still unanswered, listed explicitly — don't bury them
  in prose.
- Any new stop-and-ask trigger you hit that wasn't anticipated in the spec.

After all five specs are done:
- Re-run the Spec 05 / ground-rules §7 release checklist as a final pass, since later specs can
  invalidate earlier checks (e.g. Spec 03's new backend function needs to be reflected in Spec 04's
  data mapping if you didn't already account for it).
- A single consolidated list of every remaining Open Question across all specs, since some (legal
  entity info, target countries, retention periods) repeat across documents and only need to be
  answered once.

## Hard stop

If at any point completing a task would require guessing at something in §1 or §8 of the
ground-rules document (permission scope expansion, new data collection, new sharing with a third
party, re-enabling a gated feature, expanding to a new country, or any undocumented legal/business
fact), stop and ask me directly rather than proceeding on an assumption.
