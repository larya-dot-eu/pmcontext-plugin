---
description: Quick dashboard — open decisions, active risks, last checkpoint, active session
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
- Run `git rev-parse --show-toplevel 2>/dev/null | xargs basename | tr -cd 'a-zA-Z0-9_-'` via Bash tool.
  Example: `/home/chris/GitHubReps/linkedin` → `linkedin`
- If not in a git repo, run `basename "$PWD" | tr -cd 'a-zA-Z0-9_-'` instead.
- Use this value as `<project>` in SQL WHERE clauses below.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: attempt to use it. If unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:status requires Supabase MCP
  Install or configure the Supabase MCP server to continue.
  ```

## Queries

Run both queries via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`.

**Query 1 — project state:**
```sql
SELECT open_decisions, active_risks, last_checkpoint
FROM pm_state
WHERE project = '<project>';
```

**Query 2 — active session:**
```sql
SELECT plan_name, current_step, total_steps, status
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```

## Output Format

**If pm_state row found:**
- `open decisions` = length of the `open_decisions` JSON array
- `active risks` = length of the `active_risks` JSON array
- `last checkpoint` = `last_checkpoint.result` + `last_checkpoint.date`, or `none` if null
- Session line = `plan_name — step current_step/total_steps`, or `no active session`

```
project: <name>
open decisions: N  |  active risks: N  |  last checkpoint: RESULT DATE
active session: <plan_name> — step N/N
```

**If everything is zero/empty/null:**
```
project: <name>  |  ✓ no open decisions  |  ✓ no active risks  |  no active session
```

**If no pm_state row exists yet:**
```
project: <name>  |  not initialized — run /pmcontext:start to initialize
```
