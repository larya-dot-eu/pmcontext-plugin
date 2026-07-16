---
description: Quick-tier execution — blast-radius check then implement directly. Use for small, obvious changes (bug fix, rename, config tweak, adding a test). No planning phases.
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

The task is: $ARGUMENTS

If $ARGUMENTS is empty, output:
```
Usage: /pmcontext:quick <description of what to change>
Example: /pmcontext:quick fix the null check in auth/validate.ts line 42
```
and stop.

Detect the current project name: run `git rev-parse --show-toplevel 2>/dev/null | xargs basename | tr -cd 'a-zA-Z0-9_-'` via Bash tool. If not in a git repo, use `basename "$PWD" | tr -cd 'a-zA-Z0-9_-'`.

> **Supabase MCP tool names:** `mcp__claude_ai_Supabase__*` below assumes the common Supabase MCP install. If your server uses a different prefix, call the equivalent tool from whatever Supabase MCP is available — same SQL, same parameters.

## Step 1: Load Mandatory Context Set

Run file checks in parallel via Bash tool:
```bash
test -f CLAUDE.md && echo "exists" || echo "missing"
test -f CONTEXT.md && echo "exists" || echo "missing"
test -f ROADMAP.md && echo "exists" || echo "missing"
```

Read each file that exists. Missing files: warn and continue — do not block.

Output:
```
[CONTEXT LOADED]
  CLAUDE.md     ✓     (or [missing])
  CONTEXT.md    ✓     (or [missing])
  ROADMAP.md    ✓     (or [missing])
```

Then identify the files most likely involved based on $ARGUMENTS and read them. Do not read unrelated files — load only what is needed to understand the change.

## Step 2: Blast-Radius Check

Before touching anything, state explicitly using the `[BLAST RADIUS]` tag:

- Which files will change
- Which other parts of the system could be affected by this change
- Any risks or surprises (naming conflicts, shared state, tests that might break)

Then ask: *"Does this look right? Confirm to proceed or tell me what's wrong."*

Do not proceed until the user confirms.

## Step 3: Create Session Row

**Guard — check for an existing open session first:**
```sql
SELECT id, plan_name, status FROM pm_sessions
WHERE project = '<project>' AND status IN ('active', 'paused')
ORDER BY updated_at DESC LIMIT 1;
```
If a row is returned, stop and output:
```
[BLOCKED] An open session already exists: <plan_name> (<status>).
Run /pmcontext:close to finish it, or /pmcontext:resume to continue it, before starting new work.
```
Only create the row below if no open session exists (or the user explicitly confirms a second concurrent session).

Run via `mcp__claude_ai_Supabase__execute_sql` with `project_id = <PROJECT_ID>`:

```sql
INSERT INTO pm_sessions (project, session_type, tier, status, started_at, updated_at)
VALUES ('<project>', 'execution', 'quick', 'active', NOW(), NOW())
RETURNING id;
```

Note the returned `id` as `<SESSION_ID>`.

Create a single task to track this work:
`[Quick] <brief description of the change>`

Mark it as in_progress.

## Step 4: Implement

Make the change. Follow the patterns in `CLAUDE.md`. If any tests exist for the affected code, run them after the change.

If writing new logic (not just a fix), write a failing test first — even in quick tier a one-line test is better than none.

If you notice something unrelated that should be fixed, do not fix it now. Say:
> *"I noticed [X]. I've noted it but am staying focused on the current change."*

## Step 5: Verify

Run the relevant tests or verification command. Confirm the change works as expected.

If verification fails, fix the issue before marking done — do not close a broken session.

Mark the task as completed.

Update the session row — leave `status = 'active'` so `/pmcontext:close` can find it and write the receipt (do **not** set `completed` here, or close will miss it and create an orphan row):
```sql
UPDATE pm_sessions
SET updated_at = NOW()
WHERE id = '<SESSION_ID>';
```

Output:
```
✓ Done. Run /pmcontext:close to record this session.
```
