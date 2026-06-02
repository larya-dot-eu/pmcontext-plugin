---
description: Close session — write receipt to Supabase, update project state
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
  [BLOCKED] /pmcontext:close requires Supabase MCP
  ```

**Recommended — warn and continue:**
- `superpowers:finishing-a-development-branch`:
  `[WARN] superpowers:finishing-a-development-branch not found — branch completion guidance unavailable`

## Find Active Session

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT id, plan_name, status
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```

Note the `id` as `<SESSION_ID>`. If no row found, a new row will be created (planning-only session).

## Collect Receipt

Based on everything done this session, fill in the following fields honestly:

- **files_changed** — every file touched, one per line. Write "none" if no files were changed.
- **surface_nodes_affected** — which user-facing behaviors may now behave differently, or "none".
- **commands_run** — every terminal command executed this session.
- **tests_skipped** — any test cases not covered and why. Write "none" if full coverage.
- **risky_assumptions** — anything decided without asking the PM. Write "none" if there are none.
- **manual_checks** — exact steps the PM must take to verify this session's work before it goes live.

## Write Receipt to Supabase

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:

**Case A — active session found (SESSION_ID exists):**

```sql
UPDATE pm_sessions
SET
  status                 = 'completed',
  closed_at              = NOW(),
  updated_at             = NOW(),
  files_changed          = '<files_changed>',
  surface_nodes_affected = '<surface_nodes_affected>',
  commands_run           = '<commands_run>',
  tests_skipped          = '<tests_skipped>',
  risky_assumptions      = '<risky_assumptions>',
  manual_checks          = '<manual_checks>'
WHERE id = '<SESSION_ID>';
```

**Case B — no active session (planning-only session):**

```sql
INSERT INTO pm_sessions (
  project, status, closed_at, started_at, updated_at,
  files_changed, surface_nodes_affected, commands_run,
  tests_skipped, risky_assumptions, manual_checks
) VALUES (
  '<project>', 'completed', NOW(), NOW(), NOW(),
  '<files_changed>', '<surface_nodes_affected>', '<commands_run>',
  '<tests_skipped>', '<risky_assumptions>', '<manual_checks>'
);
```

## Update pm_state

If any new `[RISK]` or `[CORE]` decisions were raised this session, run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:

```sql
INSERT INTO pm_state (project, open_decisions, active_risks, updated_at)
VALUES ('<project>', '<open_decisions_json>', '<active_risks_json>', NOW())
ON CONFLICT (project) DO UPDATE
SET
  open_decisions = EXCLUDED.open_decisions,
  active_risks   = EXCLUDED.active_risks,
  updated_at     = NOW();
```

If no new decisions or risks: skip this query.

## Output Receipt

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SESSION CLOSED — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  FILES CHANGED
  <files_changed>

  SURFACE NODES AFFECTED
  <surface_nodes_affected>

  COMMANDS RUN
  <commands_run>

  TESTS SKIPPED
  <tests_skipped>

  RISKY ASSUMPTIONS
  <risky_assumptions>

  MANUAL CHECKS FOR PM
  <manual_checks>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
