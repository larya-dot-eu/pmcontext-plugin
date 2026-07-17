# pmcontext

A Claude Code plugin that transforms how you work with Claude — you become the Product Manager, Claude becomes your implementation engineer. Instead of prompting and hoping, you work through structured specs and plans, with explicit phase gates, blast-radius checks, and security reviews built into every session. Tracks open decisions, active risks, session receipts, and plan execution state in Supabase — across any project, on any machine.

**The core idea:** you verify that the right thing was built. Claude owns whether the code is correct. Every phase ends at a gate where Claude stops, reports in plain language, and waits for you — so you can judge the product without reading the diff.

Three things make that hold up in practice:

- **Every spec states its access rules and its scale**, per role and per resource, with a named number for traffic and growth. Blanks are rejected — "no boundaries" has to be written down as a decision, not left empty.
- **The plan gets attacked before it runs.** One pass hunts structural breakage, one attacks the access rules (what does a hostile client reach?), one attacks the scale numbers (what breaks first at 10× peak?).
- **Before shipping, the claims get tested against a running system.** `/pmcontext:deploy` replays your access rules as real HTTP requests — user B actually gets a 403 on user A's data, with the status code shown — rather than trusting the document that says they should.

## Requirements

- [Claude Code](https://claude.ai/code)
- A free [Supabase](https://supabase.com) account with one project
- Supabase MCP configured in Claude Code (see setup below)
- [`superpowers`](https://github.com/obra/superpowers) plugin — required for the planning and execution workflow (phase gates, TDD, code review)
- [`context7`](https://github.com/upstash/context7) MCP — required for Standard and Full tiers when any plan touches external libraries (Phase 3 interface type docs, Phase 4 import scan)

## Recommended Setup

For the best pmcontext experience, especially for remote or multi-device development:

- **OS**: Ubuntu (Linux) — most reliable environment for Claude Code and MCP tooling
- **Remote access**: [Tailscale](https://tailscale.com) or [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) — lets you reach your dev machine from anywhere and review HTML spec/plan files in a browser on another device
- **Version control**: GitHub with Claude Code for seamless git integration
- **`/code-review` command** — built into Claude Code, used during Phase 8 post-implementation review to check the diff for correctness bugs and regressions

## Supabase MCP Setup (one-time)

pmcontext uses Supabase to track sessions across projects and machines. You need a free Supabase account and the Supabase MCP configured in Claude Code.

**1. Create a Supabase project**

Sign up at [supabase.com](https://supabase.com) (free tier is enough). Create a new project and note the project name — you'll select it during `/pmcontext:init`.

**2. Add Supabase MCP to Claude Code**

In your Claude Code MCP settings (`~/.claude/settings.json` or via `/config`), add the Supabase MCP server. The easiest way is through the Claude Code MCP marketplace:

```
/mcp add supabase
```

Follow the prompts to authenticate your Supabase account. This is a one-time step per machine.

**What gets stored:** `pm_sessions` records files changed, commands run, and manual checks per session. `pm_state` tracks open decisions and active risks per project. All data lives in your own Supabase project — you control access.

---

## Install

Add this repo as a marketplace, then install from it:

```bash
claude plugin marketplace add larya-dot-eu/pmcontext-plugin
claude plugin install pmcontext@pmcontext-plugin
```

Restart Claude Code to register the commands.

## Updating

```bash
claude plugin marketplace update pmcontext-plugin   # refresh the cached manifest
claude plugin update pmcontext@pmcontext-plugin     # then the plugin itself
```

Restart to apply. Use the fully-qualified `pmcontext@pmcontext-plugin` — a bare `pmcontext` reports "Plugin not found". The marketplace manifest is cached separately from the plugin, so refresh it first or the update finds nothing new.

The next `/pmcontext:start` after an update will tell you if the workflow block in your project's `CLAUDE.md` is behind the version the plugin now ships, and offer to upgrade it. It always asks first and writes `CLAUDE.md.bak` before touching anything.

## First-Time Setup (once per machine)

After installing, run:

```
/pmcontext:init
```

This will:
1. List your Supabase projects and ask which one to use
2. Write `~/.pmcontext` with your Supabase project ID and the plugin's install path
3. Create the `pm_sessions` and `pm_state` tables
4. Add the PM–Claude workflow block to your project's `CLAUDE.md`

Safe to re-run — uses `CREATE TABLE IF NOT EXISTS`, and it never overwrites an existing workflow block.

Every command reads `~/.pmcontext` first. If it's missing, they all stop with `[BLOCKED] pmcontext is not configured` — run `/pmcontext:init`.

## Commands

| Command | What it does |
|---------|-------------|
| `/pmcontext:init` | One-time setup — connects Supabase, creates tables, writes `~/.pmcontext` |
| `/pmcontext:start` | Start of session — scaffolds missing files, loads project context, surfaces decisions/risks |
| `/pmcontext:quick <description>` | Quick tier — blast-radius check then implement directly, no planning phases |
| `/pmcontext:plan` | Standard tier — all 9 phases, produces a plan file ready for `/pmcontext:execute` |
| `/pmcontext:plan --full` | Full tier — same as above with HTML companions and full adversarial review |
| `/pmcontext:execute <plan>` | Executes a plan file end-to-end with TDD, phase gate enforcement, and task tracking |
| `/pmcontext:resume` | Continues the last paused or active session from where it left off |
| `/pmcontext:deploy` | Pre-deploy gates against a running system — proves the artifact builds and boots, replays the access-control matrix as real requests, checks operational readiness, then deploys with a verified rollback target. `--gate-only` reports without deploying |
| `/pmcontext:close` | End of session — writes receipt to Supabase, updates project state |
| `/pmcontext:status` | Quick dashboard — decisions, risks, checkpoint, active session |

## How It Works

One Supabase project stores state for all your coding projects. The `project` column in both tables is derived from the git repo name at runtime — so `myapp`, `my-site`, and `pmcontext` all share one database but stay isolated.

`~/.pmcontext` holds your Supabase project ID and the plugin's install path. On a new machine: install the plugin, run `/pmcontext:init`, done.

### What it writes into your project

| File | Who owns it |
|------|-------------|
| `CLAUDE.md` | Yours. The plugin appends one **PM–Claude Workflow** block between `<!-- pmcontext:block-start -->` markers, and Phase 9 maintains the access-control and scale tables inside it. Everything outside the markers is untouched — put your own notes there. |
| `CONTEXT.md` | Scaffolded once — the Node Model (Surface vs Core nodes). |
| `ROADMAP.md` | Scaffolded once, filled by brainstorming. |
| `PROJECT_BRIEF.md` | Generated by the first-run codebase tour. |
| `docs/superpowers/specs/`, `docs/superpowers/plans/` | Specs and plans. Gitignored. |

The workflow block is versioned. When the plugin ships a newer one, `/pmcontext:start` says so and offers to upgrade — always asking first, always backing up to `CLAUDE.md.bak`, and rewriting only the text between the markers.

## Typical Workflow

The plugin divides responsibility clearly: you verify that the product behaves correctly — that the right thing was built; Claude owns that the code is correct, clean, safe, and functional. Every session is bookended by `start` and `close`. Everything in between depends on how big the task is.

---

### 1. Begin every session

```
/pmcontext:start
```

Always run this first. It reads your mandatory context set (CLAUDE.md, CONTEXT.md, ROADMAP.md) and emits a `[CONTEXT LOADED]` banner confirming what was found, surfaces any open decisions or active risks from previous sessions, and scaffolds missing files if it's the first time in this project. It also tells you if there's a paused session waiting to be resumed.

---

### 2. Pick a tier

The most important decision is matching the process to the task. Too much process wastes time; too little causes bugs and rework.

**Quick — for small, obvious changes**

Use when: bug fix, rename, config tweak, adding a test, one-file change with no design decisions.

```
/pmcontext:quick fix the null check in auth/validate.ts
```

Claude checks the blast radius (what else could this touch?), asks you to confirm, then implements directly. No planning phases. Done in minutes.

**Standard — for new functionality that follows existing patterns**

Use when: new endpoint, new component, refactoring a module, anything touching 3–10 files where the approach is already established in the codebase.

```
/pmcontext:plan
/pmcontext:execute docs/superpowers/plans/2026-06-03-my-feature-plan.md
```

Claude runs all 9 phases — context priming, exploration, spec, plan, adversarial review, TDD, implementation, review, living doc update. Each phase ends with an explicit gate: Claude stops, reports findings, and waits for your approval before proceeding. You cannot skip a gate. Outputs are markdown only.

Phase 3 (spec) uses a structured skeleton — Claude identifies affected files and reads them before writing a word, then fills every field: interfaces with exact Before/After signatures, an edge cases table, out of scope, assumptions, plus two sections worth knowing about:

- **Access-Control Matrix** — one row per role × resource: what it can read, what it can write, the ownership key that scopes it to its own rows, and where the check actually runs (a database policy beats app code, and app-code-only is recorded as a finding). Also: if a token is stolen right now, how is it revoked? Read this table as a product question — *should an anonymous visitor really be able to do that?*
- **Expected Scale** — peak traffic, hot-table rows now and in a year, what grows without limit, which queries need an index. Every row needs a number, marked `measured` or `assumed`. "Unknown" is not accepted; a guess written down can be argued with.

Phase 4 (plan) opens with a codebase sync table mapping every file the plan touches to its current line count and key symbols. Every code-modifying step includes a `Verify:` block with an exact command and expected output — not "tests pass".

Phase 5 (adversarial review) is three passes: structural, then security abuse against the matrix (IDOR, unauthenticated routes, ownership taken from the request body instead of the session), then load against the scale numbers. Claude must name what breaks first at 10× peak — no name means the pass didn't happen.

Phase 9 folds the matrix and scale tables into your project's `CLAUDE.md` as one cumulative, project-wide record. If a feature changes access that already exists, that collision surfaces as a `[RISK]` for you to rule on instead of being quietly overwritten.

**Full — for architectural changes, new subsystems, or anything risky**

Use when: new infrastructure, novel approach, touching core systems, high blast radius, or anything where getting the design wrong would be expensive.

```
/pmcontext:plan --full
/pmcontext:execute docs/superpowers/plans/2026-06-03-my-feature-plan.md
```

Same 9 phases as Standard, but Phase 3 (spec) and Phase 4 (plan) also produce HTML visual companions you can open in a browser to review. Phase 5 (adversarial review) runs the full loop-back analysis — Claude may return to an earlier phase if it finds structural problems. Phase 8 (post-implementation) invokes an external code review skill.

**Not sure which tier?**
- 1–2 files, known pattern → Quick
- 3–10 files, mostly known → Standard
- Many files, novel approach, or touches core infrastructure → Full

---

### 3. During a Standard or Full session

`/pmcontext:plan` and `/pmcontext:execute` run as separate sessions. Plan first, review the output, then execute. Between the two commands, you have a plan file in `docs/superpowers/plans/` you can inspect before committing to implementation.

During execution, Claude creates tasks for each phase and each implementation step — visible in your terminal. Phase tasks look like `[Phase 7] Implementation`. Step tasks look like `[Ph.7 · 3/8] Add JWT validation` so you always know where you are within a phase.

If a session gets interrupted mid-execution:

```
/pmcontext:resume
```

This picks up from where execution stopped — mid-step, or at the start of Phase 8 or 9 if Phase 7 was already complete.

---

### 4. Before shipping to production

```
/pmcontext:deploy
```

Not a phase — run it whenever you're about to ship, from any tier including Quick. Every other phase reads documents; this one runs the system. Three gates:

| Gate | What it proves |
|------|----------------|
| **A — Artifact** | Builds clean from scratch, boots, health responds, nothing uncommitted, no secrets inside the build output |
| **B — Security** | Each row of your access-control matrix replayed as **real requests** — authenticate as user A, create a row, then try to read/update/delete it as user B. Plus unauthenticated access, role separation, server-side validation, string-built SQL, cookie flags, CORS, rate limiting, error hygiene |
| **C — Operational** | `EXPLAIN` on the queries your scale table marked hot, survives a restart, survives a second replica, growth is bounded, monitoring exists |

Then it names a verified rollback target and reports PASS/FAIL. **It stops there and asks before touching production.** On your approval: deploy → confirm health → re-check auth *against production* → watch → and only then merge, tag, and announce. Irreversible steps come last, after prod is confirmed healthy. If anything fails, it rolls back first and diagnoses second.

```
/pmcontext:deploy --gate-only
```

Runs every gate and the report, then stops. Nothing outside your machine is touched.

Two rules worth knowing. A check that can't run is reported as `N/A` with a reason — never a silent pass, so read the `N/A CHECKS` list. And if Gate B disagrees with your access-control matrix, **the gate is right and the matrix is wrong**: a 200 where the matrix promised `own only` is a live vulnerability, not a documentation nit.

Projects with no HTTP surface (a library, a CLI) are detected and most of Gate B and C report `N/A` — Gate A still applies.

---

### 5. End every session

```
/pmcontext:close
```

Always run this last, even if nothing was implemented. It writes the session receipt to Supabase — files changed, commands run, risky assumptions, and manual checks for you to review. This is what makes state available across machines and sessions.

---

### At any point

```
/pmcontext:status
```

Shows the current session state: open decisions, active risks, last checkpoint, and any paused session waiting to be resumed.

## Plan Files

Plans are created by `/pmcontext:plan` and saved to `docs/superpowers/plans/` (gitignored). Each plan must include a `## Session Launch` section at the end:

```markdown
## Session Launch

Tier:
What this builds:
Codebase state going in:
Files the plan touches:
Libraries touched:
Key design decisions:
Gotchas:
Start here:
End here:
Mandatory context:
```

`/pmcontext:execute` reads this section automatically — no briefing prompt needed. `Mandatory context:` lists the spec file path and any additional type definition files to load at execution time — write `—` if none beyond the static tier.

## Submitting to the Community Marketplace

```bash
claude plugin validate
```

Then submit via the in-app form:
- Claude.ai: `claude.ai/settings/plugins/submit`
- Console: `platform.claude.com/plugins/submit`
