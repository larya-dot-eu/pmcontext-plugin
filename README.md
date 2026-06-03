# pmcontext

Claude Code plugin for PM-Claude session management. Tracks open decisions, active risks, session receipts, and plan execution state in Supabase — across any project, on any machine.

## Requirements

- [Claude Code](https://claude.ai/code)
- Supabase MCP configured in Claude Code

## Recommended Setup

For the best pmcontext experience, especially for remote or multi-device development:

- **OS**: Ubuntu (Linux) — most reliable environment for Claude Code and MCP tooling
- **Remote access**: [Tailscale](https://tailscale.com) or [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) — lets you reach your dev machine from anywhere and review HTML spec/plan files in a browser on another device
- **Version control**: GitHub with Claude Code for seamless git integration
- **Companion plugins**: [`superpowers`](https://github.com/anthropics/claude-plugins-community), [`code-review`](https://github.com/anthropics/claude-plugins-community), [`context7`](https://github.com/upstash/context7)

## Install

```bash
claude plugin install pmcontext@community
```

Or directly from this repo:

```bash
claude plugin install --from-git github.com/larya-dot-eu/pmcontext-plugin
```

## First-Time Setup (once per machine)

After installing, run:

```
/pmcontext:init
```

This will:
1. List your Supabase projects and ask which one to use
2. Write `~/.pmcontext` with your Supabase project ID
3. Create the `pm_sessions` and `pm_state` tables

Safe to re-run — uses `CREATE TABLE IF NOT EXISTS`.

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
| `/pmcontext:close` | End of session — writes receipt to Supabase, updates project state |
| `/pmcontext:status` | Quick dashboard — decisions, risks, checkpoint, active session |

## How It Works

One Supabase project stores state for all your coding projects. The `project` column in both tables is derived from the git repo name at runtime — so `linkedin`, `myapp`, and `pmcontext` all share one database but stay isolated.

`~/.pmcontext` holds your Supabase project ID. On a new machine: install the plugin, run `/pmcontext:init`, done.

## Typical Workflow

```
/pmcontext:start              → orient the session, scaffold missing files

# Pick a tier based on task size:
/pmcontext:quick <description>  → small change: implement directly after blast-radius check
/pmcontext:plan                 → standard: all 9 phases, produces a plan file
/pmcontext:plan --full          → full: same + HTML companions + full adversarial review

/pmcontext:execute <plan>     → execute the plan with TDD and phase gate enforcement
/pmcontext:close              → write session receipt to Supabase
```

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
```

`/pmcontext:execute` reads this section automatically — no briefing prompt needed.

## Submitting to the Community Marketplace

```bash
claude plugin validate
```

Then open a PR at https://github.com/anthropics/claude-plugins-community
