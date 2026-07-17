# Changelog

All notable changes to the pmcontext plugin are documented here.

---

## [1.2.3] — 2026-07-17

### Fixed
- `init.md` now verifies `CLAUDE.md.example` is present alongside the other templates. It was checking three of the four and omitting the one it depends on at Step 5 — had it been missing, the workflow block would have silently failed to install with no warning.

---

## [1.2.2] — 2026-07-17

### Added
- `check-release.sh` — release check asserting that what ships matches what's documented: every documented command resolves to a real file, every command is in the README, `marketplace.json`'s pin covers all shipped files and exists on the remote, and the version has a CHANGELOG entry. Run before a release. It is not a plugin surface — only `commands/`, `templates/`, and `skills/` are loaded by Claude Code — so it never registers as a command or runs for users, though it is present in the repo like `LICENSE` and this file.

---

## [1.2.1] — 2026-07-17

### Fixed
- Command registration — commands now resolve as documented.

---

## [1.2.0] — 2026-07-17

### Added
- **Versioned workflow block.** `templates/CLAUDE.md.example` is now delimited by `<!-- pmcontext:block-start vN -->` / `<!-- pmcontext:block-end vN -->` markers. `/pmcontext:start` compares the version installed in the project's `CLAUDE.md` against the version the plugin ships and offers an upgrade when they differ. The shipped version is read from the template itself — there is no constant to forget to bump.

### Fixed
- **The workflow block no longer goes stale forever.** `init` and `start` previously grepped for `## PM–Claude Workflow` and skipped if present, so the block was written once at first install and never updated again. Every user who upgraded the plugin kept their original block — meaning that as of 1.1.0, existing users had the working `/pmcontext:deploy` command but a `CLAUDE.md` that never mentioned it, still said eight commands, and described the pre-1.1.0 Phase 3/5/9 gates. The block is the PM's description of their own job at each gate, so a stale one means the human follows instructions the commands no longer match.

### Notes
- **Upgrades are offered, never silent.** Claude states what the block is missing, in PM language, and asks. `CLAUDE.md.bak` is written first. Only the text between the markers is rewritten, **in place** — content before and after keeps its original position.
- **Legacy blocks** (installed before versioning) have no markers, so the end of the block cannot be located reliably. If nothing follows the block, it is replaced from its heading to end of file — how `init`/`start` originally appended it. If any content follows it, the boundary is ambiguous and the upgrade is **refused** with manual instructions rather than guessed at.
- `init` never rewrites an existing block; keeping it current is `start`'s job.

---

## [1.1.0] — 2026-07-17

### Added
- **`/pmcontext:deploy`** — new command (the ninth). Runs pre-deploy gates against a real running system rather than against documents: **Gate A** artifact (clean build, boots, health responds, nothing uncommitted, no secrets in the build output), **Gate B** security (each `(Role, Resource)` row of the access-control matrix replayed as real requests — unauthenticated access, IDOR replay, role separation, owner-from-session, input validation, string-built SQL, cookie flags, CORS, rate limiting, error hygiene), **Gate C** operational (`EXPLAIN` on hot queries, restart survival, second replica, bounded growth, monitoring, backpressure). Then verifies a rollback target, reports PASS/FAIL to the PM, and **stops for explicit confirmation before touching production**. On approval: deploy → confirm health → re-check auth against prod → watch → merge/tag/announce last. `--gate-only` runs the gates without deploying. Rollback-first-diagnose-second on any failure.
- **Access-Control Matrix** — required spec section, keyed on `(Role, Resource)`: read, create/modify/delete, ownership key, and where enforcement actually runs. Includes a token-revocation question. Blanks are rejected; "no boundaries" must be written explicitly with a reason.
- **Expected Scale** — required spec section: peak traffic, hot-table rows now → 1 year, unbounded growth, hot queries needing indexes, big scans/joins, state location. Every row needs a named number marked `measured` or `assumed`.
- **Phase 5 Pass B (security abuse) and Pass C (load)** — the adversarial review is now three passes. Pass B attacks the plan against the access-control matrix; Pass C attacks it against the expected-scale numbers ("what breaks first at 10× peak"). Both run on standard and full tiers; tier changes depth, not whether they run. Findings are recorded in `phase_gates` as `abuse_pass` / `load_pass`.

### Changed
- **Phase 9** now merges the access-control and expected-scale tables into the project's `CLAUDE.md` as project-wide cumulative tables, merged on the `(Role, Resource)` pair. A collision on an existing pair is a boundary change and is surfaced as `[RISK]` rather than silently overwritten. Rows are reconciled against the code that enforces them — where spec and code disagree, the code wins.
- **Phase 3** now reads the existing access-control table before writing, so a boundary change surfaces at spec time instead of at Phase 9.
- `templates/CLAUDE.md.example` — new Deploy Gates section; Phase 3/5/9 gate rows updated to describe the PM's job for the new passes. *(Note: existing installs keep their original block — the workflow block is written once and not yet migrated.)*

### Notes
- **No schema migration required.** Deploy records are written into the existing `phase_gates` JSONB rather than a new column or a new `session_type` value — `session_type` has a CHECK constraint that `CREATE TABLE IF NOT EXISTS` cannot amend on already-configured installs. Existing users update and run `/pmcontext:deploy` against their current tables with no database work.

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
