---
description: Resume last paused or active session from where it left off
---

## Config

Read the config file via Bash tool:
```bash
cat ~/.pmcontext 2>/dev/null
```

Extract:
- Value after `SUPABASE_PROJECT_ID=` → `<PROJECT_ID>`
- Value after `PLUGIN_DIR=` → `<PLUGIN_DIR>`

If the file is missing or `SUPABASE_PROJECT_ID` is blank, output and stop:
```
[BLOCKED] pmcontext is not configured.
Run /pmcontext:init to complete setup.
```

Detect the current project name:
- Run `git rev-parse --show-toplevel` via Bash tool, then take the basename.
- If not in a git repo, use the basename of the current working directory.
- Use this value as `<project>` in SQL WHERE clauses below.

## Prerequisite Check

**Required — abort if missing:**
- Supabase MCP: if unavailable, output and stop:
  ```
  [BLOCKED] /pmcontext:resume requires Supabase MCP
  ```
- `superpowers:executing-plans`:
  ```
  [BLOCKED] /pmcontext:resume requires superpowers:executing-plans
  Install: npx skills add superpowers
  ```
- `superpowers:test-driven-development`:
  ```
  [BLOCKED] /pmcontext:resume requires superpowers:test-driven-development
  Install: npx skills add superpowers
  ```

**Recommended — warn and continue:**
- `superpowers:requesting-code-review`:
  `[WARN] superpowers:requesting-code-review not found — code review will be skipped`
- `superpowers:verification-before-completion`:
  `[WARN] superpowers:verification-before-completion not found`
- `superpowers:using-git-worktrees`:
  `[WARN] superpowers:using-git-worktrees not found — working directly on current branch`

## Find Last Session

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
SELECT id, plan_name, plan_path, current_step, total_steps, status, updated_at
FROM pm_sessions
WHERE project = '<project>'
  AND status IN ('active', 'paused')
ORDER BY updated_at DESC
LIMIT 1;
```

**If no row found:**
```
No active or paused session found for project: <project>
Run /pmcontext:start to orient, or /pmcontext:execute <path> to start a new plan.
```
Stop.

**If row found:** note `plan_path`, `current_step`, `total_steps`, `id` as `<SESSION_ID>`.

## Read Plan File

Read the plan file at `plan_path`. If the file does not exist:
```
[ERROR] Plan file not found: <plan_path>
The session record references a file that no longer exists.
Run /pmcontext:execute <new-plan-path> to start a new session.
```
Stop.

## Load Project Context

Read the following files from the project root if they exist (run checks in parallel via Bash tool):
```bash
test -f CONTEXT.md && echo "exists" || echo "missing"
test -f PROJECT_BRIEF.md && echo "exists" || echo "missing"
```

- **CONTEXT.md** — PM–Claude protocol, communication tags, Node Model. Use the `[BLAST RADIUS]` tag when a plan step changes a Core Node.
- **PROJECT_BRIEF.md** — Surface Node Inventory and Core Node Map. Use this to identify which Surface Nodes a plan step may affect.

If either file is missing, continue without it — do not block resumption.

## Resume Execution

Output:
```
Resuming: <plan_name>
Continuing from step <current_step> of <total_steps>
```

Check `Libraries touched` in the plan's `## Session Launch` section. If non-empty and context7 MCP is unavailable:
```
[BLOCKED] This plan touches external libraries. context7 MCP required.
```
Stop.

Invoke the `superpowers:executing-plans` skill, starting from step `current_step`.

After completing each step, run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:
```sql
UPDATE pm_sessions
SET current_step = <completed_step + 1>, updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

When all steps are complete: run code review if available, then prompt: "Run /pmcontext:close to write the session receipt."
