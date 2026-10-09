# Domain docs

This repository is a single-context Flutter application inside a larger product
workspace. Before exploring or changing the app, follow the mandatory bootstrap
order in `../../AGENTS.md`. The authoritative product and domain documents are:

1. `../../../AGENTS.md`
2. `../../../CLAUDE.md`
3. `../../../ROADMAP.md`
4. `../../../product_requirements_document.md`
5. `../../../Concern_Tracking.md`
6. `../../../AUTH_REGISTRATION_RECOVERY_FLOW.md`
7. `../../../CURRENT_SCREEN_MANIFEST.md`
8. `../../CLAUDE.md`
9. `project-status.md`

If a root `CONTEXT.md` or `docs/adr/` directory is later added, read the
relevant files as well. Use the product documents' vocabulary in issues, tests,
hypotheses, and implementation notes. Surface conflicts with documented or
locked decisions instead of silently overriding them.

`project-status.md` is a dated operational snapshot. It may summarize the
documents above but never overrides their locked scope or engineering rules.
