---
description: Execute a plan file end-to-end with TDD, task tracking, and code review
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

The plan path is: $ARGUMENTS

If $ARGUMENTS is empty, output:
```
Usage: /pmcontext:execute <path-to-plan-file>
Example: /pmcontext:execute docs/superpowers/plans/2026-06-02-my-feature.md
```
and stop.

## Step 1: Read the Plan File

Read the plan file at the path provided in $ARGUMENTS. If the file does not exist, output:
```
[ERROR] Plan file not found: <path>
```
and stop.

## Step 2: Parse the Session Launch Section

Find the `## Session Launch` section at the end of the plan file. Extract:
- **What this builds** — one sentence summary
- **Codebase state going in** — test count, branch, relevant state
- **Files the plan touches** — list of files
- **Libraries touched** — list of external libraries/APIs (blank or `—` means none)
- **Key design decisions** — resolved decisions
- **Gotchas** — things to watch for
- **Start here** — first action
- **End here** — success criteria

If the `## Session Launch` section is missing, warn:
```
[WARN] No ## Session Launch section found in this plan.
Context will be limited. Proceeding with plan execution.
```

## Step 3: Prerequisite Check

**Required — abort if missing:**

- Supabase MCP:
  ```
  [BLOCKED] /pmcontext:execute requires Supabase MCP
  ```
- `superpowers:executing-plans` skill:
  ```
  [BLOCKED] /pmcontext:execute requires superpowers:executing-plans
  Install: npx skills add superpowers
  ```
- `superpowers:test-driven-development` skill:
  ```
  [BLOCKED] /pmcontext:execute requires superpowers:test-driven-development
  Install: npx skills add superpowers
  ```
- context7 MCP — **only required if `Libraries touched` field is non-empty:**
  ```
  [BLOCKED] This plan touches external libraries. context7 MCP is required for current docs.
  Install or configure the context7 MCP server to continue.
  ```

**Recommended — warn and continue:**
- `superpowers:requesting-code-review`:
  `[WARN] superpowers:requesting-code-review not found — code review step will be skipped at session end`
- `superpowers:verification-before-completion`:
  `[WARN] superpowers:verification-before-completion not found — completion verification will be skipped`
- `superpowers:using-git-worktrees`:
  `[WARN] superpowers:using-git-worktrees not found — working directly on current branch`

## Step 4: Create Session Row

Detect the current project name: run `git rev-parse --show-toplevel` via Bash tool, take basename.

Count the total plan steps (checkbox items `- [ ]` in the plan file).

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
INSERT INTO pm_sessions (project, plan_path, plan_name, status, current_step, total_steps, started_at, updated_at)
VALUES ('<project>', '<plan_path>', '<plan_name>', 'active', 1, <total_steps>, NOW(), NOW())
RETURNING id;
```
Note the returned `id` as `<SESSION_ID>`.

## Step 5: Execute the Plan

Invoke the `superpowers:executing-plans` skill to execute the plan task-by-task.

Use `TaskCreate` for each plan task to make progress visible.

Before writing any implementation code, invoke the `superpowers:test-driven-development` skill.

After completing each plan step, run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
UPDATE pm_sessions
SET current_step = <completed_step + 1>, updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

If the session ends before all steps are complete (interruption):
```sql
UPDATE pm_sessions
SET status = 'paused', updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

## Step 6: Session End

When all steps are complete:

1. If `superpowers:requesting-code-review` is available — invoke it before any push.
   Otherwise, invoke the `code-review` skill if available.

2. Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
UPDATE pm_sessions
SET status = 'active', current_step = <total_steps>, updated_at = NOW()
WHERE id = '<SESSION_ID>';
```
(Leave status as `active` — /pmcontext:close will mark it completed with the receipt.)

3. Prompt: "Plan execution complete. Run /pmcontext:close to write the session receipt."
