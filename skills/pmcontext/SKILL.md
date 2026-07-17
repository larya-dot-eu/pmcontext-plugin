---
name: pmcontext
description: >
  Context for the pmcontext PM-Claude workflow plugin. Use this skill whenever
  any /pmcontext:* command is invoked, when explaining how the tiers or phase
  gates work, when the user asks which command to run next, or when helping
  someone set up or troubleshoot pmcontext. Also load this skill if the user
  references CONTEXT.md, PROJECT_BRIEF.md, ROADMAP.md, or the PM–Claude Workflow
  block in their project's CLAUDE.md — those files are all scaffolded by this plugin.
---

## What pmcontext is

A PM-Claude workflow plugin that brings structured planning and execution to any
codebase. It ships nine slash commands (`/pmcontext:*`) backed by a Supabase
database for session tracking and project state.

No application code — every command is a Markdown instruction file that Claude
reads and executes directly.

## The nine commands

| Command | Purpose |
|---------|---------|
| `/pmcontext:init` | One-time setup: connect Supabase, create tables, write `~/.pmcontext` |
| `/pmcontext:start` | Session orientation: scaffold missing files, load project context |
| `/pmcontext:quick` | Quick tier: blast-radius check then implement directly, no phases |
| `/pmcontext:plan` | Standard/full tier: Phases 1–5 planning → produces a plan file |
| `/pmcontext:execute` | Phases 6–9: TDD → implementation → review → living doc update |
| `/pmcontext:resume` | Continue the last paused or active session |
| `/pmcontext:deploy` | Pre-deploy gates against a running system, then deploy with a verified rollback target |
| `/pmcontext:close` | Write session receipt to Supabase, update pm_state |
| `/pmcontext:status` | Quick dashboard: open decisions, active risks, current session |

## Tier system

Choose the tier based on blast radius and complexity:

- **Quick** (`/pmcontext:quick`) — small, bounded changes. No plan file, no phase gates. Blast-radius check, then implement.
- **Standard** (`/pmcontext:plan`, then `/pmcontext:execute`) — most feature work. Phases 1–5 produce a Markdown plan; Phases 6–9 execute it with TDD and review.
- **Full** (`/pmcontext:plan --full`, then `/pmcontext:execute`) — high-risk or architectural changes. Same phases as standard but with HTML companion docs, SVG dependency graph, and full adversarial review with loop-back analysis.

## Phase flow

```
plan (Phases 1–5)          execute (Phases 6–9)
─────────────────          ────────────────────
1. Context priming    →    6. TDD planning
2. Codebase tour      →    7. Implementation
3. Spec writing       →    8. Post-impl review
4. Plan writing       →    9. Living doc update
5. Adversarial review
```

Phase gates are recorded in Supabase (`phase_gates` JSONB column) and enforced
in order — phases cannot be skipped.

## Bootstrap pattern (all commands)

Every command starts with:
1. `cat ~/.pmcontext` → reads `SUPABASE_PROJECT_ID` and `PLUGIN_DIR`
2. `git rev-parse --show-toplevel | xargs basename` → derives project name
3. Uses both in every Supabase MCP call

`PLUGIN_DIR` points to the plugin installation. Commands that scaffold files
(e.g., `start.md`) read templates from `$PLUGIN_DIR/templates/`.

## Required dependencies

All commands require:
- **Supabase MCP** — session and state persistence
- **`superpowers` skills** — `executing-plans`, `test-driven-development`, `writing-plans`, `brainstorming`, `requesting-code-review`, `verification-before-completion`, `using-git-worktrees`, `finishing-a-development-branch`

`/pmcontext:plan`, `/pmcontext:execute`, and `/pmcontext:resume` additionally require:
- **context7 MCP** — `plan` uses it in Phase 3 (Path A: fetch live docs for third-party interface types) and Phase 4 (codebase sync import scan); `execute` and `resume` use it as a confirmation pass when `Libraries touched` is non-empty

## Plan file convention

Plans live in `docs/superpowers/plans/` (gitignored). Every plan must end with
a `## Session Launch` section that includes `Tier:`, `Libraries touched:`,
`Mandatory context:`, and other execution metadata. `/pmcontext:execute` reads
`Tier:` to calibrate Phase 8 depth, `Libraries touched` to decide whether
context7 is needed, and `Mandatory context:` to load the spec file and any
additional type definition files at execution time.

## Communication tags

When pmcontext is active in a project, all messages use these tags so the PM
knows how to respond without reading code:

| Tag | Meaning |
|-----|---------|
| `[SURFACE]` | Visible behavior — PM can verify directly |
| `[CORE]` | Internal logic — PM trusts Claude's judgment |
| `[VERIFY]` | Needs PM confirmation before proceeding |
| `[CHECKPOINT]` | Phase gate reached — PM reviews before next phase |
| `[RISK]` | Risk identified — PM decides whether to accept |
| `[BLAST RADIUS]` | Scope of impact for a proposed change |
| `[REFACTOR]` | Internal cleanup, no behavior change |
| `[STEELMAN]` | Best-case argument for a contested approach |

## Scaffolded files

`/pmcontext:start` creates these files in the user's project if missing:

- `CONTEXT.md` — Node Model: Surface vs Core nodes, 7 lines
- `PROJECT_BRIEF.md` — generated from codebase tour (not a static template)
- `ROADMAP.md` — minimal starter, filled via brainstorming
- Block appended to `CLAUDE.md` — PM–Claude Workflow protocol and communication tags

`/pmcontext:plan` Phase 3 additionally reads:
- `$PLUGIN_DIR/templates/spec-skeleton.md` — skeleton template Claude copies and fills field-by-field when writing a spec (interfaces with Before/After signatures, edge cases table, out of scope, assumptions)
