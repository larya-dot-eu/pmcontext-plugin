---
description: Orient session — load project state, surface decisions/risks, suggest next action
---

## Config

Read the Supabase project ID:
- Run `cat ~/.pmcontext 2>/dev/null` via Bash tool
- Extract the value after `SUPABASE_PROJECT_ID=` (trim whitespace)
- If the file is missing or the value is blank, output and stop:
  ```
  [BLOCKED] pmcontext is not configured.
  Run /pmcontext:init to complete setup.
  ```
- Use this value as `<PROJECT_ID>` for the `project_id` parameter in all MCP tool calls below.

Detect the current project name:
- Run `git rev-parse --show-toplevel` via Bash tool, then take the basename.
- If not in a git repo, use the basename of the current working directory.
- Use this value as `<project>` in SQL WHERE clauses below.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: if unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:start requires Supabase MCP
  ```

**Recommended — warn and continue if missing:**
- `superpowers:brainstorming`:
  `[WARN] superpowers:brainstorming not found — brainstorming workflow unavailable`
- `superpowers:writing-plans`:
  `[WARN] superpowers:writing-plans not found — plan writing workflow unavailable`

## Load Context

**Step 1 — Read ROADMAP.md:**
Look for `ROADMAP.md` in the current project root. Read it if present. If missing, note: "No ROADMAP.md found."

**Step 2 — Query pm_state** via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT open_decisions, active_risks, last_checkpoint
FROM pm_state
WHERE project = '<project>';
```

**Step 3 — Query pm_sessions** via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT id, plan_name, plan_path, current_step, total_steps, status, updated_at
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```

## Output

Present in this order:

1. **Project + ROADMAP state** — 1–2 sentence summary from ROADMAP.md, or "No ROADMAP.md found."
2. **Open decisions** — list each item from the `open_decisions` array, or "None."
3. **Active risks** — list each item from `active_risks` array, or "None."
4. **Last checkpoint** — from `last_checkpoint` field, or "None run yet."
5. **Paused session** — if Step 3 returned a row:
   `⚠ Paused session: <plan_name> at step <current_step>/<total_steps> — run /pmcontext:resume to continue`

## Suggest Next Action

- Paused session found → "Run /pmcontext:resume to continue, or /pmcontext:execute <path> to start a new plan."
- Open decisions exist → "There are open decisions waiting for your review before starting new work."
- Clean state → "No active session. Ready to brainstorm or execute a plan (/pmcontext:execute <path>)."
