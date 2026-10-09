# AGENTS.md

This Flutter repository is the executable app inside a larger product workspace.
When this directory is opened directly in VS Code, Codex treats it as the
project root and does not automatically discover instructions or product
documentation stored in the parent directory.

## Mandatory Context Bootstrap

Before inspecting code, planning work, diagnosing problems, or editing files,
read these documents in order:

1. `../AGENTS.md` — authoritative engineering rules and locked decisions
2. `../CLAUDE.md` — full workspace architecture and implementation context
3. `../ROADMAP.md` — MVP baseline, release priorities, and future journey
4. `../product_requirements_document.md` — product scope and feature inventory
5. `../Concern_Tracking.md` — active/historical defects and reusable fixes
6. `../AUTH_REGISTRATION_RECOVERY_FLOW.md` — required auth/profile failure and recovery behavior
7. `../CURRENT_SCREEN_MANIFEST.md` — current screens, routes, and behavior
8. `CLAUDE.md` — app-local architecture, commands, and key files
9. `docs/agents/project-status.md` — dated working-tree, validation, and release-readiness snapshot
10. `docs/agents/store-compliance-watchlist.md` — persistent Spec 01–05 gates and reminder triggers

The parent `../AGENTS.md` is the source of truth and all of its rules apply to
work in this repository. If a required parent document cannot be accessed,
report that before making changes rather than guessing project conventions.

The status snapshot is descriptive, not authoritative over the locked product
decisions above it. Refresh it when a material feature, blocker, validation
result, or release-readiness condition changes.

The compliance watchlist is an active release gate, not background reading.
Raise the matching open items whenever a task touches authentication, account
deletion, permissions, SDKs, data flows, CI/signing, legal pages, store forms,
or release preparation. Never report a compliance spec complete merely because
its source code or local tests pass; preserve the distinction between
implemented, deployed, console-configured, and device/end-to-end verified.

## Theme-Aware Widget Colors (Critical)

For every new or modified screen, widget, or component, follow the authoritative
`Theme-Aware Widget Colors (CRITICAL)` rule in `../AGENTS.md`. In feature UI,
read semantic colors from `Theme.of(context).colorScheme`; do not use
`AppColors.*`, raw `Color(0x...)`, or `Colors.*` for themeable surfaces, text,
icons, borders, shadows, state layers, or gradients. Any intentional invariant
color requires an inline reason and contrast verification across all presets
and light/dark mode.

## Working Directory

Run Flutter and Dart commands from this directory (`Mobile Appointmenting`),
where `pubspec.yaml` lives. Do not run Flutter tooling from the parent product
workspace.

## Documentation Synchronization

When a change affects product scope, roadmap status, architecture, known
concerns, or screen behavior, update the relevant parent document in the same
task. In particular, any screen addition, removal, or modification must update
`../CURRENT_SCREEN_MANIFEST.md`.

## Hive Schema Evolution

When appending a field to an existing `@HiveType`, preserve every prior field
index and declare an explicit `defaultValue` matching the field's empty state.
Regenerate the adapter, verify its reader handles an absent field, and add a
regression that reads bytes written with the previous field set. Avoid null
assertions when reading any field introduced after the type entered use.
