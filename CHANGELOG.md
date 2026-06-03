# Changelog

All notable changes to the pmcontext plugin are documented here.

---

## [1.0.7] — 2026-06-03

### Fixed
- `superpowers` link in README corrected to `github.com/obra/superpowers`.
- `context7` and `superpowers` moved from Recommended Setup to Requirements in README — both are required dependencies, not optional recommendations.
- `code-review` correctly described as a built-in Claude Code command (`/code-review`) rather than a companion plugin requiring separate installation.

---

## [1.0.6] — 2026-06-03

### Fixed
- `execute.md` Step 3 extraction list now includes `Mandatory context:` — previously Step 2 referenced it as "already parsed in Step 3" but Step 3 never extracted it, causing a silent no-op.
- `templates/CLAUDE.md.example` Phase 3 and Phase 4 gate descriptions updated to reflect skeleton-based spec workflow, self-review checklist, codebase sync table, Verify blocks, and 6 checkpoint questions.

### Added
- `templates/CLAUDE.md.example` now documents: `[CONTEXT LOADED]` banner in the Prerequisites gate row, context7 requirement note before the Phase Gates table, and explicit `[CONTEXT7]`/`[KNOWN]` tag examples in the Phase 3 gate row so PMs know what to look for when reviewing specs.
- `skills/pmcontext/SKILL.md` updated: context7 dependency now covers `plan` (Phase 3 Path A, Phase 4 import scan) in addition to `execute` and `resume`; Session Launch convention documents `Mandatory context:` field; Scaffolded files section documents `spec-skeleton.md`.
- `commands/pmcontext/init.md` template check now includes `spec-skeleton.md`.
- `docs/` added to `.gitignore` — superpowers plans, specs, and related files stay local.

---

## [1.0.5] — 2026-06-03

### Added
- **Mandatory context set** across all five pmcontext commands. Every command now runs explicit file checks (CLAUDE.md, CONTEXT.md, ROADMAP.md) at session start and emits a `[CONTEXT LOADED]` banner confirming what was read. Closes spec gap failures A1 and A4.
- **`templates/spec-skeleton.md`** — new skeleton template for Phase 3 spec writing, covering Interfaces (with Before/After signatures), Edge Cases & Error States table, Out of Scope, and Assumptions.
- **Skeleton-first Phase 3 workflow** in `/pmcontext:plan`. Claude now identifies affected files and reads them before writing a spec, fills the skeleton field-by-field (no freeform prose), enforces Path A/B annotation for third-party library types, and runs a self-review checklist before the exit gate. Closes spec gap failures A1 and A2.
- **Codebase sync table** in Phase 4 of `/pmcontext:plan`. Before writing any plan step, Claude reads every file from the spec's Interfaces section, extracts third-party imports, and writes a sync table into the plan. Every symbol in a code snippet must appear in this table.
- **Per-step `Verify:` blocks** required for every code-modifying plan step. Each block specifies an exact command, expected output, and failure diagnosis — not "tests pass". Closes plan gap failure B2.
- **`Mandatory context:` field** in the Session Launch template and in `/pmcontext:execute` Step 3 extraction list. Lists the spec file and any additional type definition files to load at execution time. Closes plan gap failure B3.
- **Phase 4 Transition Checkpoint** extended from 4 to 6 questions, adding: "Does the codebase sync table cover every file the plan touches?" and "Does every code-modifying step have a Verify: block with exact expected output?"
- **Phase 4 exit gate SQL** extended with `codebase_sync_complete` and `all_steps_verified` fields.
- **Phase 3 exit gate SQL** extended with `sections_complete` (interfaces, edge cases, out of scope, assumptions) and `self_review_passed` fields.

### Changed
- `quick.md` Step 1 renamed from "Load Context" to "Load Mandatory Context Set" — now checks and reads CONTEXT.md and ROADMAP.md in addition to CLAUDE.md, and outputs the `[CONTEXT LOADED]` banner.
- `start.md` Load Context section gains an explicit Step 0 (read CLAUDE.md) and a `[CONTEXT LOADED]` banner after Steps 0–3.
- `resume.md` "Load Project Context" replaced with "Load Mandatory Context Set" — adds CLAUDE.md, ROADMAP.md checks, feature-specific tier (reads `Mandatory context:` field from Session Launch), and `[CONTEXT LOADED]` banner.
- `execute.md` Step 2 "Load Project Context" replaced with "Load Mandatory Context Set" — adds CLAUDE.md, ROADMAP.md checks, pm_state query, feature-specific tier, context7 confirmation pass, and `[CONTEXT LOADED]` banner.
- `plan.md` "Load Project Context" replaced with "Load Mandatory Context Set" — adds `[CONTEXT LOADED]` banner and "Missing files: warn and continue" behaviour.
- `templates/CLAUDE.md.example` Phase Gates table updated: Phase 3 description now references the skeleton-based workflow and gives PMs concrete rejection criteria; Phase 4 description updated to reference codebase sync table, Verify blocks, and 6 checkpoint questions.

---

## [1.0.4] — 2026-06-03

### Added
- MIT license.

### Changed
- Clarified plugin purpose and PM/Claude responsibility split in README and docs.

---

## [1.0.3] — 2026-06-02

### Fixed
- `PLUGIN_DIR` discovery no longer exits with code 1 when directory is absent.

### Changed
- Sanitised project name derivation (strips non-alphanumeric characters).
- Improved new-user setup documentation.

---

## [1.0.2] — 2026-06-02

### Added
- `skills/pmcontext/SKILL.md` — plugin context shipped as a skill for agentic workers.
- Expanded Typical Workflow section in README with when/why/how guidance per tier.

---

## [1.0.1] — 2026-06-02

### Fixed
- `resume.md` — tier-aware Phase 8/9 handling and phase gate checks corrected.
- Stale CONTEXT.md references and plugin.json description updated.
- PM–Claude roles section restored to CONTEXT.md after accidental removal.

### Changed
- CONTEXT.md split: Node Model only — codebase tour instructions moved into `start.md`.
- Phase gates documentation clarified: applies to standard and full tiers only.

---

## [1.0.0] — 2026-06-01

### Added
- Initial release: six commands (`init`, `start`, `quick`, `plan`, `execute`, `resume`, `close`, `status`), Supabase-backed session state, tiered workflow (quick / standard / full), and phase gate enforcement via Supabase JSONB.
