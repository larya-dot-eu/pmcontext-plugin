# pmcontext

Claude Code plugin for PM-Claude session management. Tracks open decisions, active risks, session receipts, and plan execution state in Supabase — across any project, on any machine.

## Requirements

- [Claude Code](https://claude.ai/code)
- Supabase MCP configured in Claude Code

## Install

```bash
claude plugin install pmcontext@community
```

Or directly from this repo:

```bash
claude plugin install --from-git github.com/YOUR_USERNAME/pmcontext-plugin
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
| `/pmcontext:start` | Start of session — loads ROADMAP, surfaces open decisions/risks, suggests next action |
| `/pmcontext:execute <plan>` | Executes a plan file end-to-end with TDD, task tracking, and code review |
| `/pmcontext:resume` | Continues the last paused or active session with no arguments |
| `/pmcontext:close` | End of session — writes receipt to Supabase, updates project state |
| `/pmcontext:status` | Quick dashboard — decisions, risks, checkpoint, active session |

## How It Works

One Supabase project stores state for all your coding projects. The `project` column in both tables is derived from the git repo name at runtime — so `linkedin`, `myapp`, and `pmcontext` all share one database but stay isolated.

`~/.pmcontext` holds your Supabase project ID. On a new machine: install the plugin, run `/pmcontext:init`, done.

## Plan Files

Plans written with the `superpowers:writing-plans` skill should include a `## Session Launch` section at the end:

```markdown
## Session Launch

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
